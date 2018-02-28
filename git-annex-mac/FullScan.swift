//
//  FullScan.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 2/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class FullScan {
    var running = true

    let gitAnnexQueries: GitAnnexQueries
    let queries: Queries
    
    private var sharedResource = NSLock()
    private var scanning = Set<WatchedFolder>()
    
    init(gitAnnexQueries: GitAnnexQueries, queries: Queries) {
        self.gitAnnexQueries = gitAnnexQueries
        self.queries = queries
    }
    
    func startFullScan(watchedFolder: WatchedFolder) {
        guard running else { return }
        
        sharedResource.lock()
        if !scanning.contains(watchedFolder) {
            scanning.insert(watchedFolder)
            DispatchQueue.global(qos: .background).async {
                self.scan(watchedFolder)
            }
        }
        sharedResource.unlock()
    }

    func stopFullScan(watchedFolder: WatchedFolder) {
        guard running else { return }

        sharedResource.lock()
        if scanning.contains(watchedFolder) {
            NSLog("Stopping full scan for \(watchedFolder)")
            scanning.remove(watchedFolder)
        }
        sharedResource.unlock()
    }

    func isScanning(watchedFolder: WatchedFolder) -> Bool {
        guard running else { return false }

        var ret = false
        sharedResource.lock()
        ret = scanning.contains(watchedFolder)
        sharedResource.unlock()
        return ret
    }
    
    public func shouldStop(_ watchedFolder: WatchedFolder) -> Bool {
        var shouldStop = false
        sharedResource.lock()
        shouldStop = !scanning.contains(watchedFolder)
        sharedResource.unlock()
        return shouldStop
    }
    
    private func scan(_ watchedFolder: WatchedFolder) {
        while running {
            // Store the current git commit hashes before starting our full scan
            // so we can perform incremental scans, from this point
            // IE, we only want to ever do a full scan one time per repo
            
            // OK to be nil
            let gitGitCommitHash = gitAnnexQueries.latestGitCommitHashBlocking(in: watchedFolder)

            // git annex init creates 1+ commits in the git-annex branch
            // so there should always be at least one git annex commit
            if let gitAnnexCommitHash = gitAnnexQueries.latestGitAnnexCommitHashBlocking(in: watchedFolder) {
                NSLog("Starting full scan for \(watchedFolder)")
                
                // update status of all files
                if !updateStatusBlocking(in: watchedFolder) {
                    NSLog("Stop requested. Stopped scanning early for \(watchedFolder)")
                    break
                }
                
                // update status of all folders in Db for this repo
                if !FolderTracking.handleFolderUpdates(watchedFolder: watchedFolder, queries: queries, gitAnnexQueries: gitAnnexQueries, fullScan: self) {
                    NSLog("Stop requested. Stopped scanning early for \(watchedFolder)")
                    break
                }
                
                // OK, we have completed a full scan successfully, store the git and git-annex
                // commit hashes we saved off before the scan, so we can continue performing
                // incremental updates for this repo
                queries.updateLatestHandledCommit(gitCommitHash: gitGitCommitHash, gitAnnexCommitHash: gitAnnexCommitHash, in: watchedFolder)
                
                NSLog("Completed full scan for \(watchedFolder)")
            } else {
                NSLog("Could not find any commits on the git-annex branch, this should not happen, stopping full scan for \(watchedFolder)")
                break
            }
            
            break // done scanning
        }
        
        // Done scanning
        sharedResource.lock()
        scanning.remove(watchedFolder)
        sharedResource.unlock()
    }
    
//    private func enumerateAllFileChildrenAndQueueDirectories(relativePath: String, watchedFolder: WatchedFolder) -> (success: Bool, children: (files: Set<String>, dirs: Set<String>)) {
//        if shouldStop(watchedFolder) {
//        return (success: false, children: (files: Set<String>(), dirs: Set<String>()))
//        }
//
//        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: relativePath, in: watchedFolder)
//
//        var fileChildren = Set<String>()
//        var dirChildren = Set<String>()
//
//        if isDir {
//            // Dir
//            dirChildren.insert(relativePath)
//            let allChildren = Set(gitAnnexQueries.immediateChildrenNotIgnored(relativePath: relativePath, in: watchedFolder))
//
//            for child in allChildren {
//                let childrenForChild = enumerateAllFileChildrenAndQueueDirectories(relativePath: child, watchedFolder: watchedFolder)
//
//                if childrenForChild.success {
//                    childrenForChild.children.files.forEach { fileChildren.insert($0) }
//                    childrenForChild.children.dirs.forEach { dirChildren.insert($0) }
//                } else {
//                    return (success: false, children: (files: Set<String>(), dirs: Set<String>()))
//                }
//            }
//        } else {
//            // File
//            fileChildren.insert(relativePath)
//        }
//
//        return (success: true, children: (files: fileChildren, dirs: dirChildren))
//    }
   
    private func updateStatusBlocking(in watchedFolder: WatchedFolder) -> Bool {
        let allChildren = PathUtils.children(in: watchedFolder)        

        //
        // Directories
        //
        // we don't need to scan directories, just add an empty record in the database
        // so its status information can be filled in as his children are filled in
        //
        // chunks: https://stackoverflow.com/a/38156873/8671834
        //
        let dirs = Array(allChildren.dirs)
        let chunkSize = 1000
        let chunks: [[String]] = stride(from: 0, to: dirs.count, by: chunkSize).map {
            let end = dirs.endIndex
            let chunkEnd = dirs.index($0, offsetBy: chunkSize, limitedBy: end) ?? end
            return Array(dirs[$0..<chunkEnd])
        }
        for chunk in chunks {
            if shouldStop(watchedFolder) {
                return false
            }
            
            if queries.updateStatusForPathV2BatchBlocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: chunk, key: nil, in: watchedFolder, isDir: true, needsUpdate: false /* UNUSED? */) == false {
                return false
            }
        }
        
        
        //
        // Files
        //
        // calculate git-annex status information for each file
        //
        let updateStatusQueue =
            DispatchQueue(label: "com.andrewringler.git-annex-mac.FullScanUpdateStatusQueue-\(watchedFolder.uuid.uuidString)", attributes: .concurrent)
        let maxConcurrency = DispatchSemaphore(value: 100)
        let processingOfAllChildrenGroup = DispatchGroup()
        
        for file in allChildren.files {
            if shouldStop(watchedFolder) {
                return false
            }
            
            maxConcurrency.wait()
            processingOfAllChildrenGroup.enter()
            updateStatusQueue.async {
                var statusTuple: (error: Bool, pathStatus: PathStatus?)?
                statusTuple = self.gitAnnexQueries.gitAnnexPathInfo(for: file, in: watchedFolder.pathString, in: watchedFolder, includeFiles: true, includeDirs: false)
                
                if statusTuple?.error == false, let status = statusTuple?.pathStatus {
                    self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: file, key: status.key, in: watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                } else {
                    let error: String = String(statusTuple?.error ?? false)
                    NSLog("FullScan, error trying to get status for '\(file)' in \(watchedFolder) \(error)")
                }
                
                processingOfAllChildrenGroup.leave()
                maxConcurrency.signal()
            }
        }
        
        processingOfAllChildrenGroup.wait() // wait for all asynchronous status updates to complete
        return true // completed successfully
    }
    
    deinit {
        running = false
    }
}
