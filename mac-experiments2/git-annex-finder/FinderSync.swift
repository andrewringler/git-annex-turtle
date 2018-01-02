//
//  FinderSync.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync
import Foundation

class FinderSync: FIFinderSync {
    //let config = Config()
    var myFolderURL: URL = URL(fileURLWithPath: "/Users/Shared/MySyncExtension Documents")

    override init() {
        super.init()

        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath)

        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.Name.colorPanel)!, label: "Status One" , forBadgeIdentifier: "One")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.Name.caution)!, label: "Status Two", forBadgeIdentifier: "Two")
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        NSLog("beginObservingDirectoryAtURL: " + (url as NSURL).filePathURL!.absoluteString)
    }


    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        NSLog("endObservingDirectoryAtURL: " + (url as NSURL).filePathURL!.absoluteString)
    }

    override func requestBadgeIdentifier(for url: URL) {
        NSLog("requestBadgeIdentifierForURL: " + (url as NSURL).filePathURL!.absoluteString)

        let absolutePath :String = (url as NSURL).path!

        // do we already have the status cached?
        var whichBadge :Int = 0
        let defaults = UserDefaults(suiteName: "com.andrewringler.git-annex-mac.sharedgroup")
        let status :String? = defaults?.string(forKey: "gitannex." + absolutePath)
//        let status :String? = defaults?.objectForKey(forKey: "gitannex." + absolutePath)
        if status != nil && !status!.isEmpty {
            // we have a status object, lets use it
//            whichBadge = 1
//            NSLog("hmmmm '" + status! + "'")
            if status == "true" {
                NSLog("FinderSync got updates from main host app!")
                whichBadge = 2
            }
            if status == "special" {
                NSLog("FinderSync got updates from main host app!")
                whichBadge = 1
            }
        } else {
            defaults!.set("request", forKey: "gitannex." + absolutePath)
            defaults!.synchronize()
            NSLog("set key " + "gitannex." + absolutePath)
        }
        
//        var defaults = UserDefaults(suiteName: "com.andrewringler.git-annex-mac.shared-group")
//        defaults.setObject(“blueTheme”, forKey: “request-git-annex-status”)
//        defaults.synchronize()
        
//        GitAnnexQueries.gitAnnexPathIsPresent(for: url, in: myFolderURL.path)
        
        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
//        let whichBadge = abs(((url as NSURL).filePathURL! as NSURL).hash) % 3
        let badgeIdentifier = ["", "One", "Two"][whichBadge]
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
    }

    // MARK: - Menu and toolbar item support

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
        menu.addItem(withTitle: "git-annex", action: #selector(sampleAction(_:)), keyEquivalent: "")
        return menu
    }

    @IBAction func sampleAction(_ sender: AnyObject?) {
        let target = FIFinderSyncController.default().targetedURL()
        let items = FIFinderSyncController.default().selectedItemURLs()

        let item = sender as! NSMenuItem
        NSLog("sampleAction: menu item: ", item.title, ", target = ", (target! as NSURL).filePathURL!.absoluteString, ", items = ")
        for obj in items! {
            NSLog("    " + (obj as NSURL).filePathURL!.absoluteString)
        }
    }

}

