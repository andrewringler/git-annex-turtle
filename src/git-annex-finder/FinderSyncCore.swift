//
//  FinderSyncCore.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 3/16/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa
import CoreData
import Foundation

class FinderSyncCore: StoppableService {
    let finderSync: FinderSyncProtocol
    let data: DataEntrypoint
    let queries: Queries
    let statusCache: StatusCache
    let appTurtleMessagePort: AppTurtleMessagePort
    
    private var watchedFolders = Set<WatchedFolder>()
    private var lastHandledDatabaseChangesDateSinceEpochAsDouble: Double = 0
    
    init(finderSync: FinderSyncProtocol, data: DataEntrypoint) {
        self.finderSync = finderSync
        self.data = data
        statusCache = StatusCache(data: data)
        queries = Queries(data: data)
        appTurtleMessagePort = AppTurtleMessagePort(id: finderSync.id())
        super.init()
        
        //
        // Watched Folders
        //
        // grab the list of watched folders from the database and start watching them
        //
        updateWatchedFolders(queries: queries)
        
        //
        // Status Updates
        //
        // check the database for updates to the list of watched folders
        // and for updated statuses of watched files
        //
        DispatchQueue.global(qos: .background).async {
            while self.running.isRunning() {
                let foundUpdates = self.handleDatabaseUpdatesIfAny()
                if !foundUpdates {
                    // if we didn't get any database updates, lets give the CPU a rest
                    usleep(150000)
                }
            }
        }
    }
    
    func requestBadgeIdentifier(for url: URL) {
        TurtleLog.debug("requestBadgeIdentifier for \(url) isDir=\(url.hasDirectoryPath) \(finderSync.id())")
        
        if let absolutePath = PathUtils.path(for: url) {
            if let watchedFolder = self.watchedFolderParent(for: absolutePath) {
                if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                    if path.starts(with: ".git/") {
                        // TODO why does the Finder Sync extension follow symlinks sometimes?
                        TurtleLog.info("Finder Sync extension followed a symlink to \(path) in \(watchedFolder), ignoring.")
                        return
                    }
                    
                    // already have the status? then use it
                    if let status = self.statusCache.get(for: path, in: watchedFolder) {
                        DispatchQueue.global(qos: .background).async {
                            self.finderSync.updateBadge(for: url, with: status)
                        }
                        return
                    }
                    
                    // OK, status is not in the cache, maybe it is in the Db?
                    DispatchQueue.global(qos: .background).async {
                        if let status = self.statusCache.getAndCheckDb(for: path, in: watchedFolder) {
                            self.finderSync.updateBadge(for: url, with: status)
                            return
                        } else {
                            // status is not in the Db, request it
                            self.queries.addRequestV2Async(for: path, in: watchedFolder)
                            self.appTurtleMessagePort.notifyBadgeRequestsPendingDebounce()
                        }
                    }
                } else {
                    TurtleLog.error("could not get a relative path for '\(absolutePath)' in \(watchedFolder)")
                }
            } else {
                TurtleLog.error("could not find watched parent for url= \(url)")
            }
        } else {
            TurtleLog.error("could not find path for url= \(url)")
        }
    }
    
    func beginObservingDirectory(at url: URL) {
        TurtleLog.debug("beginObservingDirectory for \(url) \(finderSync.id())")
        if let absolutePath = PathUtils.path(for: url) {
            for watchedFolder in watchedFolders {
                if absolutePath.starts(with: watchedFolder.pathString) {
                    if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                        queries.addVisibleFolderAsync(for: path, in: watchedFolder, processID: finderSync.id())
                        self.appTurtleMessagePort.notifyVisibleFolderUpdatesPendingDebounce()
                        
                        return
                    } else {
                        TurtleLog.error("beginObservingDirectory: could not get relative path for \(absolutePath) in \(watchedFolder)")
                    }
                }
            }
        } else {
            TurtleLog.error("beginObservingDirectory: error, could not generate path for URL '\(url)'")
        }
        TurtleLog.error("beginObservingDirectory: error, could not find watched folder for URL '\(url)' path='\(PathUtils.path(for: url) ?? "")' in watched folders \(WatchedFolder.pretty(watchedFolders))")
    }
    
    func endObservingDirectory(at url: URL) {
        TurtleLog.debug("endObservingDirectory for \(url) \(finderSync.id())")
        if let absolutePath = PathUtils.path(for: url) {
            for watchedFolder in watchedFolders {
                if absolutePath.starts(with: watchedFolder.pathString) {
                    if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                        queries.removeVisibleFolderAsync(for: path, in: watchedFolder, processID: finderSync.id())
                        self.appTurtleMessagePort.notifyVisibleFolderUpdatesPendingDebounce()

                        return
                    } else {
                        TurtleLog.error("endObservingDirectory: could not get relative path for \(absolutePath) in \(watchedFolder)")
                    }
                }
            }
        } else {
            TurtleLog.error("endObservingDirectory: error, could not generate path for URL '\(url)'")
        }
        TurtleLog.error("endObservingDirectory: error, could not find watched folder for URL '\(url)' path='\(PathUtils.path(for: url) ?? "")' in watched folders \(WatchedFolder.pretty(watchedFolders))")
    }
    
    func updateWatchedFolders(queries: Queries) {
        let newWatchedFolders: Set<WatchedFolder> = queries.allWatchedFoldersBlocking()
        if newWatchedFolders != watchedFolders {
            watchedFolders = newWatchedFolders
            DispatchQueue.global(qos: .background).async {
                self.finderSync.setWatchedFolders(to: Set(self.watchedFolders.map { URL(fileURLWithPath: $0.pathString) }))
            }
            
            TurtleLog.info("Finder Sync is now watching: [\(WatchedFolder.pretty(watchedFolders))]")
        }
    }
    
    func handleDatabaseUpdatesIfAny() -> Bool {
        if let moreRecentUpdatesTime = queries.timeOfMoreRecentUpdatesBlocking(lastHandled: lastHandledDatabaseChangesDateSinceEpochAsDouble) {
            // save this new time, marking it as handled (for this process only)
            lastHandledDatabaseChangesDateSinceEpochAsDouble = moreRecentUpdatesTime
            
            updateWatchedFolders(queries: queries)
            updateStatusCacheAndBadgesForAllVisible()
            return true
        }
        
        return false
    }
    
    private func updateStatusCacheAndBadgesForAllVisible() {
        for watchedFolder in self.watchedFolders {
            let statuses: [PathStatus] = queries.allVisibleStatusesV2Blocking(in: watchedFolder, processID: finderSync.id())
            for status in statuses {
                if let cachedStatus = statusCache.get(for: status.path, in: watchedFolder), cachedStatus == status {
                    // OK, this value is identical to the one in our cache, ignore
                    TurtleLog.trace("ignoring identical value old=\(cachedStatus) new \(status) \(finderSync.id())")
                } else {
                    // updated value
                    TurtleLog.debug("updating to \(status) \(finderSync.id())")
                    let url = PathUtils.url(for: status.path, in: watchedFolder)
                    statusCache.put(status: status, for: status.path, in: watchedFolder)
                    DispatchQueue.global(qos: .background).async {
                        self.finderSync.updateBadge(for: url, with: status)
                    }
                }
            }
        }
    }
    
    func commandRequest(with command: GitOrGitAnnexCommand, item: URL) {
        if let absolutePath = PathUtils.path(for: item) {
            for watchedFolder in watchedFolders {
                if absolutePath.starts(with: watchedFolder.pathString) {
                    if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                        queries.submitCommandRequest(for: path, in: watchedFolder, commandType: command.commandType, commandString: command.commandString)
                        appTurtleMessagePort.notifyCommandRequestsPendingDebounce()
                    } else {
                        TurtleLog.error("could not find relative path for \(absolutePath) in \(watchedFolder)")
                    }
                    return
                }
            }
            TurtleLog.error("could not find watchedFolder for \(item)")
        } else {
            TurtleLog.error("could not find absolute path for \(item)")
        }
    }
    
    func status(for item: URL) -> PathStatus? {
        if let absolutePath = PathUtils.path(for: item) {
            for watchedFolder in watchedFolders {
                if absolutePath.starts(with: watchedFolder.pathString) {
                    if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                        return statusCache.get(for: path, in: watchedFolder)
                    } else {
                        TurtleLog.error("menu: could not retrieve relative path for \(absolutePath) in \(watchedFolder)")
                    }
                }
            }
        }
        return nil
    }
    
    func watchedFolderParent(for path: String) -> WatchedFolder? {
        for watchedFolder in self.watchedFolders {
            if path.starts(with: watchedFolder.pathString) {
                return watchedFolder
            }
        }
        return nil
    }
    
    func watchedFolderParent(for pathURL: URL?) -> WatchedFolder? {
        if let path = PathUtils.path(for: pathURL) {
            return watchedFolderParent(for: path)
        }
        return nil
    }
}
