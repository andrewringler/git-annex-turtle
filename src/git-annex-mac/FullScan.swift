//
//  FullScan.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 2/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class FullScan: StoppableService, StopProcessingWatchedFolder {
    let gitAnnexQueries: GitAnnexQueries
    let queries: Queries
    
    private var sharedResource = NSLock()
    private var scanning = Set<WatchedFolder>()
    
    init(gitAnnexQueries: GitAnnexQueries, queries: Queries) {
        self.gitAnnexQueries = gitAnnexQueries
        self.queries = queries
        super.init()
    }
    
    func startFullScan(watchedFolder: WatchedFolder) {
        guard running.isRunning() else { return }
        
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
        guard running.isRunning() else { return }

        sharedResource.lock()
        if scanning.contains(watchedFolder) {
            TurtleLog.info("Stopping full scan for \(watchedFolder)")
            scanning.remove(watchedFolder)
        }
        sharedResource.unlock()
    }

    func isScanning() -> Bool {
        guard running.isRunning() else { return false }
        
        var ret = false
        sharedResource.lock()
        ret = scanning.count > 0
        sharedResource.unlock()
        return ret
    }
    
    func isScanning(watchedFolder: WatchedFolder) -> Bool {
        guard running.isRunning() else { return false }

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
        while running.isRunning() {
            let scanStartDate = Date()
            
            // Store the current git commit hashes before starting our full scan
            // so we can perform incremental scans, from this point
            // IE, we only want to ever do a full scan one time per repo
            
            // OK to be nil
            let gitGitCommitHash = gitAnnexQueries.latestGitCommitHashBlocking(in: watchedFolder)

            // git annex init creates 1+ commits in the git-annex branch
            // so there should always be at least one git annex commit
            if let gitAnnexCommitHash = gitAnnexQueries.latestGitAnnexCommitHashBlocking(in: watchedFolder) {
                TurtleLog.info("Starting full scan for \(watchedFolder)")
                
                // update status of all files
                if !updateStatusBlocking(in: watchedFolder) {
                    TurtleLog.debug("Stop requested. Stopped scanning early for \(watchedFolder)")
                    break
                }
                
                // update status of all folders in Db for this repo
                if !FolderTracking.handleFolderUpdatesFromFullScan(watchedFolder: watchedFolder, queries: queries, gitAnnexQueries: gitAnnexQueries, stopProcessingWatchedFolder: self) {
                    TurtleLog.debug("Stop requested. Stopped scanning early for \(watchedFolder)")
                    break
                }

                // OK, we have completed a full scan successfully, store the git and git-annex
                // commit hashes we saved off before the scan, so we can continue performing
                // incremental updates for this repo
                queries.updateLatestHandledCommit(gitCommitHash: gitGitCommitHash, gitAnnexCommitHash: gitAnnexCommitHash, in: watchedFolder)
                
                let scanDuration = Date().timeIntervalSince(scanStartDate) as Double
                TurtleLog.info("Completed full scan for \(watchedFolder) in \(Int(scanDuration)) seconds")
            } else {
                TurtleLog.error("Could not find any commits on the git-annex branch, this should not happen, stopping full scan for \(watchedFolder)")
                break
            }
            
            break // done scanning
        }
        
        // Done scanning
        sharedResource.lock()
        scanning.remove(watchedFolder)
        sharedResource.unlock()
    }
    
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
            
            if queries.updateStatusForDirectoryPathsV2BatchBlocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: chunk, key: nil, in: watchedFolder, isDir: true, needsUpdate: true) == false {
                return false
            }
        }
        
        
        //
        // Files
        //
        // calculate git-annex status information for all files
        //
        let modificationDate = Date().timeIntervalSince1970 as Double
        if let filesWithCopiesLacking = self.gitAnnexQueries.gitAnnexAllFilesLackingCopies(in: watchedFolder), let resultsFileName = self.gitAnnexQueries.gitAnnexWhereisAllFiles(in: watchedFolder) {
            var s = StreamReader(url: PathUtils.urlFor(absolutePath: resultsFileName))
            while let line = s?.nextLine() {
                if let status = self.gitAnnexQueries.parseWhereis(for: line, in: watchedFolder, modificationDate: modificationDate, filesWithCopiesLacking: filesWithCopiesLacking) {
                    // TODO batch db inserts
                    
                    TurtleLog.debug("Updated status for \(status.path) in \(watchedFolder)")
                    self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: status.path, key: status.key, in: watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                }
            }
            s = nil // deinit, close file handle
            PathUtils.removeDir(resultsFileName)
        } else {
            TurtleLog.error("Could not get whereis info for \(watchedFolder)")
            return false
        }
        
        return true // completed successfully
    }    
}
