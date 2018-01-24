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
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-menubar-default"))
    let data = DataEntrypoint()

    var watchedFolders = Set<WatchedFolder>()
    var menuBarButton :NSStatusBarButton?
    var preferencesViewController: ViewController? = nil
    var preferencesWindow: NSWindow? = nil
    var fileSystemMonitors: [WatchedFolderMonitor] = []
    var listenForWatchedFolderChanges: Witness? = nil
    var visibleFolders: VisibleFolders? = nil

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = gitAnnexTurtleLogo
            menuBarButton = button
        }
        constructMenu(watchedFolders: []) // generate an empty menu stub
        visibleFolders = VisibleFolders(data: data, app: self)

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
        listenForWatchedFolderChanges = Witness(paths: [Config().dataPath], flags: .FileEvents, latency: 0) { events in
            updateListOfWatchedFoldersDebounce()
        }
        
        //
        // Command Requests
        //
        // handle command requests "git annex get/add/drop/etc…" comming from our Finder Sync extensions
        //
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleCommandRequests()
                sleep(1)
            }
        }
        
        //
        // Badge Icon Requests
        //
        // handle requests for updated badge icons from our Finder Sync extension
        //
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleBadgeRequests()
                sleep(1)
            }
        }
        
        //
        // Visible Folder Updates
        //
        // update our list of visible folders
        //
        DispatchQueue.global(qos: .background).async {
            while true {
                self.visibleFolders?.updateListOfVisibleFolders()
                sleep(1)
            }
        }
        
        //
        // Git Annex Directory Scanning
        //
        // scan our visible directories for file that we should re-calculate git-annex status for
        // this will catch files if we miss File System API updates, since they are not guaranteed
        //
        DispatchQueue.global(qos: .background).async {
            while true {
                for watchedFolder in self.watchedFolders {
                    self.checkForGitAnnexUpdates(in: watchedFolder, secondsOld: 5)
                }
                sleep(5)
            }
        }
        
        //
        // Finder Sync Extension
        //
        // launch or re-launch our Finder Sync extension
        //
        DispatchQueue.global(qos: .background).async {
            // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
            NSLog("re-launching Finder Sync extension")
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
            task.launch()
        }
    }
    
    private func updateListOfWatchedFoldersAndSetupFileSystemWatches() {
        // Re-read config, it might have changed
        let config = Config()
        
        // For all watched folders, if it has a valid git-annex UUID then
        // assume it is a valid git-annex folder and start watching it
        var newWatchedFolders = Set<WatchedFolder>()
        for watchedFolder in config.listWatchedRepos() {
            if let uuid = GitAnnexQueries.gitGitAnnexUUID(in: watchedFolder) {
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
    
    func checkForGitAnnexUpdates(in watchedFolder: WatchedFolder, secondsOld: Double) {
//        NSLog("Checking for updates on disk, git-annex \(watchedFolder.pathString)")
        let queries = Queries(data: self.data)
        let paths = queries.allPathsOlderThanBlocking(in: watchedFolder, secondsOld: secondsOld)
        
        // see https://blog.vishalvshekkar.com/swift-dispatchgroup-an-effortless-way-to-handle-unrelated-asynchronous-operations-together-5d4d50b570c6
        let updateStatusCompletionBarrier = DispatchGroup()
        for path in paths {
            // ignore non-visible paths
            if let visible = visibleFolders?.isVisible(path: path), visible {
//                NSLog("Checking for updates on \(path)")
                
                // handle multiple git-annex queries concurrently
                let url = PathUtils.url(for: path)
                updateStatusCompletionBarrier.enter()
                // TODO limit simultaneous git-annex requests?
                DispatchQueue.global(qos: .userInitiated).async {
                    if let status = GitAnnexQueries.gitAnnexPathInfo(for: url, in: watchedFolder.pathString, calculateLackingCopiesForDirs: false, in: watchedFolder) {
                        // did the status change?
                        let oldStatus = queries.statusForPathV2Blocking(path: path)
                        if oldStatus == nil || oldStatus! != status {
                            NSLog("updating in Db old status='\(oldStatus)' != newStatus='\(status)' for \(path)")
                            queries.updateStatusForPathV2Blocking(to: Status.unknown /* DEPRECATED */, presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: path, in: watchedFolder)
                        }
                    } else {
                        NSLog("unable to get status for \(path)")
                    }
                    
                    updateStatusCompletionBarrier.leave()
                }
            }
        }
        
        // wait for all asynchronous status updates to complete
        updateStatusCompletionBarrier.wait()
    }

    private func updateStatusAsync(for path: String, in watchedFolder: WatchedFolder) {
        // TODO
        // add this back in later, when we have a better handle on the timing of all events
        
//        DispatchQueue.global(qos: .background).async {
//            let url = PathUtils.url(for: path)
//            let status = GitAnnexQueries.gitAnnexPathInfo(for: url, in: watchedFolder.pathString, calculateLackingCopiesForDirs: false)
//
//            // did the status change?
//            let queries = Queries(data: self.data)
//            let oldStatus = queries.statusForPathBlocking(path: path)
//            if oldStatus == nil || oldStatus! != status {
//                NSLog("updating in Db old status='\(oldStatus!.rawValue)' != newStatus='\(status.rawValue)' for \(path)")
//                queries.updateStatusForPathBlocking(to: status, for: path, in: watchedFolder)
//            }
//        }
    }
    
    private func handleCommandRequests() {
        let queries = Queries(data: self.data)
        let commandRequests = queries.fetchAndDeleteCommandRequestsBlocking()
        
        for commandRequest in commandRequests {
            for watchedFolder in self.watchedFolders {
                if watchedFolder.uuid.uuidString == commandRequest.watchedFolderUUIDString {
                    let url = PathUtils.url(for: commandRequest.pathString)
                    
                    // Is this a Git Annex Command?
                    if commandRequest.commandType.isGitAnnex {
                        let status = GitAnnexQueries.gitAnnexCommand(for: url, in: watchedFolder.pathString, cmd: commandRequest.commandString)
                        if !status.success {
                            // git-annex has very nice error message, use them as-is
                            self.dialogOK(title: status.error.first ?? "git-annex: error", message: status.output.joined(separator: "\n"))
                        } else {
                            self.updateStatusAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    // Is this a Git Command?
                    if commandRequest.commandType.isGit {
                        let status = GitAnnexQueries.gitCommand(for: url, in: watchedFolder.pathString, cmd: commandRequest.commandString)
                        if !status.success {
                            self.dialogOK(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                        } else {
                            self.updateStatusAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    break
                }
            }
        }
    }
    
    private func handleBadgeRequests() {
        // TODO handle watchedFolders in separate threads for performance
        for watchedFolder in self.watchedFolders {
            let queries = Queries(data: self.data)
            let paths = queries.allPathsNotHandledV2Blocking(in: watchedFolder)
            
            // see https://blog.vishalvshekkar.com/swift-dispatchgroup-an-effortless-way-to-handle-unrelated-asynchronous-operations-together-5d4d50b570c6
            let updateStatusCompletionBarrier = DispatchGroup()
            for path in paths {
                // handle multiple git-annex queries concurrently
                let url = PathUtils.url(for: path)
                updateStatusCompletionBarrier.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    if let status = GitAnnexQueries.gitAnnexPathInfo(for: url, in: watchedFolder.pathString, calculateLackingCopiesForDirs: false, in: watchedFolder) {
                        // did the status change?
                        let oldStatus = queries.statusForPathV2Blocking(path: path)
                        if oldStatus == nil || oldStatus! != status {
                            NSLog("updating in Db old status='\(oldStatus)' != newStatus='\(status)' for \(path)")
                            queries.updateStatusForPathV2Blocking(to: Status.unknown /* DEPRECATED */, presentStatus: status.presentStatus, enoughCopies: status.enoughCopies, numberOfCopies: status.numberOfCopies, isGitAnnexTracked: status.isGitAnnexTracked, for: path, in: watchedFolder)
                        }
                    } else {
                        NSLog("unable to get status for \(path)")
                    }                    
                    
                    updateStatusCompletionBarrier.leave()
                }
            }
            
            updateStatusCompletionBarrier.wait() // wait for all queries to complete
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        NSLog("quiting…")
        
        // Stop our Finder Sync extensions
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
}

