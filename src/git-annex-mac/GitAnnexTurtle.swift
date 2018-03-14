//
//  GitAnnexTurtle.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 3/13/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

protocol GitAnnexTurtle {
    func updateMenubarData(with watchedFolders: Set<WatchedFolder>)

    func applicationDidFinishLaunching(_ aNotification: Notification)
    func applicationWillTerminate(_ aNotification: Notification)
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager?
}

class GitAnnexTurtleProduction: GitAnnexTurtle {
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
    
    let data: DataEntrypoint
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let fullScan: FullScan
    let handleStatusRequests: HandleStatusRequests
    
    var menuBarButton :NSStatusBarButton?
    var preferencesViewController: ViewController? = nil
    var preferencesWindow: NSWindow? = nil
    
    var watchGitAndFinderForUpdates: WatchGitAndFinderForUpdates?
    
    init() {
        for i in 0...16 {
            menubarIcons.append(NSImage(named:NSImage.Name(rawValue: "menubaricon-\(String(i))"))!)
        }
        let config = Config()
        if let gitAnnexBin = config.gitAnnexBin(), let gitBin = config.gitBin() {
            gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: gitAnnexBin, gitCmd: gitBin)
        } else {
            // TODO put notice in menubar icon
            // allow user to set paths or install
            TurtleLog.error("Could not find binary paths for git and git-annex, quitting")
            exit(-1)
        }
        
        data = DataEntrypoint()
        queries = Queries(data: data)
        fullScan = FullScan(gitAnnexQueries: gitAnnexQueries, queries: queries)
        handleStatusRequests = HandleStatusRequests(queries: queries, gitAnnexQueries: gitAnnexQueries)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = gitAnnexTurtleLogo
            menuBarButton = button
        }
        
        constructMenu(watchedFolders: []) // generate an empty menu stub
        
        // Start the main database and git-annex loop
        watchGitAndFinderForUpdates = WatchGitAndFinderForUpdates(gitAnnexTurtle: self, data: data, fullScan: fullScan, handleStatusRequests: handleStatusRequests, gitAnnexQueries: gitAnnexQueries)
        
        // Menubar Icon > Preferences menu
        preferencesViewController = ViewController.freshController(appDelegate: watchGitAndFinderForUpdates!)

        // Animated icon
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleAnimateMenubarIcon()
                usleep(100000)
            }
        }
        
        // Launch/re-launch our Finder Sync Extension
        DispatchQueue.global(qos: .background).async {
            self.launchOrRelaunchFinderSyncExtension()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        TurtleLog.info("quiting…")
        stopFinderSyncExtension()
    }
    
    //
    // Finder Sync Extension
    //
    // launch or re-launch our Finder Sync extension
    //
    private func launchOrRelaunchFinderSyncExtension() {
        // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
        TurtleLog.info("re-launching Finder Sync extension")
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
        task.launch()
    }
    
    // Stop our Finder Sync extensions
    private func stopFinderSyncExtension() {
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
    
    public func updateMenubarData(with watchedFolders: Set<WatchedFolder>) {
        constructMenu(watchedFolders: watchedFolders) // update our menubar icon menu
        updatePreferencesMenu()
    }
    
    private func updatePreferencesMenu() {
        preferencesViewController?.reloadFileList()
    }
    
    private func constructMenu(watchedFolders :Set<WatchedFolder>) {
        DispatchQueue.main.async {
            let menu = NSMenu()
            
            menu.addItem(NSMenuItem(title: "git-annex-turtle is monitoring:", action: nil, keyEquivalent: ""))
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
    
    //
    // Animate menubar-icon
    //
    //
    private func handleAnimateMenubarIcon() {
        let handlingRequests = handleStatusRequests.handlingRequests()
        if handlingRequests || fullScan.isScanning() {
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
            return
        }
        menubarIconAnimationLock.unlock()
    }
    
    private func stopAnimatingMenubarIcon() {
        menubarIconAnimationLock.lock()
        menubarAnimating = false
        menubarIconAnimationLock.unlock()
    }
}

class GitAnnexTurtleStub: GitAnnexTurtle {
    func applicationDidFinishLaunching(_ aNotification: Notification) {}
    func applicationWillTerminate(_ aNotification: Notification) {}
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return nil
    }
    
    func updateMenubarData(with watchedFolders: Set<WatchedFolder>) {}
}
