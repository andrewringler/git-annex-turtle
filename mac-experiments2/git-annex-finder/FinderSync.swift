//
//  FinderSync.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    var myFolderURL: NSURL = NSURL(fileURLWithPath: "/Users/Shared/MySyncExtension Documents")

    override init() {
        super.init()

        NSLog("FinderSync() launched from %@", NSBundle.mainBundle().bundlePath)

        // Set up the directory we are syncing.
        FIFinderSyncController.defaultController().directoryURLs = [self.myFolderURL]
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: NSImageNameColorPanel)!, label: "Status One" , forBadgeIdentifier: "One")
        FIFinderSyncController.defaultController().setBadgeImage(NSImage(named: NSImageNameCaution)!, label: "Status Two", forBadgeIdentifier: "Two")
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectoryAtURL(url: NSURL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        NSLog("beginObservingDirectoryAtURL: %@", url.filePathURL!)
    }


    override func endObservingDirectoryAtURL(url: NSURL) {
        // The user is no longer seeing the container's contents.
        NSLog("endObservingDirectoryAtURL: %@", url.filePathURL!)
    }

    override func requestBadgeIdentifierForURL(url: NSURL) {
        NSLog("requestBadgeIdentifierForURL: %@", url.filePathURL!)
        
        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
        let whichBadge = abs(url.filePathURL!.hash) % 3
        let badgeIdentifier = ["", "One", "Two"][whichBadge]
        FIFinderSyncController.defaultController().setBadgeIdentifier(badgeIdentifier, forURL: url)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "git-annex-finder"
    }

    override var toolbarItemToolTip: String {
        return "git-annex-finder: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImageNameCaution)!
    }

    override func menuForMenuKind(menuKind: FIMenuKind) -> NSMenu {
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        menu.addItemWithTitle("git-annex", action: #selector(sampleAction(_:)), keyEquivalent: "")
        return menu
    }

    @IBAction func sampleAction(sender: AnyObject?) {
        let target = FIFinderSyncController.defaultController().targetedURL()
        let items = FIFinderSyncController.defaultController().selectedItemURLs()

        let item = sender as! NSMenuItem
        NSLog("sampleAction: menu item: %@, target = %@, items = ", item.title, target!.filePathURL!)
        for obj in items! {
            NSLog("    %@", obj.filePathURL!)
        }
    }

}

