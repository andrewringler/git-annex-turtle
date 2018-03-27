//
//  HandleStatusRequests.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/25/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Foundation

fileprivate class StatusRequest: CustomStringConvertible {
    let path: String
    let priority: Priority
    let isDir: Bool

    init(for path: String, priority: Priority, isDir: Bool) {
        self.path = path
        self.priority = priority
        self.isDir = isDir
    }
    
    public var description: String { return "StatusRequest: '\(path)' priority=\(priority) isDir=\(isDir)" }
}

class HandleStatusRequestsProduction: StoppableService, HandleStatusRequests {
    let lowPriorityQueue = DispatchQueueFIFO(maxConcurrentThreads: 10)
    let highPriorityQueue = DispatchQueueFIFO(maxConcurrentThreads: 5)

    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let watchedFolder: WatchedFolder

    init(_ watchedFolder: WatchedFolder, queries: Queries, gitAnnexQueries: GitAnnexQueries) {
        self.watchedFolder = watchedFolder
        self.queries = queries
        self.gitAnnexQueries = gitAnnexQueries
        super.init()
   }
    
    // enqueue the request
    public func updateStatusFor(for path: String, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority) {
        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: path, in: watchedFolder)
        let statusRequest = StatusRequest(for: path, priority: priority, isDir: isDir)
        
        if isDir || priority == .low { /* directories are always low priority */
            lowPriorityQueue.submitTask { self.handleRequest(statusRequest) }
        } else {
            highPriorityQueue.submitTask { self.handleRequest(statusRequest) }
        }
    }
    
    public func handlingRequests() -> Bool {
        return lowPriorityQueue.handlingRequests() || highPriorityQueue.handlingRequests()
    }
    
    private func handleRequest(_ r: StatusRequest) {
        TurtleLog.debug("handling \(r)")
        
        /* Folder
         * we have a folder that has no entry in the database
         * that means we need to enumerate all of his children
         * and enqueue them for completion
         */
        if r.isDir {
            // add entry for this directory
            self.queries.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: r.path, key: nil, in: watchedFolder, isDir: true, needsUpdate: true)

            // enqueue requests to find status for all this dir's children
            let allChildren = PathUtils.children(path: r.path, in: watchedFolder)
            for child in allChildren.files {
                self.updateStatusFor(for: child, secondsOld: 0, includeFiles: true, includeDirs: true, priority: .high)
            }
            for child in allChildren.dirs {
                self.updateStatusFor(for: child, secondsOld: 0, includeFiles: true, includeDirs: true, priority: .low)
            }
        } else {
            /* File
             * we have a file, get its status
             */
            let statusTuple = self.gitAnnexQueries.gitAnnexPathInfo(for: r.path, in: watchedFolder.pathString, in: watchedFolder, includeFiles: true, includeDirs: true)
            if statusTuple.error {
                TurtleLog.error("HandleStatusRequests: error trying to get git annex info for path='\(r.path)'")
            } else if let status = statusTuple.pathStatus {
                let oldStatus = self.queries.statusForPathV2Blocking(path: r.path, in: watchedFolder)
                
                // OK we have a new status, even if it didn't change
                // update in the database so we have a new date modified
                self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: r.path, key: status.key, in: watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                
                // If status changed, invalidate immediate parent
                if oldStatus != status, let parent = status.parentPath {
                    self.queries.invalidateDirectory(path: parent, in: watchedFolder)
                }
            }
        }
    }
}
