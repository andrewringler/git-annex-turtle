//
//  HandleStatusRequests.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/25/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

enum Priority {
    case high
    case low
}

fileprivate class StatusRequest: CustomStringConvertible {
    let path: String
    let watchedFolder: WatchedFolder
    let secondsOld: Double
    let includeFiles: Bool
    let includeDirs: Bool
    let priority: Priority
    
    init(for path: String, in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority) {
        self.path = path
        self.watchedFolder = watchedFolder
        self.secondsOld = secondsOld
        self.includeFiles = includeFiles
        self.includeDirs = includeDirs
        self.priority = priority
    }
    
    public var description: String { return "StatusRequest: '\(path)' in \(watchedFolder) \(secondsOld) secondsOld, includeFiles=\(includeFiles) includeDirs=\(includeDirs) priority=\(priority)" }
}

class HandleStatusRequests {
    let maxConcurrentUpdatesPerWatchedFolderHighPriority = 10
    let maxConcurrentUpdatesPerWatchedFolderLowPriority = 5
    let queries: Queries
    
    // TODO store in database? these could get quite large?
    private var dateAddedToStatusRequestQueueHighPriority: [Double: StatusRequest] = [:]
    private var dateAddedToStatusRequestQueueLowPriority: [Double: StatusRequest] = [:]
    private var currentlyUpdatingPathByWatchedFolder: [WatchedFolder: [String]] = [:]
    
    // swift collections are NOT thread-safe, but even if they were
    // we still need a lock to guarantee transactions are atomic across our collections
    private var sharedResource = NSLock()
    
    // enqueue the request
    public func updateStatusFor(for path: String, in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority) {
        let statusRequest = StatusRequest(for: path, in: watchedFolder, secondsOld: secondsOld, includeFiles: includeFiles, includeDirs: includeDirs, priority: priority)
        let dateAdded = Date().timeIntervalSince1970 as Double
        
        // directories are always low priority, since they take a long
        // time to calculate status for
        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: path, in: watchedFolder)
        
        sharedResource.lock()
        if isDir || priority == .low {
            dateAddedToStatusRequestQueueLowPriority[dateAdded] = statusRequest
        } else {
            dateAddedToStatusRequestQueueHighPriority[dateAdded] = statusRequest
        }
        sharedResource.unlock()
    }
    
    init(queries: Queries) {
        self.queries = queries
        
        DispatchQueue.global(qos: .background).async {
            while true {
                // High Priority, handle high priority requests first
                self.handleSomeRequests(for: &self.dateAddedToStatusRequestQueueHighPriority, max: self.maxConcurrentUpdatesPerWatchedFolderHighPriority, priority: .high)
                
                // Low Priority, handle low priority requests next
                // if we still have some open threads available
                // TODO, do we care about thread starvation for these?
                self.handleSomeRequests(for: &self.dateAddedToStatusRequestQueueLowPriority, max: self.maxConcurrentUpdatesPerWatchedFolderLowPriority, priority: .low)
                
                sleep(1)
            }
        }
    }
    
    public func handlingRequests() -> Bool {
        return currentlyUpdatingPathByWatchedFolder.count > 0 ||
        dateAddedToStatusRequestQueueLowPriority.count > 0 ||
        dateAddedToStatusRequestQueueHighPriority.count > 0
    }
    
    private func handleSomeRequests(for dateAddedToStatusRequestQueue: inout [Double: StatusRequest], max maxConcurrentUpdatesPerWatchedFolder: Int, priority: Priority) {
        sharedResource.lock()
        let oldestRequestFirst = dateAddedToStatusRequestQueue.sorted(by: { $0.key < $1.key })
        sharedResource.unlock()
        
        // OK for each item, lets check if we should update it
        for item in oldestRequestFirst {
            NSLog("Handling \(item.value.path) in \(item.value.watchedFolder.pathString)")
            sharedResource.lock()
            var watchedPaths = currentlyUpdatingPathByWatchedFolder[item.value.watchedFolder]
            sharedResource.unlock()
            
            // Duplicate?
            // are we already handling this path?
            if let paths = watchedPaths, paths.contains(item.value.path) {
                // we are already getting updates for this path
                // if it is low priority, then whatever update we get will be new enough
                // if it is high priority, we probably need to re-calculate
                // so leave in the queue, and check on it later
                if priority == .low {
                    NSLog("Already updating, and low priority, remove from queue \(item.value.path) in \(item.value.watchedFolder.pathString)")
                    sharedResource.lock()
                    dateAddedToStatusRequestQueue.removeValue(forKey: item.key)
                    sharedResource.unlock()
                }
                NSLog("Already updating, ignore for now \(item.value.path) in \(item.value.watchedFolder.pathString)")
                continue
            }
            
            // Queue Full?
            // do we already have too many concurrent requests in this watched folder?
            if let paths = watchedPaths, paths.count >= maxConcurrentUpdatesPerWatchedFolder {
                // too many concurrent updates for this WatchedFolder
                // keep in queue and try again later
                NSLog("Too many items in queue ignore for now \(item.value.path) in \(item.value.watchedFolder.pathString)")
                continue
            }
            
            // Fresh Enough?
            // do we already have a new enough status update for this file in the database?
            let statusOptional = queries.statusForPathV2Blocking(path: item.value.path, in: item.value.watchedFolder)
            let oldestAllowableDate = (Date().timeIntervalSince1970 as Double) - item.value.secondsOld
            if let status = statusOptional, status.modificationDate > oldestAllowableDate, status.needsUpdate == false {
                // OK, we already have this path in the database
                // and it is new enough, and it isn't marked as needing updating
                // remove this request, it is not necessary
                NSLog("Already new enough, delete \(item.value.path) in \(item.value.watchedFolder.pathString)")
                sharedResource.lock()
                dateAddedToStatusRequestQueue.removeValue(forKey: item.key)
                sharedResource.unlock()
                continue
            }
            
            // Update it
            // we aren't currently updating this path
            // and we don't have a fresh enough copy in the database
            // and we have enough spare threads to actually do the request
            // so, we'll update it
            NSLog("OK update \(item.value.path) in \(item.value.watchedFolder.pathString)")

            sharedResource.lock()
            // remove from queue
            dateAddedToStatusRequestQueue.removeValue(forKey: item.key)
            // mark as in progress
            if watchedPaths != nil {
                watchedPaths!.append(item.value.path)
                currentlyUpdatingPathByWatchedFolder[item.value.watchedFolder] = watchedPaths!
            } else {
                currentlyUpdatingPathByWatchedFolder[item.value.watchedFolder] = [item.value.path]
            }
            sharedResource.unlock()
            updateStatusAsync(request: item.value)
        }
    }
    
    private func updateStatusAsync(request r: StatusRequest) {
        DispatchQueue.global(qos: .background).async {
            let statusTuple = GitAnnexQueries.gitAnnexPathInfo(for: r.path, in: r.watchedFolder.pathString, in: r.watchedFolder, includeFiles: r.includeFiles, includeDirs: r.includeDirs)
            if statusTuple.error {
                NSLog("HandleStatusRequests: error trying to get git annex info for path='\(r.path)'")
            } else if let status = statusTuple.pathStatus {
                let oldStatus = self.queries.statusForPathV2Blocking(path: r.path, in: r.watchedFolder)
                
                // OK we have a new status, even if it didn't change
                // update in the database so we have a new date modified
                self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: r.path, key: status.key, in: r.watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                
                // If status changed, invalidate immediate parent
                if oldStatus != status, let parent = status.parentPath {
                    self.queries.invalidateDirectory(path: parent, in: r.watchedFolder)
                }
            } else {
                // we have a skipped directory, save its status
                // if it doesn't already exist, otherwise leave it alone
                // since we didn't actually do anything
                
//                let oldStatus = self.queries.statusForPathV2Blocking(path: r.path)
//                if oldStatus == nil {
//                    self.queries.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: r.path, key: nil, in: r.watchedFolder, isDir: true, needsUpdate: true)
//                }
                
                // we have a skipped directory
                let oldStatus = self.queries.statusForPathV2Blocking(path: r.path, in: r.watchedFolder)
                
                // no entry for directory, lets add one
                if oldStatus == nil {
                    self.queries.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: r.path, key: nil, in: r.watchedFolder, isDir: true, needsUpdate: false /* we will update below */)
                }
                
                // lets update, it is out of date
                if oldStatus == nil || (oldStatus?.needsUpdate ?? true) {
                    NSLog("Skipped dir, updating, \(r)")
                    let children = GitAnnexQueries.immediateChildrenNotIgnored(relativePath: r.path, in: r.watchedFolder)
                    NSLog("children: \(children)")
                    for child in children {
                        if let _ = self.queries.statusForPathV2Blocking(path: child, in: r.watchedFolder) {
                            // OK, we already have an entry for this child in the database
                            // do nothing
                        } else {
                            NSLog("no entry for child: \(child) in \(r.watchedFolder)")
                            // No entry exists, lets request one
                            self.queries.addRequestV2Async(for: child, in: r.watchedFolder)
                        }
                    }
                }
            }
            
            // Done, now remove this path from the in-progress queue
            self.sharedResource.lock()
            var watchedPaths = self.currentlyUpdatingPathByWatchedFolder[r.watchedFolder]
            if var paths = watchedPaths, let index = paths.index(of: r.path) {
                paths.remove(at: index)
                self.currentlyUpdatingPathByWatchedFolder[r.watchedFolder] = paths
            }
            self.sharedResource.unlock()
        }
    }
}
