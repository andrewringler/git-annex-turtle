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
    let config = Config()
    var myFolderURL: URL = URL(fileURLWithPath: "/Users/Shared/MySyncExtension Documents")

    override init() {
        super.init()

        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath)

        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameColorPanel)!, label: "Status One" , forBadgeIdentifier: "One")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameCaution)!, label: "Status Two", forBadgeIdentifier: "Two")
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        debugPrint("beginObservingDirectoryAtURL: %@", (url as NSURL).filePathURL!)
    }


    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        debugPrint("endObservingDirectoryAtURL: %@", (url as NSURL).filePathURL!)
    }

    override func requestBadgeIdentifier(for url: URL) {
        debugPrint("requestBadgeIdentifierForURL: %@", (url as NSURL).filePathURL!)
        
        // For demonstration purposes, this picks one of our two badges, or no badge at all, based on the filename.
        let whichBadge = abs(((url as NSURL).filePathURL! as NSURL).hash) % 3
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
        return NSImage(named: NSImageNameCaution)!
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
        debugPrint("sampleAction: menu item: %@, target = %@, items = ", item.title, (target! as NSURL).filePathURL!)
        for obj in items! {
            debugPrint("    %@", (obj as NSURL).filePathURL!)
        }
    }

}

