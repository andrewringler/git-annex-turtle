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
    let source: PathSource
    let isDir: Bool

    init(for path: String, source: PathSource, isDir: Bool) {
        self.path = path
        self.source = source
        self.isDir = isDir
    }
    
    public var description: String { return "StatusRequest: '\(path)' source=\(source) isDir=\(isDir)" }
}

class HandleStatusRequestsProduction: StoppableService, HandleStatusRequests {
    let lowPriorityQueue = DispatchQueueFIFO(maxConcurrentThreads: 5)
    let highPriorityQueue = DispatchQueueFIFO(maxConcurrentThreads: 20)

    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let watchedFolder: WatchedFolder
    let canRecheckFoldersForUpdates: CanRecheckFoldersForUpdates
    
    init(_ watchedFolder: WatchedFolder, queries: Queries, gitAnnexQueries: GitAnnexQueries, canRecheckFoldersForUpdates: CanRecheckFoldersForUpdates) {
        self.watchedFolder = watchedFolder
        self.queries = queries
        self.gitAnnexQueries = gitAnnexQueries
        self.canRecheckFoldersForUpdates = canRecheckFoldersForUpdates
        super.init()
   }
    
    // enqueue the request
    public func updateStatusFor(for path: String, source: PathSource, isDir: Bool? = nil, priority: Priority = .low) {
        if let isDirectory = isDir != nil ? isDir : GitAnnexQueries.directoryExistsAt(relativePath: path, in: watchedFolder) {
            let statusRequest = StatusRequest(for: path, source: source, isDir: isDirectory)
            
            if priority == .low || isDirectory || source == .badgerequest {
                /* directories can be slow to complete so are low priority
                 * badge requests are likely just duplicates of requests we will get from gitlog, so are low priority
                 */
                lowPriorityQueue.submitTask { self.handleRequest(statusRequest) }
            } else {
                highPriorityQueue.submitTask { self.handleRequest(statusRequest) }
            }
        }
    }
    
    public func handlingRequests() -> Bool {
        return lowPriorityQueue.handlingRequests() || highPriorityQueue.handlingRequests()
    }
    
    private func handleRequest(_ r: StatusRequest) {
        TurtleLog.debug("handling \(r) in \(watchedFolder)")
        
        if PathUtils.isCurrent(r.path) == false,
            PathUtils.pathExists(for: r.path, in: watchedFolder) == false {
            /* Path (file or directory) no longer exists in the working tree
             * just delete the entry from the database, so that it won't appear in future db queries */
            TurtleLog.debug("removing path=\(r.path) that is no longer in the work tree in \(watchedFolder)")
            self.queries.removeStatusForPathBlocking(for: r.path, in: watchedFolder)
            return
        }
        
        /* Folder
         * we have a folder
         */
        if r.isDir {
            if let oldStatus = self.queries.statusForPathV2Blocking(path: r.path, in: watchedFolder), oldStatus.needsUpdate == false {
                // our folder already has a status, just mark it as invalid
                // so that our FolderTracking processing will re check all of its children
                self.queries.invalidateDirectory(path: r.path, in: watchedFolder)
            } else {
                // no entry in db for this directory, add one
                self.queries.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: r.path, key: nil, in: watchedFolder, isDir: true, needsUpdate: true)
            }
            canRecheckFoldersForUpdates.recheckFolderUpdates()
        } else {
            /* File
             * we have a file, get its status
             */
            let statusTuple = self.gitAnnexQueries.gitAnnexPathInfo(for: r.path, in: watchedFolder.pathString, in: watchedFolder, includeFiles: true, includeDirs: true)
            if statusTuple.error {
                TurtleLog.error("HandleStatusRequests: error trying to get git annex info for path='\(r.path)' in \(watchedFolder)")
            } else if let status = statusTuple.pathStatus {
                let oldStatus = self.queries.statusForPathV2Blocking(path: r.path, in: watchedFolder)
                
                // OK we have a new status, even if it didn't change
                // update in the database so we have a new date modified
                self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: r.path, key: status.key, in: watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                
                // If status changed, invalidate immediate parent
                // and re-check parent folder for completion
                if oldStatus != status, let parent = status.parentPath {
                    self.queries.invalidateDirectory(path: parent, in: watchedFolder)
                    canRecheckFoldersForUpdates.recheckFolderUpdates()
                }
            }
        }
    }
}
