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
//    let popover = NSPopover()
    
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    let gitAnnexLogoSquareColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-color"))
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-menubar-default"))
    let defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
    
    var watchedFolders = Set<WatchedFolder>()
    var menuBarButton :NSStatusBarButton?
    var preferencesViewController: ViewController? = nil
    var preferencesWindow: NSWindow? = nil
    
    private func updateListOfWatchedFolders() {
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

            for watchedFolder in watchedFolders {
                NSLog("Watching: %@ %@", watchedFolder.uuid.uuidString, watchedFolder.pathString)
            }
            
            // notify our Finder Sync extension of the change
            if let encodedData :Data = try? JSONEncoder().encode(watchedFolders) {
                defaults.set(encodedData, forKey: GitAnnexTurtleWatchedFoldersDbPrefix)
            } else {
                NSLog("unable to encode watched folders")
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = gitAnnexTurtleLogo
            button.action = #selector(printQuote(_:))
            menuBarButton = button
        }
        
        // Setup preferences view controller
        preferencesViewController = ViewController.freshController(appDelegate: self)
//        preferencesViewController?.appDelegate = self
//        preferencesViewController?.reloadFileList()

        // THIS IS USEFUL FOR TESTING
        // delete all of our keys
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.starts(with: GitAnnexTurtleDbPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        
        // Periodically check if watched folder list has changed, update menu and notify Finder Sync extension
        DispatchQueue.global(qos: .background).async {
            while true {
                // TODO: use an OS filesystem monitor on ~/.config/git-annex/turtle-watch
                self.updateListOfWatchedFolders()
                sleep(2)
            }
        }
        
        // Handle command requests coming from the (potentially multiple instances) of our Finder Sync extension
        DispatchQueue.global(qos: .background).async {
            while true {
                for watchedFolder in self.watchedFolders {
                    let allKeys = self.defaults.dictionaryRepresentation().keys
                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleDbPrefix) }) {
                        // Is this a Git Annex Command?
                        for command in GitAnnexCommands.all {
                            if key.starts(with: command.dbPrefixWithUUID(in: watchedFolder)) {
                                if let url = self.defaults.url(forKey: key) {
                                    let status = GitAnnexQueries.gitAnnexCommand(for: url, in: watchedFolder.pathString, cmd: command)
                                    if !status.success {
                                        // git-annex has very nice error message, use them as-is
                                        self.dialogOK(title: status.error.first ?? "git-annex: error", message: status.output.joined(separator: "\n"))
                                    }
                                    
                                    // handled, delete the request
                                    self.defaults.removeObject(forKey: key)
                                } else {
                                    NSLog("unable to retrieve url for key %@", key)
                                }
                            }
                        }
                        
                        // Is this a Git Command?
                        for command in GitCommands.all {
                            if key.starts(with: command.dbPrefixWithUUID(in: watchedFolder)) {
                                if let url = self.defaults.url(forKey: key) {
                                    let status = GitAnnexQueries.gitCommand(for: url, in: watchedFolder.pathString, cmd: command)
                                    if !status.success {
                                        self.dialogOK(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                                    }
                                   
                                    // handled, delete the request
                                    self.defaults.removeObject(forKey: key)
                                } else {
                                    NSLog("unable to retrieve url for key %@", key)
                                }
                            }
                        }
                    }
                }
                sleep(1)
            }
        }
        
        // Periodically check for badge requests from our Finder Sync extension
        DispatchQueue.global(qos: .background).async {
            while true {
                let defaultsDict = self.defaults.dictionaryRepresentation()
                let allKeys = defaultsDict.keys
                
                /* Handle all badge requests, these are the highest priority for a nice user experience
                 * since there are the whole point of this app
                 */
                for watchedFolder in self.watchedFolders {
                    // find all request keys for this watched folder
                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleRequestBadgeDbPrefixNoPath(in: watchedFolder)) }) {
                        if let url = self.defaults.url(forKey: key) {
                            if let path = PathUtils.path(for: url) {
                                // handle multiple git-annex queries concurrently
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let status = GitAnnexQueries.gitAnnexPathInfo(for: url, in: watchedFolder.pathString)
                                    self.defaults.set(status.rawValue, forKey: GitAnnexTurtleStatusUpdatedDbPrefix(for: path, in: watchedFolder))
                                }
                            } else {
                                NSLog("unable to get path for URL in key %@", key)
                            }
                        } else {
                            NSLog("unable to get URL for key %@", key)
                        }
                        

                        /* OK, either we handled it, we are handling it, or there was some error
                         * we couldn't handle. Either way, remove it from UserDefaults so we don't
                         * try to deal with it again
                         */
                        self.defaults.removeObject(forKey: key)
                    }
                }
                sleep(1)
            }
        }
        
        // Launch/re-launch Finder Sync extension
        DispatchQueue.global(qos: .background).async {
            // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
            task.launch()
        }

        // Periodically check if the state of a file/directory has changed since we last checked
        DispatchQueue.global(qos: .background).async {
            while true {
                let defaultsDict = self.defaults.dictionaryRepresentation()
                let allKeys = defaultsDict.keys

                // We only want to re-check files that are still in watched folders
                for watchedFolder in self.watchedFolders {
                    // find all existing keys for this watched folder
                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleStatusDbPrefixNoPath(in: watchedFolder)) }) {
                        var path = key
                        path.removeFirst(GitAnnexTurtleStatusDbPrefixNoPath(in: watchedFolder).count)
                        if let oldStatus = Status.status(fromOptional: self.defaults.string(forKey: key)) {
                            let url = PathUtils.url(for: path)
                            // TODO handle multiple git-annex queries concurrently
                            // NOTE if we do DispatchQueue async, we need to ensure
                            // below that our sleep, sleeps long enough for all threads to complete!
                            let newStatus = GitAnnexQueries.gitAnnexPathInfo(for: url, in: watchedFolder.pathString)
                            if oldStatus != newStatus {
                                NSLog("status for '%@' updated from '%@' to '%@', notifying Finder Sync", path, oldStatus.rawValue, newStatus.rawValue)
                                self.defaults.set(newStatus.rawValue, forKey: GitAnnexTurtleStatusUpdatedDbPrefix(for: path, in: watchedFolder))
                            }
                        } else {
                            NSLog("unable to get status for key '%@'", key)
                        }
                    }
                }
                sleep(2)
            }
        }
        
//        DispatchQueue.global(qos: .background).async {
//            while true {
//                // handle all direct requests first
//                var numberOfDirectRequest :Int = 0
//                repeat {
//                    let allKeys = self.defaults.dictionaryRepresentation().keys
//                    numberOfDirectRequest = 0
//                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleDbPrefix) }) {
//                        if key.starts(with: GitAnnexTurtleRequestBadgeDbPrefix) {
//                            // OK Finder Sync requested this URL, is it still in view?
//                            var path = key
//                            path.removeFirst("gitannex.requestbadge.".count)
//                            let url = URL(fileURLWithPath: path)
//                            var parentURL = url
//                            parentURL.deleteLastPathComponent() // containing folder
//                            if let parentPath = (parentURL as NSURL).path {
//                                let observingKey = "gitannex.observing." + parentPath
//                                if defaults.string(forKey: observingKey) != nil {
//                                    // OK we are still observing this directory
//                                    let status = GitAnnexQueries.gitAnnexPathInfo(for: url, in: (myFolderURL as NSURL).path!)
//                                    // Add updated status
//                                    defaults.set(status, forKey: "gitannex.status.updated." + path)
//
//                                    // Remove the request we have handled it
//                                    defaults.removeObject(forKey: key)
//                                    numberOfDirectRequest += 1
//                                }
//                            }
//                        }
//                    }
//                } while numberOfDirectRequest > 0
//                // keep looking for direct requests until we haven't found any new ones
//
//                // OK there are no new direct requests for badges
//                // lets give our CPU a break
//                sleep(1)
//
//                // OK maybe file state has changed via OS commands
//                // git or git annex commands since we last checked
//                // lets periodically poll all files in observed folders
//                // IE all files that are in Finder windows that are visible to a user
//                let allKeys = defaults.dictionaryRepresentation().keys
//                for key in allKeys {
//                    if key.starts(with: "gitannex.observing.") {
//                        if let observingURL :URL = defaults.url(forKey: key) {
//                            if let filesToCheck: [String] = try? FileManager.default.contentsOfDirectory(atPath: (observingURL as NSURL).path!) {
//                                // TODO PERFORMANCE
//                                // we can actually pass git-annex a whole list of files
//                                // which would probably be quicker than launching
//                                // separate processes to run the bash commands in
//                                for file in filesToCheck {
//                                    let fullPath = observingURL.appendingPathComponent(file)
//                                    let status = GitAnnexQueries.gitAnnexPathInfo(for: fullPath, in: (myFolderURL as NSURL).path!)
//
//                                    //is there already an old status for this
//                                    //that is equivalent?
//                                    if let oldStatus = defaults.string(forKey: "gitannex.status." + (fullPath as NSURL).path!) {
//                                        if oldStatus != status {
//                                            // OK, we have a new status, lets
//                                            // let Finder Sync extension know
//                                            defaults.set(status, forKey: "gitannex.status.updated." + (fullPath as NSURL).path!)
//                                        }
//                                    } else {
//                                        defaults.set(status, forKey: "gitannex.status.updated." + (fullPath as NSURL).path!)
//                                    }
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        NSLog("quiting")
        
        // stop Finder Sync extension
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pluginkit -e ignore -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
        task.launch()
    }
    
    @objc func printQuote(_ sender: Any?) {
        let quoteText = "Never put off until tomorrow what you can do the day after tomorrow."
        let quoteAuthor = "Mark Twain"
        
        print("\(quoteText) — \(quoteAuthor)")
    }
    
    @objc func showPreferencesWindow(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow()
            preferencesWindow?.title = "git-annex-turtle Preferences"
            preferencesWindow?.isReleasedWhenClosed = false
            preferencesWindow?.contentViewController = preferencesViewController
            preferencesWindow?.styleMask.insert([.closable, .miniaturizable, .titled])
        }
        preferencesWindow?.makeKeyAndOrderFront(self)
    }
    
    func constructMenu(watchedFolders :Set<WatchedFolder>) {
        DispatchQueue.main.async {
            let menu = NSMenu()
            
            menu.addItem(NSMenuItem(title: "git-annex-turtle is watching:", action: nil, keyEquivalent: ""))
            if watchedFolders.count > 0 {
                for watching in watchedFolders {
                    var watchingStringTruncated = watching.pathString
                    if(watchingStringTruncated.count > 40){
                        watchingStringTruncated = "…" + watchingStringTruncated.suffix(40)
                    }
                    let watching = menu.addItem(withTitle: watchingStringTruncated, action: nil, keyEquivalent: "")
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
}

