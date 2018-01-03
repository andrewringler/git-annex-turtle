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
    let defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
    
    // hard-coded folder for now
    let myFolderURL: URL = URL(fileURLWithPath: "/Users/Shared/MySyncExtension Documents")
    
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        // just set a single folder to watch, FinderSync will read this
        // hard-coded single folder for now
        defaults.synchronize()
        defaults.set("/Users/Shared/MySyncExtension Documents", forKey: "myFolderURL")
        defaults.synchronize()

        // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
        task.launch()
        
        while true {
            let allKeys = defaults.dictionaryRepresentation().keys
            for key in allKeys {
                if key.starts(with: "gitannex.") {
                    if(defaults.string(forKey: key)! == "request"){
                        var url :String = key
                        url.removeFirst("gitannex.".count)
                        let status = GitAnnexQueries.gitAnnexPathInfo(for: URL(fileURLWithPath: url), in: (myFolderURL as NSURL).path!)
                        
                        if status == "present" {
                            defaults.set("present", forKey: key)
                        } else if status == "absent" {
                            defaults.set("absent", forKey: key)
                        } else {
                            defaults.set("unknown", forKey: key)
                        }
                    }
                }
            }

            sleep(1)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

