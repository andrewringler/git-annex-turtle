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
    let gitAnnexLogoColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-color"))

    override init() {
        defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
        myFolderURL =  URL(fileURLWithPath: defaults.string(forKey: "myFolderURL")!)
        super.init()
        
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath, " watching ", (myFolderURL as NSURL).path!)

        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]

        FIFinderSyncController.default().setBadgeImage(imgPresent!, label: "Present" , forBadgeIdentifier: "present")
        FIFinderSyncController.default().setBadgeImage(imgAbsent!, label: "Absent", forBadgeIdentifier: "absent")
        FIFinderSyncController.default().setBadgeImage(imgUnknown!, label: "Unknown", forBadgeIdentifier: "unknown")
        FIFinderSyncController.default().setBadgeImage(imgFullyPresentDirectory!, label: "Fully Present", forBadgeIdentifier: "fully-present-directory")
        FIFinderSyncController.default().setBadgeImage(imgPartiallyPresentDirectory!, label: "Partially Present", forBadgeIdentifier: "partially-present-directory")

//        DispatchQueue.global(qos: .background).async {
//            while true {
//                NSLog("a background task every 5 seconds")
//                sleep(5)
//            }
//        }
    }

    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        // Unless it is in a file dialog
    }

    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
    }

//    func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
//        NSLog("notified of change on key " + keyPath!)
//    }
    
    private func updateBadge(for url: URL, with status: String) {
        var whichBadge :Int = 0
        if status == "absent" {
            whichBadge = 1
//            NSLog("Absent Icon")
        } else if status == "present" {
            whichBadge = 2
//            NSLog("Present Icon")
        } else if status == "unknown" {
            whichBadge = 3
//            NSLog("Unknown Icon")
        } else if status == "fully-present-directory" {
            whichBadge = 4
//            NSLog("Fully Present Directory")
        } else if status == "partially-present-directory" {
            whichBadge = 5
//            NSLog("Partially Present Directory")
        } else {
//            NSLog("No Icon Yet!")
        }
        
        let badgeIdentifier = ["", "absent", "present", "unknown", "fully-present-directory", "partially-present-directory"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        let absolutePath :String = (url as NSURL).path!
        let status :String? = defaults.string(forKey: "gitannex." + absolutePath)
        
        // do we already have the status cached?
        if status != nil && !status!.isEmpty {
            // we have a status object, lets use it
            updateBadge(for: url, with: status!)
        } else {
            // TODO observer on specific property? or global observer?
            // https://stackoverflow.com/questions/36608645/call-function-when-if-value-in-nsuserdefaults-standarduserdefaults-changes

            // OK wait for an update to come in on this icon
            // https://stackoverflow.com/questions/37805885/how-to-create-dispatch-queue-in-swift-3
            DispatchQueue.global(qos: .background).async {
                while true {
                    let status :String? = self.defaults.string(forKey: "gitannex." + absolutePath)
                    if status != nil && !status!.isEmpty && status! != "request" {
                        self.updateBadge(for: url, with: status!)
                        return
                    }
                    sleep(1)
                }
            }

            defaults.set("request", forKey: "gitannex." + absolutePath)
            defaults.synchronize()
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
        menuItem.image = gitAnnexLogoColor
        menuItem = menu.addItem(withTitle: "git annex add", action: #selector(gitAnnexAdd(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoColor
        menuItem = menu.addItem(withTitle: "git annex lock", action: #selector(gitAnnexLock(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoColor
        menuItem = menu.addItem(withTitle: "git annex unlock", action: #selector(gitAnnexUnlock(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoColor
        
        menuItem = menu.addItem(withTitle: "git annex drop", action: #selector(gitAnnexDrop(_:)), keyEquivalent: "")
        menuItem.image = gitAnnexLogoColor

        menuItem = menu.addItem(withTitle: "git annex copy --to=", action: nil, keyEquivalent: "")
        menuItem.image = gitAnnexLogoColor
        let gitAnnexCopyToMenu = NSMenu(title: "")
        gitAnnexCopyToMenu.addItem(withTitle: "cloud", action: #selector(gitAnnexCopy(_:)), keyEquivalent: "")
        gitAnnexCopyToMenu.addItem(withTitle: "usb 2tb", action: #selector(gitAnnexCopy(_:)), keyEquivalent: "")
        menuItem.submenu = gitAnnexCopyToMenu
        
        menuItem = menu.addItem(withTitle: "git add", action: #selector(gitAdd(_:)), keyEquivalent: "")
        menuItem.image = gitLogoOrange
        return menu
    }

    @IBAction func gitAnnexGet(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex get: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }
    @IBAction func gitAnnexAdd(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex add: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }
    @IBAction func gitAnnexDrop(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex drop: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }
    @IBAction func gitAnnexLock(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex lock: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }
    @IBAction func gitAnnexUnlock(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex unlock: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }
    @IBAction func gitAdd(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git add: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }
    @IBAction func gitAnnexCopy(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()
        
        let item = sender as! NSMenuItem
        NSLog("git annex copy --to=", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }

}

