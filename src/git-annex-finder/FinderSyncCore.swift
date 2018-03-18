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

class FinderSyncCore {
    let finderSync: FinderSyncProtocol
    let data: DataEntrypoint
    let queries: Queries
    let statusCache: StatusCache

    private var watchedFolders = Set<WatchedFolder>()
    private var lastHandledDatabaseChangesDateSinceEpochAsDouble: Double = 0
    
    init(finderSync: FinderSyncProtocol, data: DataEntrypoint) {
        self.finderSync = finderSync
        self.data = data
        statusCache = StatusCache(data: data)
        queries = Queries(data: data)

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
        //
        // NOTE:
        // I tried using File System API monitors on the sqlite database
        // and I tried using observe on UserDefaults
        // none worked reliably, perhaps Finder Sync Extensions are designed to ignore/miss notifications?
        // or perhaps the Finder Sync extension is going into a background mode and not waking up?
        // or perhaps Finder Sync extensions are meant to be transient, so can never
        // really accept notifications from the system
        //
        // TODO ooops, probably I was just registering them on a background thread
        // File System API registration requests must happen on the main thread…
        // try and retest
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleDatabaseUpdatesIfAny()
                usleep(100000)
            }
        }
    }
    
    func requestBadgeIdentifier(for url: URL) {
        TurtleLog.debug("requestBadgeIdentifier for \(url) \(finderSync.id())")
        
        if let absolutePath = PathUtils.path(for: url) {
            if let watchedFolder = self.watchedFolderParent(for: absolutePath) {
                if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                    // Request the folder:
                    // we may already have this path in our cache
                    // but we still want to create a request to let the main app know
                    // that this path is still fresh and still in view
                    DispatchQueue.global(qos: .background).async {
                        self.queries.addRequestV2Async(for: path, in: watchedFolder)
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
    
    func handleDatabaseUpdatesIfAny() {
        if let moreRecentUpdatesTime = queries.timeOfMoreRecentUpdatesBlocking(lastHandled: lastHandledDatabaseChangesDateSinceEpochAsDouble) {
            // save this new time, marking it as handled (for this process only)
            lastHandledDatabaseChangesDateSinceEpochAsDouble = moreRecentUpdatesTime
            
            updateWatchedFolders(queries: queries)
            updateStatusCacheAndBadgesForAllVisible()
        }
    }
    
    private func updateStatusCacheAndBadgesForAllVisible() {
        for watchedFolder in self.watchedFolders {
            let statuses: [PathStatus] = queries.allVisibleStatusesV2Blocking(in: watchedFolder, processID: finderSync.id())
            for status in statuses {
                if let cachedStatus = statusCache.get(for: status.path, in: watchedFolder), cachedStatus == status {
                    // OK, this value is identical to the one in our cache, ignore
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
    
    private func watchedFolderParent(for path: String) -> WatchedFolder? {
        for watchedFolder in self.watchedFolders {
            if path.starts(with: watchedFolder.pathString) {
                return watchedFolder
            }
        }
        return nil
    }
}
