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
    let defaults = UserDefaults(suiteName: "com.andrewringler.git-annex-mac.sharedgroup")
    // hard-coded folder for now
    let myFolderURL: URL = URL(fileURLWithPath: "/Users/Shared/MySyncExtension Documents")
    
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        // just set a single folder to watch, FinderSync will read this
        // hard-coded single folder for now
        defaults!.set("/Users/Shared/MySyncExtension Documents", forKey: "myFolderURL")
        defaults!.synchronize()
        
        // see https://github.com/kpmoran/OpenTerm/commit/022dcfaf425645f63d4721b1353c31614943bc32
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "pluginkit -e use -i com.andrewringler.git-annex-mac.git-annex-finder ; killall Finder"]
        task.launch()
        
        // TODO in DispatchQueue?
//        DispatchQueue.main.async(execute: {
//            debugPrint("dispatch")
//        })
        
        while true {
//            debugPrint(".")
            let allKeys = defaults?.dictionaryRepresentation().keys
            var updatesAvailable :Bool = false
            for key in allKeys! {
                if key.starts(with: "gitannex.") {
                    //NSLog("main app found request " + key)
//                    let url = URL(fileURLWithPath: key.
                    var url :String = key
                    url.removeFirst("gitannex.".count)
                    let present = GitAnnexQueries.gitAnnexPathIsPresent(for: URL(fileURLWithPath: url), in: (myFolderURL as NSURL).path!)
                    
                    if present {
                        defaults!.set("special", forKey: key)
                        updatesAvailable = true
                    } else {
                        defaults!.set("true", forKey: key)
                        updatesAvailable = true
                    }
                }
            }
            if updatesAvailable {
                defaults!.synchronize()
            }

//            let status :String? = defaults?.string(forKey: absolutePath)
//            if let thestatus = status {
//                if(thestatus != "request"){
//                    // we have a status object, lets use it
//                    whichBadge = 1
//                }
//            } else {
//                defaults!.set("request", forKey: absolutePath)
//                defaults!.synchronize()
//                whichBadge = 2
//            }
            
            
            sleep(1)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        //NSLog("quiting git-annex-mac AppDelegate")
    }


}

