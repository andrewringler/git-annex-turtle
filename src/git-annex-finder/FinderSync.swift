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
    var finderSyncMenus: FinderSyncMenus?
    var keepAlive: AppTurtleMessagePortPingKeepAlive?
    
    let badgeIcons: BadgeIcons
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-turtle-logo"))

    override init() {
        badgeIcons = BadgeIcons(finderSyncController: FIFinderSyncController.default())

        super.init()
        finderSyncCore = FinderSyncCore(finderSync: self, data: DataEntrypoint())
        keepAlive = AppTurtleMessagePortPingKeepAlive(id: id(), stoppable: finderSyncCore!)
        finderSyncMenus = FinderSyncMenus(finderSync: self)
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
        TurtleLog.debug("updating badge for '\(url)' to \(status) badgeName=\(badgeName)")
        
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
        /* returning "" here would hide the toolbar menu,
         * but we can't do that dynamically since Finder doesn't re-read this value
         * we could show/hide the toolbar via a UI preference, then restart Finder if
         * the user wanted…
         */
        return "git-annex-turtle"
    }
    
    override var toolbarItemToolTip: String {
        return "git-annex-turtle"
    }
    
    override var toolbarItemImage: NSImage {
        return gitAnnexTurtleLogo!
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        return finderSyncMenus?.createMenu(for: menuKind) ?? NSMenu(title: "")
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
        if let commandTypeInt = item?.tag, let commandType = MenuCommandTypeTag(rawValue: commandTypeInt) {
            switch commandType {
            // Command applies to container target (IE current Finder window path)
            case .target:
                if let currentFolder = target {
                    finderSyncCore!.commandRequest(with: command, item: currentFolder)
                } else {
                    TurtleLog.error("invalid menu item for folder-level command \(command) and target \(String(describing: target))")
                }

            // Command applies to root (entire repo) of current Finder window path
            case .repoOfTarget:
                if let watchedFolder = finderSyncCore?.watchedFolderParent(for: target) {
                    let watchedFolderURL = PathUtils.urlFor(absolutePath: watchedFolder.pathString)
                    finderSyncCore!.commandRequest(with: command, item: watchedFolderURL)
                } else {
                    TurtleLog.error("invalid menu item for repo-level command \(command) and target \(String(describing: target))")
                }
                
            // Command applies to selected items in Finder window
            case .selectedItems:
                if let items :[URL] = FIFinderSyncController.default().selectedItemURLs() {
                    for obj: URL in items {
                        finderSyncCore!.commandRequest(with: command, item: obj)
                    }
                } else {
                    TurtleLog.error("invalid item for selected items command \(command) and target \(String(describing: target))")
                }
            }
        } else {
            TurtleLog.error("invalid command type in menu for command \(command) and target \(String(describing: target))")
        }
    }
    
    func id() -> String {
        return processID
    }
}
