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
    
    private func scan(_ watchedFolder: WatchedFolder) {
        while running {
            // Stop requested for our repo?
            var shouldStop = false
            sharedResource.lock()
            shouldStop = !scanning.contains(watchedFolder)
            sharedResource.unlock()
            if shouldStop {
                return
            }

            updateStatusBlocking(in: watchedFolder)
            break // done scanning
        }
        
        // Done scanning
        sharedResource.lock()
        scanning.remove(watchedFolder)
        sharedResource.unlock()
    }
    
    private func enumerateAllFileChildren(relativePath: String, watchedFolder: WatchedFolder) -> Set<String> {
        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: relativePath, in: watchedFolder)
        
        var fileChildren = Set<String>()
        
        if isDir {
            let allChildren = Set(gitAnnexQueries.immediateChildrenNotIgnored(relativePath: relativePath, in: watchedFolder))
            
            for child in allChildren {
                for fileChild in enumerateAllFileChildren(relativePath: child, watchedFolder: watchedFolder) {
                    fileChildren.insert(fileChild)
                }
            }
        } else {
            // file
            fileChildren.insert(relativePath)
        }
        
        return fileChildren
    }
    
    private func updateStatusBlocking(in watchedFolder: WatchedFolder) {
        let files = enumerateAllFileChildren(relativePath: PathUtils.CURRENT_DIR, watchedFolder: watchedFolder)
        
        for file in files {
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
    }
    
    deinit {
        running = false
    }
}
