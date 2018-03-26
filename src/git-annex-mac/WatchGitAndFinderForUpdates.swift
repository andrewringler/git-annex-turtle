//
//  TheMainLoop.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 3/13/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class WatchGitAndFinderForUpdates: StoppableService {
    let config: Config
    let gitAnnexTurtle: GitAnnexTurtle
    let data: DataEntrypoint
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let visibleFolders: VisibleFolders
    let fullScan: FullScan
    let handleStatusRequests: HandleStatusRequests
    let dialogs: Dialogs
    
    var watchedFolders = Set<WatchedFolder>()
    var fileSystemMonitors: [WatchedFolderMonitor] = []
    var listenForWatchedFolderChanges: Witness? = nil
    
    init(gitAnnexTurtle: GitAnnexTurtle, config: Config, data: DataEntrypoint, fullScan: FullScan, handleStatusRequests: HandleStatusRequests, gitAnnexQueries: GitAnnexQueries, dialogs: Dialogs) {
        self.gitAnnexTurtle = gitAnnexTurtle
        self.config = config
        self.data = data
        self.fullScan = fullScan
        self.handleStatusRequests = handleStatusRequests
        self.gitAnnexQueries = gitAnnexQueries
        self.dialogs = dialogs
        
        queries = Queries(data: data)
        visibleFolders = VisibleFolders(queries: queries)

        super.init()

        updateListOfWatchedFolders()
        setupFileSystemMonitorOnConfigFile()

        // Handle command, badge requests and visible folder updates from Finder Sync
        // check if incomplete folders have finished scanning their children
        DispatchQueue.global(qos: .background).async {
            while super.running.isRunning() {
                let foundUpdates = self.handleDatabaseUpdates()
                if !foundUpdates {
                    // if we didn't get any database updates, lets give the CPU a rest
                    usleep(150000)
                }
            }
        }
        _ = handleDatabaseUpdates() // check Db for updates, once now
    }
    
    private func handleDatabaseUpdates() -> Bool {
        let foundUpdatesCommands = handleCommandRequests()
        let foundUpdatesBadges = handleBadgeRequests()
        
        // does not contribute to foundUpdates, since these are all things
        // that don't necessary change rapidly
        updateWatchedAndVisibleFolders()
        
        return foundUpdatesCommands || foundUpdatesBadges
    }
    
    private func updateWatchedAndVisibleFolders() {
        self.visibleFolders.updateListOfVisibleFolders(with: self.watchedFolders)
        
        // Handle folder updates, for any folder that is not doing a full scan
        for watchedFolder in self.watchedFolders {
            if !self.fullScan.isScanning(watchedFolder: watchedFolder) {
                _ = FolderTracking.handleFolderUpdates(watchedFolder: watchedFolder, queries: self.queries, gitAnnexQueries: self.gitAnnexQueries)
            }
        }
        
        // Setup file system watches for any folder that has completed its full scan
        // that we aren't already watching
        for watchedFolder in self.watchedFolders {
            // A folder we need to start a file system watch for, is one
            // that has a commit hash in the database (meaning it is done with a full scan)
            // and one that isn't already being watched
            let handledCommits = self.queries.getLatestCommits(for: watchedFolder)
            if handledCommits.gitAnnexCommitHash != nil, (self.fileSystemMonitors.filter{ $0.watchedFolder == watchedFolder }).count == 0 {
                // Setup filesystem watch
                // must happen on main thread for Apple File System Events API to work
                if (Thread.isMainThread) {
                    let monitor = WatchedFolderMonitor(watchedFolder: watchedFolder, app: self)
                    self.fileSystemMonitors.append(monitor)
                    
                    // run once now, in case we missed some while setting up watch
                    monitor.doUpdates()
                } else {
                    DispatchQueue.main.sync {
                        let monitor = WatchedFolderMonitor(watchedFolder: watchedFolder, app: self)
                        self.fileSystemMonitors.append(monitor)
                        
                        // run once now, in case we missed some while setting up watch
                        monitor.doUpdates()
                    }
                }
            }
        }
    }
    
    // Read in list of watched folders from Config (or create)
    // also populates menu with correct folders (if any)
    private func updateListOfWatchedFolders() {
        // For all watched folders, if it has a valid git-annex UUID then
        // assume it is a valid git-annex folder and start monitoring it
        var newWatchedFolders = Set<WatchedFolder>()
        for watchedFolder in config.listWatchedRepos() {
            if let uuid = gitAnnexQueries.gitGitAnnexUUID(in: watchedFolder) {
                newWatchedFolders.insert(WatchedFolder(uuid: uuid, pathString: watchedFolder))
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
                    if let index = fileSystemMonitors.index(where: { $0.watchedFolder == watchedFolder} ) {
                        fileSystemMonitors.remove(at: index)
                    }
                }
            }
            
            gitAnnexTurtle.updateMenubarData(with: watchedFolders)
            
            TurtleLog.info("Finder Sync is now monitoring: [\(WatchedFolder.pretty(watchedFolders))]")
            
            // Save updated folder list to the database
            let queries = Queries(data: data)
            queries.updateWatchedFoldersBlocking(to: watchedFolders.sorted())
            
            startFullScanForWatchedFoldersWithNoHistoryInDb()
        }
    }
    
    //
    // Watch List Config File Updates: ~/.config/git-annex/turtle-monitor
    //
    // in addition to changing the watched folders via the Menubar GUI, users may
    // edit the config file directly. We will attach a file system monitor to detect this
    //
    private func setupFileSystemMonitorOnConfigFile() {
        let updateListOfWatchedFoldersDebounce = debounce(delay: .milliseconds(200), queue: DispatchQueue.global(qos: .background), action: updateListOfWatchedFolders)
        listenForWatchedFolderChanges = Witness(paths: [config.dataPath], flags: .FileEvents, latency: 0.3) { events in
            updateListOfWatchedFoldersDebounce()
        }
    }
    
    // Start a full scan for any folder with no git annex commit information
    private func startFullScanForWatchedFoldersWithNoHistoryInDb() {
        for watchedFolder in watchedFolders {
            // Last commit hash that we have handled (from the database)
            let handledCommits = queries.getLatestCommits(for: watchedFolder)
            
            if handledCommits.gitAnnexCommitHash == nil {
                fullScan.startFullScan(watchedFolder: watchedFolder)
            }
        }
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
            
            handleStatusRequests.updateStatusFor(for: path, in: watchedFolder, secondsOld: secondsOld, includeFiles: includeFiles, includeDirs: includeDirs, priority: priority)
        }
        
        // OK, we have queued all changed paths for updates
        // from the last handled commit, up-to and including the
        // latest commit (that was available before we started)
        queries.updateLatestHandledCommit(gitCommitHash: currentGitCommitHash, gitAnnexCommitHash: currentGitAnnexCommitHash, in: watchedFolder)
    }
    
    //
    // Command Requests
    //
    // handle command requests "git annex get/add/drop/etc…" comming from our Finder Sync extensions
    //
    private func handleCommandRequests() -> Bool {
        let queries = Queries(data: self.data)
        let commandRequests = queries.fetchAndDeleteCommandRequestsBlocking()
        
        for commandRequest in commandRequests {
            for watchedFolder in self.watchedFolders {
                if watchedFolder.uuid.uuidString == commandRequest.watchedFolderUUIDString {
                    // Is this a Git Annex Command?
                    if commandRequest.commandType.isGitAnnex {
                        let status = gitAnnexQueries.gitAnnexCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString)
                        if !status.success {
                            // git-annex has very nice error message, use them as-is
                            dialogs.dialogOK(title: status.error.first ?? "git-annex: error", message: status.output.joined(separator: "\n"))
                        } else {
                            // success, update this file status right away
                            //                            self.updateStatusNowAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    // Is this a Git Command?
                    if commandRequest.commandType.isGit {
                        let status = gitAnnexQueries.gitCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString)
                        if !status.success {
                            dialogs.dialogOK(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                        } else {
                            // success, update this file status right away
                            //                            self.updateStatusNowAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    break
                }
            }
        }
        
        return commandRequests.count > 0
    }
    
    //
    // Badge Icon Requests
    //
    // handle requests for updated badge icons from our Finder Sync extension
    //
    private func handleBadgeRequests() -> Bool {
        var foundUpdates = false
        
        for watchedFolder in self.watchedFolders {
            // Only handle badge requests for folders that aren't currently being scanned
            // TODO, give immediate feedback to the user here on some files?
            // TODO, we can miss some files if they appear after full scan enumeration
            if !fullScan.isScanning(watchedFolder: watchedFolder) {
                for path in queries.allPathRequestsV2Blocking(in: watchedFolder) {
                    foundUpdates = true
                    
                    if queries.statusForPathV2Blocking(path: path, in: watchedFolder) != nil {
                        // OK, we already have a status for this path, maybe
                        // Finder Sync missed it, lets update our last modified flag
                        // to ensure Finder Sync see it
                        queries.updateLastModifiedAsync.runTaskAgain()
                    } else {
                        // We have no information about this file
                        // enqueue it for inspection
                        handleStatusRequests.updateStatusFor(for: path, in: watchedFolder, secondsOld: 0, includeFiles: true, includeDirs: true, priority: .high)
                    }
                }
            }
        }
        
        return foundUpdates
    }
    
    func getWatchedFolders() -> Set<WatchedFolder> {
        return watchedFolders
    }
    
    override public func stop() {
        handleStatusRequests.stop()
        fileSystemMonitors.forEach { $0.stop() }
        fileSystemMonitors = []
        listenForWatchedFolderChanges = nil
        super.stop()
    }
}
