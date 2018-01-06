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
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    
    var watchedFolders :[(UUID, String)] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup") {
            let config = Config()

            // For all watched folders, if it has a valid git-annex UUID then
            // assume it is a valid git-annex folder and start watching it
            for watchedFolder in config.listWatchedRepos() {
                NSLog("About to try to watch '%@'", watchedFolder)
                if let uuid = GitAnnexQueries.gitGitAnnexUUID(in: watchedFolder) {
                    watchedFolders.append((uuid, watchedFolder))
                    NSLog("Watching: %@ %@", uuid.uuidString, watchedFolder)
                } else {
                    // TODO let the user know this?
                    NSLog("Could not find valid git-annex UUID for '%@', not watching", watchedFolder)
                }
            }
            
            // just grab the first repo to watch, for now
            let repo :String? = config.listWatchedRepos().first
            
            if let button = statusItem.button {
                button.image = NSImage(named:NSImage.Name(rawValue: "git-annex-menubar-default"))
                button.action = #selector(printQuote(_:))
            }
            constructMenu(watching: repo)
            
            // delete all of our keys
            // THIS IS USEFUL FOR TESTING
            let allKeys = defaults.dictionaryRepresentation().keys
            for key in allKeys {
                if key.starts(with: "gitannex.") {
                    defaults.removeObject(forKey: key)
                }
            }
            
            // Handle command requests
            if repo != nil {
                let myFolderURL = URL(fileURLWithPath: repo!)
                DispatchQueue.global(qos: .background).async {
                    while true {
                        let allKeys = defaults.dictionaryRepresentation().keys
                        for key in allKeys {
                            // Is this a Git Annex Command?
                            for command in GitAnnexCommands.all {
                                if key.starts(with: command.dbPrefix) {
                                    if let url = defaults.url(forKey: key) {
                                        let status = GitAnnexQueries.gitAnnexCommand(for: url, in: (myFolderURL as NSURL).path!, cmd: command)
                                        // TODO, what to do with status?
                                        
                                        // handled, delete the request
                                        defaults.removeObject(forKey: key)
                                    }
                                }
                            }
                            
                            // Is this a Git Command?
                            for command in GitCommands.all {
                                if key.starts(with: command.dbPrefix) {
                                    if let url = defaults.url(forKey: key) {
                                        let status = GitAnnexQueries.gitCommand(for: url, in: (myFolderURL as NSURL).path!, cmd: command)
                                        // TODO, what to do with status?
                                        
                                        // handled, delete the request
                                        defaults.removeObject(forKey: key)
                                    }
                                }
                            }
                            

                        }
                        
                        sleep(1)
                    }
                }
            }
            
            DispatchQueue.global(qos: .background).async {
                if repo != nil {
                    let myFolderURL = URL(fileURLWithPath: repo!)
                    
                    defaults.set(repo, forKey: "myFolderURL")
                    // defaults.synchronize() will ensure we dont relaunch
                    // our Finder extension until we have set the folders
                    // it should listen on
                    // TODO it should constantly be checking if this has changed
                    // once we are doing that, we can get rid of this
                    // synchronize call
                    defaults.synchronize()
                    
                    // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
                    let task = Process()
                    task.launchPath = "/bin/bash"
                    task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
                    task.launch()
                    
                    while true {
                        // handle all direct requests first
                        var numberOfDirectRequest :Int = 0
                        repeat {
                            let allKeys = defaults.dictionaryRepresentation().keys
                            numberOfDirectRequest = 0
                            for key in allKeys {
                                if key.starts(with: "gitannex.requestbadge.") {
                                    // OK Finder Sync requested this URL, is it still in view?
                                    var path = key
                                    path.removeFirst("gitannex.requestbadge.".count)
                                    let url = URL(fileURLWithPath: path)
                                    var parentURL = url
                                    parentURL.deleteLastPathComponent() // containing folder
                                    if let parentPath = (parentURL as NSURL).path {
                                        let observingKey = "gitannex.observing." + parentPath
                                        if defaults.string(forKey: observingKey) != nil {
                                            // OK we are still observing this directory
                                            let status = GitAnnexQueries.gitAnnexPathInfo(for: url, in: (myFolderURL as NSURL).path!)
                                            // Add updated status
                                            defaults.set(status, forKey: "gitannex.status.updated." + path)
                                            
                                            // Remove the request we have handled it
                                            defaults.removeObject(forKey: key)
                                            numberOfDirectRequest += 1
                                        }
                                    }
                                }
                            }
                        } while numberOfDirectRequest > 0
                        // keep looking for direct requests until we haven't found any new ones
                        
                        // OK there are no new direct requests for badges
                        // lets give our CPU a break
                        sleep(1)
                        
                        // OK maybe file state has changed via OS commands
                        // git or git annex commands since we last checked
                        // lets periodically poll all files in observed folders
                        // IE all files that are in Finder windows that are visible to a user
                        let allKeys = defaults.dictionaryRepresentation().keys
                        for key in allKeys {
                            if key.starts(with: "gitannex.observing.") {
                                if let observingURL :URL = defaults.url(forKey: key) {
                                    if let filesToCheck: [String] = try? FileManager.default.contentsOfDirectory(atPath: (observingURL as NSURL).path!) {
                                        // TODO PERFORMANCE
                                        // we can actually pass git-annex a whole list of files
                                        // which would probably be quicker than launching
                                        // separate processes to run the bash commands in
                                        for file in filesToCheck {
                                            let fullPath = observingURL.appendingPathComponent(file)
                                            let status = GitAnnexQueries.gitAnnexPathInfo(for: fullPath, in: (myFolderURL as NSURL).path!)
                                            
                                            //is there already an old status for this
                                            //that is equivalent?
                                            if let oldStatus = defaults.string(forKey: "gitannex.status." + (fullPath as NSURL).path!) {
                                                if oldStatus != status {
                                                    // OK, we have a new status, lets
                                                    // let Finder Sync extension know
                                                    defaults.set(status, forKey: "gitannex.status.updated." + (fullPath as NSURL).path!)
                                                }
                                            } else {
                                                defaults.set(status, forKey: "gitannex.status.updated." + (fullPath as NSURL).path!)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    NSLog("did not find any folders to watch, quiting")
                    // stop Finder Sync extension
                    let task = Process()
                    task.launchPath = "/bin/bash"
                    task.arguments = ["-c", "pluginkit -e ignore -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
                    task.launch()
                    
                    exit(0)
                }
            }
        }
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
    
    func constructMenu(watching :String?) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "git-annex-turtle is watching:", action: nil, keyEquivalent: ""))
        if let watchString = watching {
            var watchingStringTruncated = watchString
            if(watchingStringTruncated.count > 40){
                watchingStringTruncated = "…" + watchingStringTruncated.suffix(40)
            }
            let watching = menu.addItem(withTitle: watchingStringTruncated, action: nil, keyEquivalent: "")
            watching.image = gitAnnexLogoNoArrowsColor
        } else {
            menu.addItem(NSMenuItem(title: "Not watching any repos", action: nil, keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        statusItem.menu = menu
    }
    
    @IBAction func nilAction(_ sender: AnyObject?) {}
}

