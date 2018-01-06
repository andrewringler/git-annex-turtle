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
    var defaults: UserDefaults
    let myFolderURL: URL
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let imgAbsent = NSImage(named:NSImage.Name(rawValue: "git-annex-absent"))
    let imgUnknown = NSImage(named:NSImage.Name(rawValue: "git-annex-unknown"))
    let imgFullyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-fully-present-directory"))
    let imgPartiallyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-partially-present-directory"))
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))

    override init() {
        defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
        myFolderURL =  URL(fileURLWithPath: defaults.string(forKey: "myFolderURL")!)
        super.init()
        
        NSLog("FinderSync() watching %@", (myFolderURL as NSURL).path!)

        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]

        FIFinderSyncController.default().setBadgeImage(imgPresent!, label: "Present" , forBadgeIdentifier: "present")
        FIFinderSyncController.default().setBadgeImage(imgAbsent!, label: "Absent", forBadgeIdentifier: "absent")
        FIFinderSyncController.default().setBadgeImage(imgUnknown!, label: "Unknown", forBadgeIdentifier: "unknown")
        FIFinderSyncController.default().setBadgeImage(imgFullyPresentDirectory!, label: "Fully Present", forBadgeIdentifier: "fully-present-directory")
        FIFinderSyncController.default().setBadgeImage(imgPartiallyPresentDirectory!, label: "Partially Present", forBadgeIdentifier: "partially-present-directory")

        // Poll for changes
        // https://stackoverflow.com/questions/36608645/call-function-when-if-value-in-nsuserdefaults-standarduserdefaults-changes
        // https://stackoverflow.com/questions/37805885/how-to-create-dispatch-queue-in-swift-3
        DispatchQueue.global(qos: .background).async {
            while true {
                let allKeys = self.defaults.dictionaryRepresentation().keys
                var statusUpdates :Int = 0
                for key in allKeys {
                    if key.starts(with: "gitannex.status.updated.") {
                        // OK lets update the badge icon with the new updated status
                        var path = key
                        path.removeFirst("gitannex.status.updated.".count)
                        
                        if let status = self.defaults.string(forKey: key) {
                            self.updateBadge(for: URL(fileURLWithPath: path), with: status)
                            
                            // remove this .new key, we have handled it
                            self.defaults.removeObject(forKey: key)
                            
                            // replace with a standard key, that we can check for
                            // when we receive a requestBadgeIdentifier from the OS
                            // this would happen if the user closes and re-opens the
                            // a finder window we already have data for
                            self.defaults.set(status, forKey: "gitannex.status." + path)
                            
                            statusUpdates += 1
                        }
                    }
                }
                // TODO wait on updates flag? instead of sleep / polling?
                // only sleep/delay if we haven't received any updates
                // otherwise there might already been more waiting
                // while we handled these ones
                if statusUpdates == 0 {
                    sleep(1)
                }
            }
        }
    }

    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
        if let path = (url as NSURL).path {
            let key = "gitannex.observing." + path
            defaults.set(url, forKey: key)
        }
    }

    // The user is no longer seeing the container's contents.
    override func endObservingDirectory(at url: URL) {
        if let path = (url as NSURL).path {
            let key = "gitannex.observing." + path
            defaults.removeObject(forKey: key)
        }
    }
    
    private func updateBadge(for url: URL, with status: String) {
        var whichBadge :Int = 0
        if status == "absent" {
            whichBadge = 1
        } else if status == "present" {
            whichBadge = 2
        } else if status == "unknown" {
            whichBadge = 3
        } else if status == "fully-present-directory" {
            whichBadge = 4
        } else if status == "partially-present-directory" {
            whichBadge = 5
        } else {
            // nothing, no icon
            // setBadgeIdentifier below will clear an icon if there was one
        }
        
        let badgeIdentifier = ["", "absent", "present", "unknown", "fully-present-directory", "partially-present-directory"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        if let path = (url as NSURL).path {
            let statusKey = "gitannex.status." + path
            
            // do we already have the status cached?
            if let status = defaults.string(forKey: statusKey) {
                updateBadge(for: url, with: status)
                return
            }
            
            // OK status is not available, lets request it
            let requestKey = "gitannex.requestbadge." + path
            defaults.set(url, forKey: requestKey)
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

