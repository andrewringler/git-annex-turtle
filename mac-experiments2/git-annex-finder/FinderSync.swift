//
//  FinderSync.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync
//import Foundation

class FinderSync: FIFinderSync {
    let defaults: UserDefaults
    var watchedFolders = Set<WatchedFolder>()
    var pathToURL = Dictionary<String, URL>()
    
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let imgAbsent = NSImage(named:NSImage.Name(rawValue: "git-annex-absent"))
    let imgUnknown = NSImage(named:NSImage.Name(rawValue: "git-annex-unknown"))
    let imgFullyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-fully-present-directory"))
    let imgPartiallyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-partially-present-directory"))
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))

    func updateWatchedFolders() {
        if let decoded  = defaults.object(forKey: GitAnnexTurtleWatchedFoldersDbPrefix) as? Data {
            NSKeyedUnarchiver.setClass(WatchedFolder.self, forClassName: "git_annex_turtle.WatchedFolder")
            let newWatchedFolders = NSKeyedUnarchiver.unarchiveObject(with: decoded) as! Set<WatchedFolder>
            if newWatchedFolders != watchedFolders {
                watchedFolders = newWatchedFolders
                FIFinderSyncController.default().directoryURLs = Set(newWatchedFolders.map { URL(fileURLWithPath: $0.pathString) })

                NSLog("Finder Sync is watching: ")
                for watchedFolder in watchedFolders {
                    NSLog(watchedFolder.pathString)
                    NSLog(watchedFolder.uuid.uuidString)
                }
                
                // WORKAROUND, some badges don't update their icon if set
                // soon after updating FIFinderSyncController.default().directoryURLs
                // so we'll just force update of all badges after a few seconds
//                let delayInSeconds = 20.0
//                DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
//                    self.updateAllBadges()
//                }
            }
        }
    }
    
    override init() {
        defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
        super.init()
        
        // Set up the directory we are syncing
        updateWatchedFolders()
        
        FIFinderSyncController.default().setBadgeImage(imgPresent!, label: "Present" , forBadgeIdentifier: Status.present.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsent!, label: "Absent", forBadgeIdentifier: Status.absent.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgUnknown!, label: "Unknown", forBadgeIdentifier: Status.unknown.rawValue)
//        FIFinderSyncController.default().setBadgeImage(imgFullyPresentDirectory!, label: "Fully Present", forBadgeIdentifier: "fully-present-directory")
        FIFinderSyncController.default().setBadgeImage(imgPartiallyPresentDirectory!, label: "Partially Present", forBadgeIdentifier: Status.partiallyPresentDirectory.rawValue)
        
        // Poll for changes
        // https://stackoverflow.com/questions/36608645/call-function-when-if-value-in-nsuserdefaults-standarduserdefaults-changes
        // https://stackoverflow.com/questions/37805885/how-to-create-dispatch-queue-in-swift-3
        DispatchQueue.global(qos: .background).async {
            while true {
                let defaultsDict = self.defaults.dictionaryRepresentation()
                let allKeys = defaultsDict.keys
                
                for watchedFolder in self.watchedFolders {
                    // find all status update keys for this watched folder
                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder)) }) {
                        var path = key
                        path.removeFirst(GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder).count)
                        if let status = self.defaults.string(forKey: key) {
                            // instantiating URL directly doesn't work, it prepends the container path
                            // see https://stackoverflow.com/questions/27062454/converting-url-to-string-and-back-again
                            if let url = self.pathToURL[path] {
                                self.updateBadge(for: url, with: status)
                                
                                // remove this .updated key, we have handled it
                                self.defaults.removeObject(forKey: key)
                                
                                // replace with a standard status key, that we can check for
                                // when we receive a requestBadgeIdentifier from the OS
                                // this would happen if the user closes and re-opens the
                                // a finder window we already have data for
                                self.defaults.set(status, forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder))
                            } else {
                                NSLog("unable to retrieve url for path '%@'", path)
                               // NSLog("keys in db are %@", self.pathToURL.keys)
                            }
                        } else {
                            NSLog("could not find value for key %@", key)
                        }
                    }
                }
                
                //                var statusUpdates :Int = 0
                //                for key in allKeys {
                //                    if key.starts(with: "gitannex.status.updated.") {
                //                        // OK lets update the badge icon with the new updated status
                //                        var path = key
                //                        path.removeFirst("gitannex.status.updated.".count)
                //
                //                        if let status = self.defaults.string(forKey: key) {
                //                            self.updateBadge(for: URL(fileURLWithPath: path), with: status)
                //
                //                            // remove this .new key, we have handled it
                //                            self.defaults.removeObject(forKey: key)
                //
                //                            // replace with a standard key, that we can check for
                //                            // when we receive a requestBadgeIdentifier from the OS
                //                            // this would happen if the user closes and re-opens the
                //                            // a finder window we already have data for
                //                            self.defaults.set(status, forKey: "gitannex.status." + path)
                //
                //                            statusUpdates += 1
                //                        }
                //                    }
                //                }
                // TODO wait on updates flag? instead of sleep / polling?
                
                // sleep is causing the extension to not create badges on first load
                // but getting rid of the sleep git 99%cpu
                sleep(1)
                
                self.updateWatchedFolders()
            }
        }
    }
    
    func updateAllBadges() {
        for watchedFolder in watchedFolders {
            // find all status update keys for this watched folder
            let defaultsDict = self.defaults.dictionaryRepresentation()
            let allKeys = defaultsDict.keys
            for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleStatusDbPrefixNoPath(in: watchedFolder)) }) {
                var path = key
                path.removeFirst(GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder).count)
                if let status = self.defaults.string(forKey: key) {
                    if let url = pathToURL[path] {
                        self.updateBadge(for: url, with: status)
                    } else {
                        NSLog("unable to update badge, url was never stored for path %@", path)
                    }
                } else {
                    NSLog("unable to retrieve status for key %@", key)
                }
            }
        }
    }
    
    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
//        if let path = (url as NSURL).path {
//            let key = "gitannex.observing." + path
//            defaults.set(url, forKey: key)
//        }
    }
    
    // The user is no longer seeing the container's contents.
    override func endObservingDirectory(at url: URL) {
//        if let path = (url as NSURL).path {
//            let key = "gitannex.observing." + path
//            defaults.removeObject(forKey: key)
//        }
    }
    
//    private func updateBadge(for url: URL, with status: String) {
//        var whichBadge :Int = 0
//        if status == "absent" {
//            whichBadge = 1
//        } else if status == "present" {
//            whichBadge = 2
//        } else if status == "unknown" {
//            whichBadge = 3
//        } else if status == "fully-present-directory" {
//            whichBadge = 4
//        } else if status == "partially-present-directory" {
//            whichBadge = 5
//        } else {
//            NSLog("Invalid status '%@'", status)
//            // nothing, no icon
//            // setBadgeIdentifier below will clear an icon if there was one
//        }
//
//        NSLog("settings status to '%@' for '%@'", status, url.absoluteString)
//        let badgeIdentifier = ["", "absent", "present", "unknown", "fully-present-directory", "partially-present-directory"][whichBadge]
//        NSLog("settings badgeIdentifier to '%@' for '%@'", badgeIdentifier, url.absoluteString)
//
//        pathToURL.updateValue(url, forKey: url.absoluteString)
//
//        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
//    }
    private func updateBadge(for url: URL, with status: String) {
        FIFinderSyncController.default().setBadgeIdentifier(Status.status(from: status).rawValue, for: url)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        if let path = PathUtils.path(for: url) {
            NSLog("storing url for path '%@'", path)
            pathToURL.updateValue(url, forKey: path) // store original URL
            
            for watchedFolder in watchedFolders {
                if path.starts(with: watchedFolder.pathString) {
                    // do we already have the status cached?
                    if let status = defaults.string(forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder)) {
                        updateBadge(for: url, with: status)
                        return
                    }
                    
                    // OK status is not available, lets request it
                    defaults.set(url, forKey: GitAnnexTurtleRequestBadgeDbPrefix(for: path, in: watchedFolder))
                } else {
                    NSLog("Finder Sync could not find watched parent for url '%@'", url.absoluteString)
                }
            }
        } else {
            NSLog("unable to get path for url '%@'", url.absoluteString)
        }
    }
    
    override var toolbarItemName: String {
        return "git-annex-finder"
    }
    
    override var toolbarItemToolTip: String {
        return "git-annex-finder: Click the toolbar item for a menu."
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.Name.caution)!
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        var menuItem = menu.addItem(withTitle: "git annex get", action: #selector(gitAnnexGet(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoNoArrowsColor
        menuItem = menu.addItem(withTitle: "git annex add", action: #selector(gitAnnexAdd(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoNoArrowsColor
        menuItem = menu.addItem(withTitle: "git annex lock", action: #selector(gitAnnexLock(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoNoArrowsColor
        menuItem = menu.addItem(withTitle: "git annex unlock", action: #selector(gitAnnexUnlock(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        menuItem = menu.addItem(withTitle: "git annex drop", action: #selector(gitAnnexDrop(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        //        menuItem = menu.addItem(withTitle: "git annex copy --to=", action: nil, keyEquivalent: "")
        //        menuItem.image = gitAnnexLogoColor
        //        let gitAnnexCopyToMenu = NSMenu(title: "")
        //        gitAnnexCopyToMenu.addItem(withTitle: "cloud", action: #selector(gitAnnexCopy(_:)), keyEquivalent: "")
        //        gitAnnexCopyToMenu.addItem(withTitle: "usb 2tb", action: #selector(gitAnnexCopy(_:)), keyEquivalent: "")
        //        menuItem.submenu = gitAnnexCopyToMenu
        
        menuItem = menu.addItem(withTitle: "git add", action: #selector(gitAdd(_:)), keyEquivalent: "")
        menuItem.image = gitLogoOrange
        return menu
    }
    
    @IBAction func gitAnnexGet(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex get: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj: URL in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
            defaults.set(obj, forKey: GitAnnexCommands.Get.dbPrefix + (obj as NSURL).path!)
        }
    }
    @IBAction func gitAnnexAdd(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex add: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
            defaults.set(obj, forKey: GitAnnexCommands.Add.dbPrefix + (obj as NSURL).path!)
        }
    }
    @IBAction func gitAnnexDrop(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex drop: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
            defaults.set(obj, forKey: GitAnnexCommands.Drop.dbPrefix + (obj as NSURL).path!)
        }
    }
    @IBAction func gitAnnexLock(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex lock: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
            defaults.set(obj, forKey: GitAnnexCommands.Lock.dbPrefix + (obj as NSURL).path!)
        }
    }
    @IBAction func gitAnnexUnlock(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex unlock: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
            defaults.set(obj, forKey: GitAnnexCommands.Unlock.dbPrefix + (obj as NSURL).path!)
        }
    }
    @IBAction func gitAdd(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git add: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
            defaults.set(obj, forKey: GitCommands.Add.dbPrefix + (obj as NSURL).path!)
        }
    }
}

