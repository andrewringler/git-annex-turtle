//
//  AppDelegate.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//
import Cocoa
//import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let maybeDefaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")
        let config = Config()
        
        // just grab the first repo to watch, for now
        let repo :String? = config.listWatchedRepos().first

        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name(rawValue: "git-annex-menubar-default2"))
            button.action = #selector(printQuote(_:))
        }
        constructMenu(watching: repo)

        DispatchQueue.global(qos: .background).async {
            
            if let defaults = maybeDefaults, repo != nil {
                let myFolderURL = URL(fileURLWithPath: repo!)
                
                // FinderSync will read this
                defaults.synchronize()
                
                // delete all of our keys
                // THIS IS USEFUL FOR TESTING
                let allKeys = defaults.dictionaryRepresentation().keys
                for key in allKeys {
                    if key.starts(with: "gitannex.") {
                        defaults.removeObject(forKey: key)
                    }
                }
                
                defaults.set(repo, forKey: "myFolderURL")
                defaults.synchronize()
                
                // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
                let task = Process()
                task.launchPath = "/bin/bash"
                task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
                task.launch()
                
                while true {
                    defaults.synchronize()
                    let allKeys = defaults.dictionaryRepresentation().keys
                    for key in allKeys {
                        if key.starts(with: "gitannex.") {
                            if let v = defaults.string(forKey: key), v == "request" {
                                var url :String = key
                                url.removeFirst("gitannex.".count)
                                let status = GitAnnexQueries.gitAnnexPathInfo(for: URL(fileURLWithPath: url), in: (myFolderURL as NSURL).path!)
                                
                                if status == "present" {
                                    defaults.set("present", forKey: key)
                                } else if status == "absent" {
                                    defaults.set("absent", forKey: key)
                                } else if status == "fully-present-directory" {
                                    defaults.set("fully-present-directory", forKey: key)
                                } else if status == "partially-present-directory" {
                                    defaults.set("partially-present-directory", forKey: key)
                                } else {
                                    defaults.set("unknown", forKey: key)
                                }
                            }
                        }
                    }
                    sleep(1)
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
        
//        menu.addItem(NSMenuItem(title: "Print Quote", action: #selector(AppDelegate.printQuote(_:)), keyEquivalent: "P"))
//        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "git-annex-turtle", action: nil, keyEquivalent: ""))
        if let watchString = watching {
            var watchingStringTruncated = watchString
            if(watchingStringTruncated.count > 40){
                watchingStringTruncated = "…" + watchingStringTruncated.suffix(40)
            }
            menu.addItem(NSMenuItem(title: "Watching “" + watchingStringTruncated + "”", action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Not watching any repos", action: nil, keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        statusItem.menu = menu
    }
    
    @IBAction func nilAction(_ sender: AnyObject?) {}
}

