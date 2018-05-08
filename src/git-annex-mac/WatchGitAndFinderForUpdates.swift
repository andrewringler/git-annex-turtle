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

class WatchGitAndFinderForUpdates: StoppableService, CanRecheckFoldersForUpdates, CanRecheckGitCommitsAndFullScans {
    let config: Config
    let preferences: Preferences
    let gitAnnexTurtle: GitAnnexTurtle
    let data: DataEntrypoint
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let visibleFolders: VisibleFolders
    let fullScan: FullScan
    let dialogs: Dialogs
    let updateBinaryPathsLock = NSLock()
    
    var listenForConfigChanges: Witness?
    
    lazy var watchedFolderWatches: WatchedFolderWatches = {
        return WatchedFolderWatches(app: self)
    }()
    lazy var processFolderUpdates = RunNowOrAgain {
        return self.checkAllFoldersForCompletion()
    }
    lazy var watchedFolders: WatchedFolders = {
       return WatchedFolders(config: config, gitAnnexTurtle: gitAnnexTurtle, gitAnnexQueries: gitAnnexQueries, queries: queries, fullScan: fullScan, watchedFolderWatches: watchedFolderWatches, canRecheckFoldersForUpdates: self)
    }()
    
    init(gitAnnexTurtle: GitAnnexTurtle, config: Config, data: DataEntrypoint, fullScan: FullScan, gitAnnexQueries: GitAnnexQueries, dialogs: Dialogs, visibleFolders: VisibleFolders, preferences: Preferences) {
        self.gitAnnexTurtle = gitAnnexTurtle
        self.config = config
        self.preferences = preferences
        self.data = data
        self.fullScan = fullScan
        self.gitAnnexQueries = gitAnnexQueries
        self.dialogs = dialogs
        self.visibleFolders = visibleFolders
        self.queries = Queries(data: data)
        
        super.init()

        listenForConfigChanges = setupFileSystemMonitorOnConfigFile()
        watchedFolders.updateListOfWatchedFolders()
        processFolderUpdates.runTaskAgain()
    }
    
    public func recheckFolderUpdates() {
        processFolderUpdates.runTaskAgain()
    }
    
    // Recheck if folders are waiting to run full scans on
    // Recheck if folders have git updates that need processing
    // this can happen if the user has invalid git/git-annex paths for some duration
    public func recheckForGitCommitsAndFullScans() {
        watchedFolders.updateListOfWatchedFolders()
        watchedFolders.startFullScanForWatchedFoldersWithNoHistoryInDb()
        watchedFolderWatches.checkAll()
    }
    
    // Handle folder updates, for any folder that is not doing a full scan
    private func checkAllFoldersForCompletion() {
        for watchedFolder in watchedFolders.getWatchedFolders() {
            if !self.fullScan.isScanning(watchedFolder: watchedFolder) {
                _ = FolderTracking.handleFolderUpdates(watchedFolder: watchedFolder, queries: self.queries, gitAnnexQueries: self.gitAnnexQueries)
            }
        }
    }
    
    // Handle changes in the config file, preferences, list of watched folders, etc…
    private func handleConfigUpdates() {
        updateBinaryPaths()
        watchedFolders.updateListOfWatchedFolders()
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
    
    //
    // Watch List Config File Updates: ~/.config/git-annex/turtle-monitor
    //
    // in addition to changing the watched folders via the Menubar GUI, users may
    // edit the config file directly. We will attach a file system monitor to detect this
    //
    private func setupFileSystemMonitorOnConfigFile() -> Witness {
        let handleConfigUpdatesDebounce = debounce(delay: .milliseconds(200), queue: DispatchQueue.global(qos: .background), action: handleConfigUpdates)
        return Witness(paths: [config.dataPath], flags: .FileEvents, latency: 0.3) { events in
            handleConfigUpdatesDebounce()
        }
    }
    
    // updates from Watched Folder monitor
    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double) {
        checkForGitAnnexUpdates(in: watchedFolder, secondsOld: secondsOld, includeFiles: true, includeDirs: false)
    }

    private func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool) {
        
        // TODO, this is a to fix a deinit timming issue
        // we probably should not have this function be publicly callable
        guard running.isRunning() else {
            return
        }
        
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
    
    func handlingStatusRequests() -> Bool {
        for watchedFolder in watchedFolders.getWatchedFolders() {
            if watchedFolder.handleStatusRequests!.handlingRequests() {
                return true
            }
        }
        return false
    }
    
    override public func stop() {
        watchedFolderWatches.stop()
        listenForConfigChanges = nil
        super.stop()
    }
}
