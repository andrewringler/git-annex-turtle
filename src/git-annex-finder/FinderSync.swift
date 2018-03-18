//
//  FinderSync.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync
import CoreData

class FinderSync: FIFinderSync, FinderSyncProtocol {
    // Save off our Process Identifier, since each get request will be different (because of timestamping)
    let processID: String = ProcessInfo().globallyUniqueString

    var finderSyncCore: FinderSyncCore?
        
    let badgeIcons: BadgeIcons
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    
    override init() {
        badgeIcons = BadgeIcons(finderSyncController: FIFinderSyncController.default())

        super.init()
        finderSyncCore = FinderSyncCore(finderSync: self, data: DataEntrypoint())
    }
    
    func setWatchedFolders(to newWatchedFolders: Set<URL>) {
        if (Thread.isMainThread) {
            FIFinderSyncController.default().directoryURLs = newWatchedFolders
        } else {
            DispatchQueue.main.sync {
                FIFinderSyncController.default().directoryURLs = newWatchedFolders
            }
        }
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        finderSyncCore!.requestBadgeIdentifier(for: url)
    }

    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
        finderSyncCore!.beginObservingDirectory(at: url)
    }
    
    // The user is no longer seeing the container's contents.
    // TODO this is process specific I think. IE if a user loads
    // a file window it will have its own Finder Sync process and generate
    // its own set of start and end calls
    override func endObservingDirectory(at url: URL) {
        finderSyncCore!.endObservingDirectory(at: url)
    }
    
    func updateBadge(for url: URL, with status: PathStatus) {
        let badgeName: String = badgeIcons.badgeIconFor(status: status)
        
        // its a GUI thing, must happen on the main thread
        if (Thread.isMainThread) {
            FIFinderSyncController.default().setBadgeIdentifier(badgeName, for: url)
        } else {
            DispatchQueue.main.async {
                FIFinderSyncController.default().setBadgeIdentifier(badgeName, for: url)
            }
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
        // If the user control clicked on a single file
        // grab its status, if we have it cached
        var statusOptional: PathStatus? = nil
        if menuKind == FIMenuKind.contextualMenuForItems, let items :[URL] = FIFinderSyncController.default().selectedItemURLs(), items.count == 1, let item = items.first {
            statusOptional = finderSyncCore!.status(for: item)
        }
        
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        var menuItem = NSMenuItem()
        
        // If the user ctrl-clicked a single item that we have status information about
        // then summarize the status as the first menu item
        if let status: PathStatus = statusOptional, status.isGitAnnexTracked, let present = status.presentStatus {
            var menuTitle = "\(present.menuDisplay())"
            if let numberOfCopies = status.numberOfCopies {
                menuTitle = menuTitle + ", \(numberOfCopies) copies"
            }
            if let enough = status.enoughCopies {
                menuTitle = menuTitle + " (\(enough.menuDisplay()))"
            }
            menuItem = menu.addItem(withTitle: menuTitle, action: nil, keyEquivalent: "")
        }
        
        menuItem = menu.addItem(withTitle: "git annex get", action: #selector(gitAnnexGet(_:)), keyEquivalent: "g")
        menuItem.image = gitAnnexLogoNoArrowsColor
        menuItem = menu.addItem(withTitle: "git annex add", action: #selector(gitAnnexAdd(_:)), keyEquivalent: "a")
        menuItem.image = gitAnnexLogoNoArrowsColor
        menuItem = menu.addItem(withTitle: "git annex lock", action: #selector(gitAnnexLock(_:)), keyEquivalent: "l")
        menuItem.image = gitAnnexLogoNoArrowsColor
        menuItem = menu.addItem(withTitle: "git annex unlock", action: #selector(gitAnnexUnlock(_:)), keyEquivalent: "u")
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        menuItem = menu.addItem(withTitle: "git annex drop", action: #selector(gitAnnexDrop(_:)), keyEquivalent: "d")
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        // TODO add copy and copy --to menu items
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
        commandRequest(with: .gitAnnex(.get), target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexAdd(_ sender: AnyObject?) {
        commandRequest(with: .gitAnnex(.add), target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexDrop(_ sender: AnyObject?) {
        commandRequest(with: .gitAnnex(.drop), target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexLock(_ sender: AnyObject?) {
        commandRequest(with: .gitAnnex(.lock), target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexUnlock(_ sender: AnyObject?) {
        commandRequest(with: .gitAnnex(.unlock), target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAdd(_ sender: AnyObject?) {
        commandRequest(with: .git(.add), target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    
    private func commandRequest(with command: GitOrGitAnnexCommand, target: URL?, item: NSMenuItem?, items: [URL]?) {
        if let items :[URL] = FIFinderSyncController.default().selectedItemURLs() {
            for obj: URL in items {
                finderSyncCore!.commandRequest(with: command, item: obj)
            }
        } else {
            TurtleLog.error("invalid context menu item for command \(command) and target \(String(describing: target))")
        }
    }
    
    func id() -> String {
        return processID
    }
}
