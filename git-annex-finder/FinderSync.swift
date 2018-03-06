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

class FinderSync: FIFinderSync {
    let data = DataEntrypoint()
    // Save off our Process Identifier, since each get request will be different (because of timestamping)
    let processID: String = ProcessInfo().globallyUniqueString
    
    var watchedFolders = Set<WatchedFolder>()
    let statusCache: StatusCache
    var lastHandledDatabaseChangesDateSinceEpochAsDouble: Double = 0
    
    let badgeIcons: BadgeIcons
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    
    override init() {
        statusCache = StatusCache(data: data)
        badgeIcons = BadgeIcons(finderSyncController: FIFinderSyncController.default())
        
        super.init()
        
        //
        // Watched Folders
        //
        // grab the list of watched folders from the database and start watching them
        //
        updateWatchedFolders(queries: Queries(data: data))
        
        //
        // Status Updates
        //
        // check the database for updates to the list of watched folders
        // and for updated statuses of watched files
        //
        //
        // NOTE:
        // I tried using File System API monitors on the sqlite database
        // and I tried using observe on UserDefaults
        // none worked reliably, perhaps Finder Sync Extensions are designed to ignore/miss notifications?
        // or perhaps the Finder Sync extension is going into a background mode and not waking up?
        // or perhaps Finder Sync extensions are meant to be transient, so can never
        // really accept notifications from the system
        //
        // TODO ooops, probably I was just registering them on a background thread
        // File System API registration requests must happen on the main thread…
        // try and retest
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleDatabaseUpdatesIfAny()
                usleep(100000)
            }
        }
    }
    
    func updateWatchedFolders(queries: Queries) {
        let newWatchedFolders: Set<WatchedFolder> = queries.allWatchedFoldersBlocking()
        if newWatchedFolders != watchedFolders {
            watchedFolders = newWatchedFolders
            
            if (Thread.isMainThread) {
                FIFinderSyncController.default().directoryURLs = Set(newWatchedFolders.map { URL(fileURLWithPath: $0.pathString) })
            } else {
                DispatchQueue.main.sync {
                    FIFinderSyncController.default().directoryURLs = Set(newWatchedFolders.map { URL(fileURLWithPath: $0.pathString) })
                }
            }
            
            TurtleLog.info("Finder Sync is now watching: [\(WatchedFolder.pretty(watchedFolders))]")
        }
    }
    
    func handleDatabaseUpdatesIfAny() {
        let queries = Queries(data: self.data)
        if let moreRecentUpdatesTime = queries.timeOfMoreRecentUpdatesBlocking(lastHandled: lastHandledDatabaseChangesDateSinceEpochAsDouble) {
            // save this new time, marking it as handled (for this process)
            lastHandledDatabaseChangesDateSinceEpochAsDouble = moreRecentUpdatesTime
            
            updateWatchedFolders(queries: queries)
            
            for watchedFolder in self.watchedFolders {
                let statuses: [PathStatus] = queries.allVisibleStatusesV2Blocking(in: watchedFolder, processID: processID)
                for status in statuses {
                    if let cachedStatus = statusCache.get(for: status.path, in: watchedFolder), cachedStatus == status {
                        // OK, this value is identical to the one in our cache, ignore
                    } else {
                        // updated value
                        TurtleLog.debug("updating to \(status) \(id())")
                        let url = PathUtils.url(for: status.path, in: watchedFolder)
                        statusCache.put(status: status, for: status.path, in: watchedFolder)
                        updateBadge(for: url, with: status)
                    }
                }
            }
        }
    }
    
    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
        TurtleLog.debug("beginObservingDirectory for \(url) \(id())")
        if let absolutePath = PathUtils.path(for: url) {
            for watchedFolder in watchedFolders {
                if absolutePath.starts(with: watchedFolder.pathString) {
                    if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                        Queries(data: data).addVisibleFolderAsync(for: path, in: watchedFolder, processID: processID)
                        return
                    } else {
                        TurtleLog.error("beginObservingDirectory: could not get relative path for \(absolutePath) in \(watchedFolder)")
                    }
                }
            }
        } else {
            TurtleLog.error("beginObservingDirectory: error, could not generate path for URL '\(url)'")
        }
        TurtleLog.error("beginObservingDirectory: error, could not find watched folder for URL '\(url)' path='\(PathUtils.path(for: url) ?? "")' in watched folders \(WatchedFolder.pretty(watchedFolders))")
    }
    
    // The user is no longer seeing the container's contents.
    // TODO this is process specific I think. IE if a user loads
    // a file window it will have its own Finder Sync process and generate
    // its own set of start and end calls
    override func endObservingDirectory(at url: URL) {
        TurtleLog.debug("endObservingDirectory for \(url) \(id())")
        if let absolutePath = PathUtils.path(for: url) {
            for watchedFolder in watchedFolders {
                if absolutePath.starts(with: watchedFolder.pathString) {
                    if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                        Queries(data: data).removeVisibleFolderAsync(for: path, in: watchedFolder, processID: processID)
                        return
                    } else {
                        TurtleLog.error("endObservingDirectory: could not get relative path for \(absolutePath) in \(watchedFolder)")
                    }
                }
            }
        } else {
            TurtleLog.error("endObservingDirectory: error, could not generate path for URL '\(url)'")
        }
        TurtleLog.error("endObservingDirectory: error, could not find watched folder for URL '\(url)' path='\(PathUtils.path(for: url) ?? "")' in watched folders \(WatchedFolder.pretty(watchedFolders))")
    }
    
    private func updateBadge(for url: URL, with status: PathStatus) {
        let badgeName: String = badgeIcons.badgeIconFor(status: status)
        
        if (Thread.isMainThread) {
            FIFinderSyncController.default().setBadgeIdentifier(badgeName, for: url)
        } else {
            DispatchQueue.main.async {
                FIFinderSyncController.default().setBadgeIdentifier(badgeName, for: url)
            }
        }
    }
    
    private func watchedFolderParent(for path: String) -> WatchedFolder? {
        for watchedFolder in self.watchedFolders {
            if path.starts(with: watchedFolder.pathString) {
                return watchedFolder
            }
        }
        return nil
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        TurtleLog.debug("requestBadgeIdentifier for \(url) \(id())")
        
        if let absolutePath = PathUtils.path(for: url) {
            if let watchedFolder = self.watchedFolderParent(for: absolutePath) {
                if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                    // Request the folder:
                    // we may already have this path in our cache
                    // but we still want to create a request to let the main app know
                    // that this path is still fresh and still in view
                    DispatchQueue.global(qos: .background).async {
                        Queries(data: self.data).addRequestV2Async(for: path, in: watchedFolder)
                    }
                    
                    // already have the status? then use it
                    if let status = self.statusCache.get(for: path, in: watchedFolder) {
                        self.updateBadge(for: url, with: status)
                        return
                    }
                    
                    // OK, status is not in the cache, maybe it is in the Db?
                    DispatchQueue.global(qos: .background).async {
                        if let status = self.statusCache.getAndCheckDb(for: path, in: watchedFolder) {
                            self.updateBadge(for: url, with: status)
                            return
                        }
                    }
                } else {
                    TurtleLog.error("Finder Sync could not get a relative path for '\(absolutePath)' in \(watchedFolder)")
                }
            } else {
                TurtleLog.error("Finder Sync could not find watched parent for url= \(url)")
            }
        } else {
            TurtleLog.error("Finder Sync could not find path for url= \(url)")
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
        if menuKind == FIMenuKind.contextualMenuForItems {
            if let items :[URL] = FIFinderSyncController.default().selectedItemURLs(), items.count == 1 {
                for obj: URL in items {
                    if let absolutePath = PathUtils.path(for: obj) {
                        for watchedFolder in watchedFolders {
                            if absolutePath.starts(with: watchedFolder.pathString) {
                                if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                                    statusOptional = statusCache.get(for: path, in: watchedFolder)
                                } else {
                                    TurtleLog.error("menu: could not retrieve relative path for \(absolutePath) in \(watchedFolder)")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        var menuItem = NSMenuItem()
        
        // If the user ctrl-clicked a single item that we have status information about
        // then summarize the status as the first menu item
        if let status = statusOptional, status.isGitAnnexTracked, let present = status.presentStatus {
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
        let queries = Queries(data: data)
        
        if let items :[URL] = FIFinderSyncController.default().selectedItemURLs() {
            for obj: URL in items {
                if let absolutePath = PathUtils.path(for: obj) {
                    for watchedFolder in watchedFolders {
                        if absolutePath.starts(with: watchedFolder.pathString) {
                            if let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
                                queries.submitCommandRequest(for: path, in: watchedFolder, commandType: command.commandType, commandString: command.commandString)
                            } else {
                                TurtleLog.error("commandRequest: could not find relative path for \(absolutePath) in \(watchedFolder)")
                            }
                            break
                        }
                    }
                }
            }
        } else {
            TurtleLog.error("invalid context menu item for command \(command) and target \(target)")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        TurtleLog.info("quiting \(id())")
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return data.applicationShouldTerminate(sender)
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return data.windowWillReturnUndoManager(window: window)
    }
    
    func id() -> String {
//        return String(UInt(bitPattern: ObjectIdentifier(self)))
        return processID
    }
}
