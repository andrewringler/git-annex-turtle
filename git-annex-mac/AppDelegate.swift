//
//  AppDelegate.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    let gitAnnexLogoSquareColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-color"))
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "menubaricon-0"))
    
    var menubarIcons: [NSImage] = []
    var menubarAnimationIndex: Int = 0
    let menubarIconAnimationLock = NSLock()
    var menubarAnimating: Bool = false

    let data = DataEntrypoint()
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries

    var handleStatusRequests: HandleStatusRequests? = nil
    var watchedFolders = Set<WatchedFolder>()
    var menuBarButton :NSStatusBarButton?
    var preferencesViewController: ViewController? = nil
    var preferencesWindow: NSWindow? = nil
    var fileSystemMonitors: [WatchedFolderMonitor] = []
    var listenForWatchedFolderChanges: Witness? = nil
    var visibleFolders: VisibleFolders? = nil
    var handledGitCommit = WatchedFolderToCommitHash()
    var handledAnnexCommit = WatchedFolderToCommitHash()

    override init() {
        for i in 0...16 {
           menubarIcons.append(NSImage(named:NSImage.Name(rawValue: "menubaricon-\(String(i))"))!)
        }
        let config = Config()
        if let gitAnnexBin = config.gitAnnexBin(), let gitBin = config.gitBin() {
            gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: gitAnnexBin, gitCmd: gitBin)
        } else {
            // TODO put notice in menubar icon
            // allow user to set paths or install
            NSLog("Could not find binary paths for git and git-annex, quitting")
            exit(-1)
        }
        
        queries = Queries(data: data)
        
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = gitAnnexTurtleLogo
            menuBarButton = button
        }
        
        constructMenu(watchedFolders: []) // generate an empty menu stub
        visibleFolders = VisibleFolders(data: data, app: self)
        handleStatusRequests = HandleStatusRequests(queries: Queries(data: self.data), gitAnnexQueries: gitAnnexQueries)
        
        // Menubar Icon > Preferences menu
        preferencesViewController = ViewController.freshController(appDelegate: self)
        
        // Read in list of watched folders from Config (or create)
        // also populates menu with correct folders (if any)
        updateListOfWatchedFoldersAndSetupFileSystemWatches()
        
        //
        // Watch List Config File Updates: ~/.config/git-annex/turtle-watch
        //
        // in addition to changing the watched folders via the Menubar GUI, users may
        // edit the config file directly. We will attach a file system monitor to detect this
        //
        let updateListOfWatchedFoldersDebounce = throttle(delay: 0.1, queue: DispatchQueue.global(qos: .background), action: updateListOfWatchedFoldersAndSetupFileSystemWatches)
        listenForWatchedFolderChanges = Witness(paths: [Config().dataPath], flags: .FileEvents, latency: 0.1) { events in
            updateListOfWatchedFoldersDebounce()
        }
        
        DispatchQueue.global(qos: .background).async {
            // Main loop
            while true {
                // PERFORMANCE, trigger off a file system watch on the Db
                self.visibleFolders?.updateListOfVisibleFolders()

                // PERFORMANCE, trigger off a file system watch on the Db
                FolderTracking.handleFolderUpdates(watchedFolders: self.watchedFolders, queries: self.queries, gitAnnexQueries: self.gitAnnexQueries)
                
                // PERFORMANCE, trigger directly from HandleStatusRequests class
                self.handleAnimateMenubarIcon()

                // PERFORMANCE, trigger off a file system watch on the Db
                self.handleBadgeRequests()
                
                // PERFORMANCE, trigger off a file system watch on the Db
                self.handleCommandRequests()

                usleep(100000)
            }
        }

        DispatchQueue.global(qos: .background).async {
            self.launchOrRelaunchFinderSyncExtension()
        }
    }
    
    private func updateListOfWatchedFoldersAndSetupFileSystemWatches() {
        // Re-read config, it might have changed
        let config = Config()
        
        // For all watched folders, if it has a valid git-annex UUID then
        // assume it is a valid git-annex folder and start watching it
        var newWatchedFolders = Set<WatchedFolder>()
        for watchedFolder in config.listWatchedRepos() {
            if let uuid = gitAnnexQueries.gitGitAnnexUUID(in: watchedFolder) {
                newWatchedFolders.insert(WatchedFolder(uuid: uuid, pathString: watchedFolder))
            } else {
                // TODO let the user know this?
                NSLog("Could not find valid git-annex UUID for '%@', not watching", watchedFolder)
            }
        }
        
        if newWatchedFolders != watchedFolders {
            watchedFolders = newWatchedFolders // atomically set the new array
            constructMenu(watchedFolders: watchedFolders) // update our menubar icon menu
            preferencesViewController?.reloadFileList()

            NSLog("Finder Sync is now watching: [\(WatchedFolder.pretty(watchedFolders))]")

            updateLatestCommitEntriesForWatchedFolders()
            
            // Save updated folder list to the database
            let queries = Queries(data: data)
            queries.updateWatchedFoldersBlocking(to: watchedFolders.sorted())
            
            // Start monitoring the new list of folders
            // TODO, we should only monitor the visible folders sent from Finder Sync
            // in addition to the .git/annex folder for annex updates
            // Monitoring the entire watched folder, is unnecessarily expensive
            fileSystemMonitors = watchedFolders.map {
                WatchedFolderMonitor(watchedFolder: $0, app: self)
            }
        }
    }

    // updates from Watched Folder monitor
    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double) {
        checkForGitAnnexUpdates(in: watchedFolder, secondsOld: secondsOld, includeFiles: true, includeDirs: false)
    }
            
//    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool) {
//        let queries = Queries(data: self.data)
//        let paths = queries.allPathsOlderThanBlocking(in: watchedFolder, secondsOld: secondsOld)
//
//        for path in paths {
//            // ignore non-visible paths
//            if let visible = visibleFolders?.isVisible(path: path), visible {
//                handleStatusRequests?.updateStatusFor(for: path, in: watchedFolder, secondsOld: secondsOld, includeFiles: includeFiles, includeDirs: includeDirs, priority: .low)
//            }
//        }
//    }

    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double, includeFiles: Bool, includeDirs: Bool) {
        NSLog("Checking for updates in \(watchedFolder)")
        
        var paths: [String] = []
        
        let lastGitCommitOptional = handledGitCommit.get(for: watchedFolder)
        let lastAnnexCommitOptional = handledAnnexCommit.get(for: watchedFolder)
        
        // Mark current commits as handled
        updateLatestCommitEntriesForWatchedFolders()
        
        /* Commits to git could mean:
         * - new file content (we should update key)
         * - existing file points to new content in git-annex
         * - change in lock/unlock state
         * - add/drop for a path
         */
        if let lastGitCommit = lastGitCommitOptional {
            var gitPaths = gitAnnexQueries.allFileChangesGitSinceBlocking(commitHash: lastGitCommit, in: watchedFolder)
            // convert relative git paths to absolute paths
//            gitPaths = gitPaths.map { "\(watchedFolder.pathString)/\($0)" }
            paths += gitPaths
        }
        
        /* Commits to git-annex branch could mean:
         * - location updates for file content
         */
        if let lastAnnexCommit = lastAnnexCommitOptional {
            let keysChanged = gitAnnexQueries.allKeysWithLocationsChangesGitAnnexSinceBlocking(commitHash: lastAnnexCommit, in: watchedFolder)
            let newPaths = Queries(data: data).pathsWithStatusesGivenAnnexKeysBlocking(keys: keysChanged, in: watchedFolder)
            paths += newPaths
            
            if keysChanged.count != newPaths.count {
                // for 1 or more paths we were unable to find an associated key
                // perhaps user did a `git annex add` via the commandline
                // if the path was ever shown in a Finder window we will have
                // a not-tracked entry for it, lets re-check all of our untracked paths
                let newPaths = Queries(data: data).allNonTrackedPathsBlocking(in: watchedFolder)
                NSLog("Checking non tracked paths \(newPaths)")
                paths += newPaths
            }
        }
        paths = Set<String>(paths).sorted() // remove duplicates
        
        if paths.count > 0 {
            NSLog("Requesting updated statuses for \(paths)")
        }
        
        for path in paths {
            // TODO, we always care about all paths, right?
            // since we need to potentially update paths for
            // parents that are now visible
//            if let visible = visibleFolders?.isVisible(relativePath: path, in: watchedFolder), visible {
//            }
            
            handleStatusRequests?.updateStatusFor(for: path, in: watchedFolder, secondsOld: secondsOld, includeFiles: includeFiles, includeDirs: includeDirs, priority: .low)
        }
    }
    
    private func updateStatusNowAsync(for path: String, in watchedFolder: WatchedFolder) {
        handleStatusRequests?.updateStatusFor(for: path, in: watchedFolder, secondsOld: 0, includeFiles: true, includeDirs: false, priority: .high)
    }
    
    //
    // Command Requests
    //
    // handle command requests "git annex get/add/drop/etc…" comming from our Finder Sync extensions
    //
    private func handleCommandRequests() {
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
                            self.dialogOK(title: status.error.first ?? "git-annex: error", message: status.output.joined(separator: "\n"))
                        } else {
                            // success, update this file status right away
                            self.updateStatusNowAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    // Is this a Git Command?
                    if commandRequest.commandType.isGit {
                        let status = gitAnnexQueries.gitCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString)
                        if !status.success {
                            self.dialogOK(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                        } else {
                            // success, update this file status right away
                            self.updateStatusNowAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    break
                }
            }
        }
    }
    
    private func updateLatestCommitEntriesForWatchedFolders() {
        // Mark the current commit as handled
        //
        // NOTE: currently, this is true, as any folder requests that come in
        // will trigger a new git-annex request regardless of freshness
        // for performance we should probably store this latest commit hash
        // in the database, check on startup and re-scan any files in the database
        // that have changed since the latest commit, then update the latest
        // commit hash
        for watchedFolder in watchedFolders {
            // master branch (IE git files)
            // grab latest commit hash, if we don't already have one
            if !handledGitCommit.contains(for: watchedFolder) {
                if let gitGitCommitHash = gitAnnexQueries.latestGitCommitHashBlocking(in: watchedFolder) {
                    handledGitCommit.put(value: gitGitCommitHash, for: watchedFolder)
                } else {
                    NSLog("Error: could not find latest commit on master branch for watchedFolder: \(watchedFolder)")
                }
            }

            // git-annex branch (IE git-annex location tracking)
            // grab latest commit hash, if we don't already have one
            if !handledAnnexCommit.contains(for: watchedFolder) {
                if let gitAnnexCommitHash = gitAnnexQueries.latestGitAnnexCommitHashBlocking(in: watchedFolder) {
                    handledAnnexCommit.put(value: gitAnnexCommitHash, for: watchedFolder)
                } else {
                    NSLog("Error: could not find latest git-annex branch commit for watchedFolder: \(watchedFolder)")
                }
            }
        }
    }
    
    //
    // Badge Icon Requests
    //
    // handle requests for updated badge icons from our Finder Sync extension
    //
    private func handleBadgeRequests() {
        for watchedFolder in self.watchedFolders {
            for path in Queries(data: data).allPathRequestsV2Blocking(in: watchedFolder) {
                handleStatusRequests?.updateStatusFor(for: path, in: watchedFolder, secondsOld: 0, includeFiles: true, includeDirs: false, priority: .high)
            }
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        NSLog("quiting…")
        stopFinderSyncExtension()
    }
    
    //
    // Finder Sync Extension
    //
    // launch or re-launch our Finder Sync extension
    //
    func launchOrRelaunchFinderSyncExtension() {
        // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
        NSLog("re-launching Finder Sync extension")
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
        task.launch()
    }
    
    // Stop our Finder Sync extensions
    func stopFinderSyncExtension() {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pluginkit -e ignore -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
        task.launch()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return data.applicationShouldTerminate(sender)
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return data.windowWillReturnUndoManager(window: window)
    }
    
    @objc func showPreferencesWindow(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow()
            preferencesWindow?.center()
            preferencesWindow?.title = "git-annex-turtle Preferences"
            preferencesWindow?.isReleasedWhenClosed = false
            preferencesWindow?.contentViewController = preferencesViewController
            preferencesWindow?.styleMask.insert([.closable, .miniaturizable, .titled])
        }
        // show and bring to frong
        // see https://stackoverflow.com/questions/1740412/how-to-bring-nswindow-to-front-and-to-the-current-space
        preferencesWindow?.center()
        preferencesWindow?.orderedIndex = 0
        preferencesWindow?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func constructMenu(watchedFolders :Set<WatchedFolder>) {
        DispatchQueue.main.async {
            let menu = NSMenu()
            
            menu.addItem(NSMenuItem(title: "git-annex-turtle is observing:", action: nil, keyEquivalent: ""))
            if watchedFolders.count > 0 {
                for watching in watchedFolders {
                    var watchingStringTruncated = watching.pathString
                    if(watchingStringTruncated.count > 40){
                        watchingStringTruncated = "…" + watchingStringTruncated.suffix(40)
                    }
                    _ = menu.addItem(withTitle: watchingStringTruncated, action: nil, keyEquivalent: "")
//                    watching.image = self.gitAnnexLogoNoArrowsColor
                }
            } else {
                menu.addItem(NSMenuItem(title: "nothing", action: nil, keyEquivalent: ""))
            }
            
            menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(self.showPreferencesWindow(_:)), keyEquivalent: ""))
            
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
            
            self.statusItem.menu = menu
        }
    }
    
    @IBAction func nilAction(_ sender: AnyObject?) {}
    
    func dialogOK(title: String, message: String) {
        DispatchQueue.main.async {
            // https://stackoverflow.com/questions/29433487/create-an-nsalert-with-swift
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.icon = self.gitAnnexLogoSquareColor
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func watchedFolderFrom(uuid: String) -> WatchedFolder? {
        for watchedFolder in watchedFolders {
            if watchedFolder.uuid.uuidString == uuid {
                return watchedFolder
            }
        }
        return nil
    }
    
    //
    // Animate menubar-icon
    //
    //
    private func handleAnimateMenubarIcon() {
        if let handlingRequests = handleStatusRequests?.handlingRequests(), handlingRequests {
            startAnimatingMenubarIcon()
        } else {
            stopAnimatingMenubarIcon()
        }
    }
    
    private func animateMenubarIcon() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.3, qos: .background) {
            if let button = self.statusItem.button {
                DispatchQueue.main.async {
                    button.image = self.menubarIcons[self.menubarAnimationIndex]
                }
                
                // only stop animating after we have completed a full cycle
                if self.menubarAnimationIndex == 0 {
                    self.menubarIconAnimationLock.lock()
                    if self.menubarAnimating == false {
                        self.menubarIconAnimationLock.unlock()
                        return // we are done
                    }
                    self.menubarIconAnimationLock.unlock()
                }
                
                // increment menubar icon animation
                self.menubarAnimationIndex = (self.menubarAnimationIndex + 1) % (self.menubarIcons.count - 1)
                
                self.animateMenubarIcon() // continue animating
            }
        }
    }
    
    private func startAnimatingMenubarIcon() {
        menubarIconAnimationLock.lock()
        if menubarAnimating == false {
            menubarAnimating = true
            menubarIconAnimationLock.unlock()
            animateMenubarIcon()
        }
        menubarIconAnimationLock.unlock()
    }
    
    private func stopAnimatingMenubarIcon() {
        menubarIconAnimationLock.lock()
        menubarAnimating = false
        menubarIconAnimationLock.unlock()
    }
}

class WatchedFolderToCommitHash {
    // NSCache is thread-safe
    var map = NSCache<NSString, NSString>()
    
    func get(for key: WatchedFolder) -> String? {
        return map.object(forKey: key.uuid.uuidString as NSString) as String?
    }
    
    func put(value: String, for key: WatchedFolder) {
        map.setObject(value as NSString, forKey: key.uuid.uuidString as NSString)
    }
    
    func contains(for key: WatchedFolder) -> Bool {
        return map.object(forKey: key.uuid.uuidString as NSString) as String? != nil
    }
}
