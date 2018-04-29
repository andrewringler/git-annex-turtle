//
//  TheMainLoop.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 3/13/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

protocol HasWatchedFolders {
    func getWatchedFolders() -> Set<WatchedFolder>
}
protocol CanRecheckFoldersForUpdates {
    func recheckFolderUpdates()
}

class WatchGitAndFinderForUpdates: StoppableService, HasWatchedFolders, CanRecheckFoldersForUpdates, CanRecheckGitCommitsAndFullScans {
    let config: Config
    let preferences: Preferences
    let gitAnnexTurtle: GitAnnexTurtle
    let data: DataEntrypoint
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let visibleFolders: VisibleFolders
    let fullScan: FullScan
    let dialogs: Dialogs
    var watchedFolderWatches: WatchedFolderWatches?
    var processFolderUpdates: RunNowOrAgain?
    let updateBinaryPathsLock = NSLock()
    let updateListOfWatchedFoldersLock = NSLock()
    let startFullScanForWatchedFoldersWithNoHistoryInDbLock = NSLock()
    
    var watchedFolders = Set<WatchedFolder>()
    var listenForConfigChanges: Witness? = nil
    
    init(gitAnnexTurtle: GitAnnexTurtle, config: Config, data: DataEntrypoint, fullScan: FullScan, gitAnnexQueries: GitAnnexQueries, dialogs: Dialogs, visibleFolders: VisibleFolders, preferences: Preferences) {
        self.gitAnnexTurtle = gitAnnexTurtle
        self.config = config
        self.preferences = preferences
        self.data = data
        self.fullScan = fullScan
        self.gitAnnexQueries = gitAnnexQueries
        self.dialogs = dialogs
        self.visibleFolders = visibleFolders
        queries = Queries(data: data)
        super.init()

        self.watchedFolderWatches = WatchedFolderWatches(app: self)
        self.processFolderUpdates = RunNowOrAgain {
            self.checkAllFoldersForCompletion()
        }

        updateListOfWatchedFolders()
        setupFileSystemMonitorOnConfigFile()
        processFolderUpdates?.runTaskAgain()
    }
    
    public func recheckFolderUpdates() {
        processFolderUpdates?.runTaskAgain()
    }
    
    // Recheck if folders are waiting to run full scans on
    // Recheck if folders have git updates that need processing
    // this can happen if the user has invalid git/git-annex paths for some duration
    public func recheckForGitCommitsAndFullScans() {
        updateListOfWatchedFolders()
        startFullScanForWatchedFoldersWithNoHistoryInDb()
        watchedFolderWatches!.checkAll()
    }
    
    // Handle folder updates, for any folder that is not doing a full scan
    private func checkAllFoldersForCompletion() {
        for watchedFolder in self.watchedFolders {
            if !self.fullScan.isScanning(watchedFolder: watchedFolder) {
                _ = FolderTracking.handleFolderUpdates(watchedFolder: watchedFolder, queries: self.queries, gitAnnexQueries: self.gitAnnexQueries)
            }
        }
    }
    
    // Handle changes in the config file, preferences, list of watched folders, etc…
    private func handleConfigUpdates() {
        updateBinaryPaths()
        updateListOfWatchedFolders()
    }
    
    private func updateBinaryPaths() {
        updateBinaryPathsLock.lock()
        if let newGitBin = config.gitBin(), !newGitBin.isEmpty, let workingDirectory = PathUtils.parent(absolutePath: config.dataPath), FindBinaries.validGit(workingDirectory: workingDirectory, gitAbsolutePath: newGitBin) {
            preferences.setGitBin(gitBin: newGitBin)
        }
        
        if let newGitAnnexBin = config.gitAnnexBin(), !newGitAnnexBin.isEmpty, let workingDirectory = PathUtils.parent(absolutePath: config.dataPath), FindBinaries.validGitAnnex(workingDirectory: workingDirectory, gitAnnexAbsolutePath: newGitAnnexBin) {
            preferences.setGitAnnexBin(gitAnnexBin: newGitAnnexBin)
        }
        updateBinaryPathsLock.unlock()
    }
    
    // Read in list of watched folders from Config (or create)
    // also populates menu with correct folders (if any)
    private func updateListOfWatchedFolders() {
        updateListOfWatchedFoldersLock.lock()
        // For all watched folders, if it has a valid git-annex UUID then
        // assume it is a valid git-annex folder and start monitoring it
        var newWatchedFolders = Set<WatchedFolder>()
        for watchedFolder in config.listWatchedRepos() {
            if let uuid = gitAnnexQueries.gitGitAnnexUUID(in: watchedFolder) {
                if let existingWatchedFolder = (watchedFolders.filter {
                    return $0.uuid == uuid && $0.pathString == watchedFolder }).first {
                    // If we already have this WatchedFolder, re-use the object
                    // so current queries are not interrupted
                    newWatchedFolders.insert(existingWatchedFolder)
                } else {
                    // OK, we don't already have this watched folder
                    // create a new object with a new handleStatusRequests
                    let newWatchedFolder = WatchedFolder(uuid: uuid, pathString: watchedFolder)
                    let handleStatusRequests = HandleStatusRequestsProduction(newWatchedFolder, queries: queries, gitAnnexQueries: gitAnnexQueries, canRecheckFoldersForUpdates: self)
                    newWatchedFolder.handleStatusRequests = handleStatusRequests
                    newWatchedFolders.insert(newWatchedFolder)
                }
            } else {
                // TODO let the user know this?
                TurtleLog.error("Could not find valid git-annex UUID for '%@', not monitoring", watchedFolder)
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
                    watchedFolderWatches!.remove(watchedFolder)
                }
            }
            
            gitAnnexTurtle.updateMenubarData(with: watchedFolders)
            
            TurtleLog.info("Finder Sync is now monitoring: [\(WatchedFolder.pretty(watchedFolders))]")
            
            // Save updated folder list to the database
            let queries = Queries(data: data)
            queries.updateWatchedFoldersBlocking(to: watchedFolders.sorted())
            
            startFullScanForWatchedFoldersWithNoHistoryInDb()
            watchedFolderWatches!.setupMissingWatches()
        }
        updateListOfWatchedFoldersLock.unlock()
    }
    
    //
    // Watch List Config File Updates: ~/.config/git-annex/turtle-monitor
    //
    // in addition to changing the watched folders via the Menubar GUI, users may
    // edit the config file directly. We will attach a file system monitor to detect this
    //
    private func setupFileSystemMonitorOnConfigFile() {
        let handleConfigUpdatesDebounce = debounce(delay: .milliseconds(200), queue: DispatchQueue.global(qos: .background), action: handleConfigUpdates)
        listenForConfigChanges = Witness(paths: [config.dataPath], flags: .FileEvents, latency: 0.3) { events in
            handleConfigUpdatesDebounce()
        }
    }
    
    // Start a full scan for any folder with no git annex commit information
    private func startFullScanForWatchedFoldersWithNoHistoryInDb() {
        startFullScanForWatchedFoldersWithNoHistoryInDbLock.lock()
        for watchedFolder in watchedFolders {
            // Last commit hash that we have handled (from the database)
            let handledCommits = queries.getLatestCommits(for: watchedFolder)
            
            if handledCommits.gitAnnexCommitHash == nil {
                fullScan.startFullScan(watchedFolder: watchedFolder, success: watchedFolderWatches!.setupMissingWatches)
            }
        }
        startFullScanForWatchedFoldersWithNoHistoryInDbLock.unlock()
    }
    
    // updates from Watched Folder monitor
    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double) {
        checkForGitAnnexUpdates(in: watchedFolder, secondsOld: secondsOld, includeFiles: true, includeDirs: false)
    }

    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool) {
        TurtleLog.debug("Checking for updates in \(watchedFolder)")
        
        var paths: [String] = []
        
        // Last commit hash that we have handled (from the database)
        let handledCommits = queries.getLatestCommits(for: watchedFolder)
        let handledGitCommitHashOptional = handledCommits.gitCommitHash
        let handledGitAnnexCommitHashOptional = handledCommits.gitAnnexCommitHash
        
        // We are still performing a full scan for this folder
        // no incremental updates to perform yet
        if handledGitAnnexCommitHashOptional == nil {
            return
        }
        
        // Current commit hashes (un-handled)
        let currentGitCommitHash = gitAnnexQueries.latestGitCommitHashBlocking(in: watchedFolder)
        let currentGitAnnexCommitHash = gitAnnexQueries.latestGitAnnexCommitHashBlocking(in: watchedFolder)
        
        /* Commits to git could mean:
         * - new file content (we should update key)
         * - existing file points to new content in git-annex
         * - change in lock/unlock state
         * - add/drop for a path
         */
        if let handledGitCommitHash = handledGitCommitHashOptional {
            let gitPaths = gitAnnexQueries.allFileChangesGitSinceBlocking(commitHash: handledGitCommitHash, in: watchedFolder)
            paths += gitPaths
        } else if currentGitCommitHash != nil {
            // we have never handled a git commit, if there is at least one
            // then we'll grab all files ever mentioned in any git commit
            let gitPaths = gitAnnexQueries.allFileChangesInGitLog(in: watchedFolder)
            paths += gitPaths
        }
        
        /* Commits to git-annex branch could mean:
         * - location updates for file content
         */
        if let handledGitAnnexCommitHash = handledGitAnnexCommitHashOptional {
            let keysChanged = gitAnnexQueries.allKeysWithLocationsChangesGitAnnexSinceBlocking(commitHash: handledGitAnnexCommitHash, in: watchedFolder)
            let newPaths = Queries(data: data).pathsWithStatusesGivenAnnexKeysBlocking(keys: keysChanged, in: watchedFolder)
            paths += newPaths
            
            if keysChanged.count != newPaths.count {
                // for 1 or more paths we were unable to find an associated key
                // perhaps user did a `git annex add` via the commandline
                // if the path was ever shown in a Finder window we will have
                // a not-tracked entry for it, lets re-check all of our untracked paths
                let newPaths = Queries(data: data).allNonTrackedPathsBlocking(in: watchedFolder)
                TurtleLog.debug("Checking non tracked paths \(newPaths)")
                paths += newPaths
            }
        }
        paths = Set<String>(paths).sorted() // remove duplicates
        
        if paths.count > 0 {
            TurtleLog.debug("Requesting updated statuses for \(paths)")
        }
        
        for path in paths {
            var priority: Priority = .low
            if visibleFolders.isVisible(relativePath: path, in: watchedFolder) {
                priority = .high
            }
            
            // git & git-annex don't report new folders directly
            // so infer them from the files within
            queries.addAllMissingParentFolders(for: path, in: watchedFolder)
            
            watchedFolder.handleStatusRequests!.updateStatusFor(for: path, source: .gitlog, isDir: nil, priority: priority)
        }
        
        // OK, we have queued all changed paths for updates
        // from the last handled commit, up-to and including the
        // latest commit (that was available before we started)
        queries.updateLatestHandledCommit(gitCommitHash: currentGitCommitHash, gitAnnexCommitHash: currentGitAnnexCommitHash, in: watchedFolder)
    }
    
    func getWatchedFolders() -> Set<WatchedFolder> {
        return watchedFolders
    }
    
    func handlingStatusRequests() -> Bool {
        for watchedFolder in watchedFolders {
            if watchedFolder.handleStatusRequests!.handlingRequests() {
                return true
            }
        }
        return false
    }
    
    override public func stop() {
        watchedFolderWatches?.stop()
        listenForConfigChanges = nil
        super.stop()
    }
}
