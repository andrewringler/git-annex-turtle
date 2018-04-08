//
//  GitAnnexTurtleProduction.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/14/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

class GitAnnexTurtleProduction: GitAnnexTurtle {
    // https://developer.apple.com/macos/human-interface-guidelines/icons-and-images/system-icons/
    let actionIcon = NSImage(named:NSImage.Name.actionTemplate)
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    let gitAnnexLogoSquareColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-color"))
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "menubaricon-0"))
    let serviceThread: DispatchQueue
    
    var menubarIcons: [NSImage] = []
    var menubarAnimationIndex: Int = 0
    let menubarIconAnimationLock = NSLock()
    var menubarAnimating: Bool = false
    
    let config = Config(dataPath: Config.DEFAULT_DATA_PATH)
    let data: DataEntrypoint
    let queries: Queries
    let gitAnnexQueries: GitAnnexQueries
    let fullScan: FullScan
    let dialogs = TurtleDialogs()
    
    var menuBarButton :NSStatusBarButton?
    var preferencesViewController: ViewController? = nil
    var preferencesWindow: NSWindow? = nil
    
    var watchGitAndFinderForUpdates: WatchGitAndFinderForUpdates?
    
    init() {
        for i in 0...16 {
            menubarIcons.append(NSImage(named:NSImage.Name(rawValue: "menubaricon-\(String(i))"))!)
        }
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
        serviceThread = DispatchQueue(label: "com.andrewringler.git-annex-mac.ServiceThread")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = gitAnnexTurtleLogo
            menuBarButton = button
        }
        
        constructMenu(watchedFolders: []) // generate an empty menu stub
        
        // Start the main database and git-annex loop
        watchGitAndFinderForUpdates = WatchGitAndFinderForUpdates(gitAnnexTurtle: self, config: config, data: data, fullScan: fullScan, gitAnnexQueries: gitAnnexQueries, dialogs: dialogs)
        
        // Menubar Icon > Preferences menu
        preferencesViewController = ViewController.freshController(appDelegate: watchGitAndFinderForUpdates!)
        
        // Start Service to communicate with Finder Sync extension instances
        serviceThread.async {
            // CFMessagePort expects a runloop, so give it one inside a custom GCD thread
            // this seems like a reasonable way to interop with these Object-C libraries from Swift
            // see https://stackoverflow.com/a/38001438/8671834 for more discussions
            let server = TurtleServer(name: messagePortName, toRunLoop: CFRunLoopGetCurrent())
//            server.addSourceForNewLocalMessagePort()
            CFRunLoopRun()
        }

        // Animated icon
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleAnimateMenubarIcon()
                // PERFORMANCE, this is spiking the CPU
                usleep(150000)
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
    
    @objc func showAboutWindow(_ sender: Any?) {
        dialogs.about()
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
        // show and bring to front
        // see https://stackoverflow.com/questions/1740412/how-to-bring-nswindow-to-front-and-to-the-current-space
        preferencesWindow?.center()
        preferencesWindow?.orderedIndex = 0
        preferencesWindow?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showInFinder(_ sender: NSMenuItem) {
        if let watchedFolder = sender.representedObject as? WatchedFolder {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: watchedFolder.pathString)
        }
    }
        
    public func updateMenubarData(with watchedFolders: Set<WatchedFolder>) {
        constructMenu(watchedFolders: watchedFolders) // update our menubar icon menu
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
                    var newMenuItem = menu.addItem(withTitle: watchingStringTruncated, action: #selector(self.showInFinder(_:)), keyEquivalent: "")
                    newMenuItem.target = self
                    newMenuItem.representedObject = watching
                    //                    watching.image = self.gitAnnexLogoNoArrowsColor
                }
            } else {
                menu.addItem(NSMenuItem(title: "nothing", action: nil, keyEquivalent: ""))
            }
            
            menu.addItem(NSMenuItem.separator())

            let preferencesMenuItem = NSMenuItem(title: "Preferences…", action: #selector(self.showPreferencesWindow(_:)), keyEquivalent: "")
            preferencesMenuItem.target = self
            preferencesMenuItem.image = self.actionIcon
            menu.addItem(preferencesMenuItem)
            
            let aboutMenuItem = NSMenuItem(title: "About git-annex-turtle", action: #selector(self.showAboutWindow(_:)), keyEquivalent: "")
            aboutMenuItem.target = self
            menu.addItem(aboutMenuItem)
            
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
            
            self.statusItem.menu = menu
            
            self.preferencesViewController?.reloadFileList()
        }
    }
    
    @IBAction func nilAction(_ sender: AnyObject?) {}
    
    //
    // Animate menubar-icon
    //
    //
    private func handleAnimateMenubarIcon() {
        let handlingRequests = watchGitAndFinderForUpdates?.handlingStatusRequests() ?? false
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
