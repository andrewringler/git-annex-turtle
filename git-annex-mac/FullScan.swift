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

        NSLog("Stopping full scan for \(watchedFolder)")
        
        sharedResource.lock()
        scanning.remove(watchedFolder)
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
    
    private func enumerateAllFileChildrenAndQueueDirectories(relativePath: String, watchedFolder: WatchedFolder) -> (success: Bool, children: Set<String>) {
        if shouldStop(watchedFolder) {
            return (success: false, children: Set<String>())
        }
        
        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: relativePath, in: watchedFolder)
        
        var fileChildren = Set<String>()
        
        if isDir {
            // Add an incomplete entry in the database, that we will clean up later
            // once all children have been populated
            queries.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: relativePath, key: nil, in: watchedFolder, isDir: true, needsUpdate: false /* UNUSED? */)
            
            let allChildren = Set(gitAnnexQueries.immediateChildrenNotIgnored(relativePath: relativePath, in: watchedFolder))
            
            for child in allChildren {
                let childrenForChild = enumerateAllFileChildrenAndQueueDirectories(relativePath: child, watchedFolder: watchedFolder)
                
                if childrenForChild.success {
                    for fileChild in childrenForChild.children {
                        fileChildren.insert(fileChild)
                    }
                } else {
                    return (success: false, children: Set<String>())
                }
            }
        } else {
            // file
            fileChildren.insert(relativePath)
        }
        
        return (success: true, children: fileChildren)
    }
    
    private func updateStatusBlocking(in watchedFolder: WatchedFolder) -> Bool {
        let allFileChildren = enumerateAllFileChildrenAndQueueDirectories(relativePath: PathUtils.CURRENT_DIR, watchedFolder: watchedFolder)
        
        if !allFileChildren.success {
            return false // terminated early
        }
        
        for file in allFileChildren.children {
            if shouldStop(watchedFolder) {
                return false
            }
            
            var statusTuple: (error: Bool, pathStatus: PathStatus?)?
            if (Thread.isMainThread) {
                statusTuple = self.gitAnnexQueries.gitAnnexPathInfo(for: file, in: watchedFolder.pathString, in: watchedFolder, includeFiles: true, includeDirs: false)
            } else {
                DispatchQueue.main.sync {
                    statusTuple = self.gitAnnexQueries.gitAnnexPathInfo(for: file, in: watchedFolder.pathString, in: watchedFolder, includeFiles: true, includeDirs: false)
                }
            }
            
            if statusTuple?.error == false, let status = statusTuple?.pathStatus {
                if (Thread.isMainThread) {
                    self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: file, key: status.key, in: watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                } else {
                    DispatchQueue.main.sync {
                        self.queries.updateStatusForPathV2Blocking(presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: file, key: status.key, in: watchedFolder, isDir: status.isDir, needsUpdate: status.needsUpdate)
                    }
                }
            } else {
                NSLog("FullScan, error trying to get status for '\(file)' in \(watchedFolder) \(statusTuple?.error ?? nil)")
            }
        }
        
        return true // completed successfully
    }
    
    deinit {
        running = false
    }
}
