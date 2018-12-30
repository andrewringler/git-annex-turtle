//
//  WatchedFolders.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 5/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class WatchedFolders: HasWatchedFolders {
    let updateListOfWatchedFoldersLock = NSLock()
    let startFullScanForWatchedFoldersWithNoHistoryInDbLock = NSLock()
    var watchedFolders = Set<WatchedFolder>()

    let config: Config
    let gitAnnexTurtle: GitAnnexTurtle
    let gitAnnexQueries: GitAnnexQueries
    let queries: Queries
    let fullScan: FullScan
    let canRecheckFoldersForUpdates: CanRecheckFoldersForUpdates
    let watchedFolderWatches: WatchedFolderWatches
    
    init(config: Config, gitAnnexTurtle: GitAnnexTurtle, gitAnnexQueries: GitAnnexQueries, queries: Queries, fullScan: FullScan, watchedFolderWatches: WatchedFolderWatches, canRecheckFoldersForUpdates: CanRecheckFoldersForUpdates) {
        self.config = config
        self.gitAnnexTurtle = gitAnnexTurtle
        self.gitAnnexQueries = gitAnnexQueries
        self.queries = queries
        self.fullScan = fullScan
        self.watchedFolderWatches = watchedFolderWatches
        self.canRecheckFoldersForUpdates = canRecheckFoldersForUpdates
    }

    func getWatchedFolders() -> Set<WatchedFolder> {
        return watchedFolders
    }
    
    // Read in list of watched folders from Config (or create)
    // also populates menu with correct folders (if any)
    public func updateListOfWatchedFolders() {
        updateListOfWatchedFoldersLock.lock()
        // For all watched folders, if it has a valid git-annex UUID then
        // assume it is a valid git-annex folder and start monitoring it
        var newWatchedFolders = Set<WatchedFolder>()
        let newWatchedRepoPaths = config.listWatchedRepos()
        for watchedFolder in newWatchedRepoPaths {
            if let containedInThisParent = (newWatchedRepoPaths.filter {
                return watchedFolder.path != $0.path && watchedFolder.path.starts(with: $0.path) }).first {
                TurtleLog.info("Cannot monitor '\(watchedFolder.path)' nested inside \(containedInThisParent.path), will ignore.")
                continue
            }
            
            if let uuid = gitAnnexQueries.gitGitAnnexUUID(in: watchedFolder.path) {
                if let existingWatchedFolder = (watchedFolders.filter {
                    return $0.uuid == uuid && $0.pathString == watchedFolder.path }).first {
                    // If we already have this WatchedFolder, re-use the object
                    // so current queries are not interrupted
                    existingWatchedFolder.shareRemote = ShareSettings(shareRemote: watchedFolder.shareRemote, shareLocalPath: watchedFolder.shareLocalPath)
                    newWatchedFolders.insert(existingWatchedFolder)
                } else {
                    // OK, we don't already have this watched folder
                    // create a new object with a new handleStatusRequests
                    let newWatchedFolder = WatchedFolder(uuid: uuid, pathString: watchedFolder.path)
                    newWatchedFolder.shareRemote = ShareSettings(shareRemote: watchedFolder.shareRemote, shareLocalPath: watchedFolder.shareLocalPath)
                    let handleStatusRequests = HandleStatusRequestsProduction(newWatchedFolder, queries: queries, gitAnnexQueries: gitAnnexQueries, canRecheckFoldersForUpdates: canRecheckFoldersForUpdates)
                    newWatchedFolder.handleStatusRequests = handleStatusRequests
                    newWatchedFolders.insert(newWatchedFolder)
                }
            } else {
                // TODO let the user know this?
                TurtleLog.error("Could not find valid git-annex UUID for '%@', not monitoring", watchedFolder.path)
            }
        }
        
        if newWatchedFolders != watchedFolders {
            let previousWatchedFolders = watchedFolders
            watchedFolders = newWatchedFolders // atomically set the new array
            
            // Stop any full scans that might be runnning for a removed folder
            // Stop any file system watches
            for watchedFolder in previousWatchedFolders {
                if !watchedFolders.contains(watchedFolder) {
                    TurtleLog.info("Stopped monitoring \(watchedFolder)")
                    
                    fullScan.stopFullScan(watchedFolder: watchedFolder)
                    watchedFolderWatches.remove(watchedFolder)
                }
            }
            TurtleLog.info("Finder Sync is now monitoring: [\(WatchedFolder.pretty(watchedFolders))]")
            
            // Save updated folder list to the database
            queries.updateWatchedFoldersBlocking(to: watchedFolders.sorted())
            
            startFullScanForWatchedFoldersWithNoHistoryInDb()
            watchedFolderWatches.setupMissingWatches()
        }
        
        // Update UI
        gitAnnexTurtle.updateMenubarData(with: watchedFolders)
        
        updateListOfWatchedFoldersLock.unlock()
    }
    
    // Start a full scan for any folder with no git annex commit information
    public func startFullScanForWatchedFoldersWithNoHistoryInDb() {
        startFullScanForWatchedFoldersWithNoHistoryInDbLock.lock()
        for watchedFolder in getWatchedFolders() {
            // Last commit hash that we have handled (from the database)
            let handledCommits = queries.getLatestCommits(for: watchedFolder)
            
            if handledCommits.gitAnnexCommitHash == nil {
                fullScan.startFullScan(watchedFolder: watchedFolder, success: watchedFolderWatches.setupMissingWatches)
            }
        }
        startFullScanForWatchedFoldersWithNoHistoryInDbLock.unlock()
    }
}
