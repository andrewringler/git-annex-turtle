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
    let isDir: Bool
    
    init(for path: String, in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority, isDir: Bool) {
        self.path = path
        self.watchedFolder = watchedFolder
        self.secondsOld = secondsOld
        self.includeFiles = includeFiles
        self.includeDirs = includeDirs
        self.priority = priority
        self.isDir = isDir
    }
    
    public var description: String { return "StatusRequest: '\(path)' in \(watchedFolder) \(secondsOld) secondsOld, includeFiles=\(includeFiles) includeDirs=\(includeDirs) priority=\(priority) isDir=\(isDir)" }
}

class HandleStatusRequests {
    let maxConcurrentUpdatesPerWatchedFolderHighPriority = 20
    let maxConcurrentUpdatesPerWatchedFolderLowPriority = 5
    
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    
    fileprivate let lowPriorityQueue =
        DispatchQueue(label: "com.andrewringler.git-annex-mac.LowPriority", attributes: .concurrent)
    fileprivate let highPriorityQueue =
        DispatchQueue(label: "com.andrewringler.git-annex-mac.HighPriority", attributes: .concurrent)

    // TODO store in the database? these could get quite large?
    private var dateAddedToStatusRequestQueueHighPriority: [Double: StatusRequest] = [:]
    private var dateAddedToStatusRequestQueueLowPriority: [Double: StatusRequest] = [:]
    private var currentlyUpdatingPathByWatchedFolder: [WatchedFolder: [String]] = [:]
    
    // swift collections are NOT thread-safe, but even if they were
    // we still need a lock to guarantee transactions are atomic across our collections
    private var sharedResource = NSLock()
    
    // enqueue the request
    public func updateStatusFor(for path: String, in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority) {
        // Create the Request
        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: path, in: watchedFolder)
        let statusRequest = StatusRequest(for: path, in: watchedFolder, secondsOld: secondsOld, includeFiles: includeFiles, includeDirs: includeDirs, priority: priority, isDir: isDir)

        // Enqueue the request, prioritized FIFO
        let dateAdded = Date().timeIntervalSince1970 as Double
        sharedResource.lock()
        if isDir || priority == .low { /* directories are always low priority */
            dateAddedToStatusRequestQueueLowPriority[dateAdded] = statusRequest
        } else {
            dateAddedToStatusRequestQueueHighPriority[dateAdded] = statusRequest
        }
        sharedResource.unlock()
    }
    
    init(queries: Queries, gitAnnexQueries: GitAnnexQueries) {
        self.queries = queries
        self.gitAnnexQueries = gitAnnexQueries
        
        // High Priority
        DispatchQueue.global(qos: .background).async {
            let limitConcurrentThreadsHighPriority = DispatchSemaphore(value: self.maxConcurrentUpdatesPerWatchedFolderHighPriority)

            while true {
                self.handleSomeRequests(for: &self.dateAddedToStatusRequestQueueHighPriority, max: self.maxConcurrentUpdatesPerWatchedFolderHighPriority, priority: .high, queue: self.highPriorityQueue, limitConcurrentThreads: limitConcurrentThreadsHighPriority)
                
                sleep(1)
            }
        }
        
        // Low Priority
        DispatchQueue.global(qos: .background).async {
            let limitConcurrentThreadsLowPriority = DispatchSemaphore(value: self.maxConcurrentUpdatesPerWatchedFolderLowPriority)
            
            while true {
                self.handleSomeRequests(for: &self.dateAddedToStatusRequestQueueLowPriority, max: self.maxConcurrentUpdatesPerWatchedFolderLowPriority, priority: .low, queue: self.lowPriorityQueue, limitConcurrentThreads: limitConcurrentThreadsLowPriority)
                
                sleep(1)
            }
        }
    }
    
    public func handlingRequests() -> Bool {
        var isHandlingRequests: Bool = false
        sharedResource.lock()
        isHandlingRequests = currentlyUpdatingPathByWatchedFolder.reduce(0, { x, y in (x + y.value.count) }) > 0 ||
            dateAddedToStatusRequestQueueLowPriority.count > 0 ||
            dateAddedToStatusRequestQueueHighPriority.count > 0
        sharedResource.unlock()
        
        return isHandlingRequests
    }
    
    private func handleSomeRequests(for dateAddedToStatusRequestQueue: inout [Double: StatusRequest], max maxConcurrentUpdatesPerWatchedFolder: Int, priority: Priority, queue: DispatchQueue, limitConcurrentThreads: DispatchSemaphore) {
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
            if let status = statusOptional, status.isDir {
                /* we have a directory which already has an entry in our database
                 * that means that some procedure has already enumerated this directories
                 * files, there is nothing we need to do, except wait for his children
                 * to finish updating their statuses
                 */
                NSLog("Ignoring folder already present in database \(item.value.path) for \(item.value.watchedFolder)")
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
            watchedPaths = currentlyUpdatingPathByWatchedFolder[item.value.watchedFolder]
            if watchedPaths != nil {
                watchedPaths!.append(item.value.path)
                currentlyUpdatingPathByWatchedFolder[item.value.watchedFolder] = watchedPaths!
            } else {
                currentlyUpdatingPathByWatchedFolder[item.value.watchedFolder] = [item.value.path]
            }
            sharedResource.unlock()
            
            NSLog("wait() \(item.value.path) in \(item.value.watchedFolder.pathString)")
            limitConcurrentThreads.wait()
            NSLog("enter() \(item.value.path) in \(item.value.watchedFolder.pathString)")
            updateStatusAsync(request: item.value, queue: queue, limitConcurrentThreads: limitConcurrentThreads)
        }
    }
    
    private func updateStatusAsync(request r: StatusRequest, queue: DispatchQueue, limitConcurrentThreads: DispatchSemaphore) {
        queue.async {
            /* Folder
             * we have a folder that has no entry in the database
             * that means we need to enumerate all of his children
             * and enqueue them for completion
             */
            if r.isDir {
                // add entry for this directory
                self.queries.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: r.path, key: nil, in: r.watchedFolder, isDir: true, needsUpdate: true)

                // enqueue requests to find status for all this dirs children
                let allChildren = PathUtils.children(path: r.path, in: r.watchedFolder)
                for child in allChildren.files {
                    self.updateStatusFor(for: child, in: r.watchedFolder, secondsOld: 0, includeFiles: true, includeDirs: true, priority: .high)
                }
                for child in allChildren.dirs {
                    self.updateStatusFor(for: child, in: r.watchedFolder, secondsOld: 0, includeFiles: true, includeDirs: true, priority: .low)
                }
            } else {
                /* File
                 * we have a file, get its status
                 */
                let statusTuple = self.gitAnnexQueries.gitAnnexPathInfo(for: r.path, in: r.watchedFolder.pathString, in: r.watchedFolder, includeFiles: r.includeFiles, includeDirs: r.includeDirs)
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
                }
            }
            
            // Done, now remove this path from the in-progress queue
            self.sharedResource.lock()
            var watchedPaths = self.currentlyUpdatingPathByWatchedFolder[r.watchedFolder]
            if var paths = watchedPaths, let index = paths.index(of: r.path) {
                paths.remove(at: index)
                self.currentlyUpdatingPathByWatchedFolder[r.watchedFolder] = paths
            } else {
                NSLog("Could not find path \(r.path) in \(self.currentlyUpdatingPathByWatchedFolder) for \(r.watchedFolder)")
            }
            self.sharedResource.unlock()
            
            NSLog("release() \(r.path) in \(r.watchedFolder.pathString)")
            limitConcurrentThreads.signal() // done, allow other threads to execute
        }
    }
}
