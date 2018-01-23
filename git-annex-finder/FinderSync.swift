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

    var watchedFolders = Set<WatchedFolder>()
    let statusCache: StatusCache
    var lastHandledDatabaseChangesDateSinceEpochAsDouble: Double = 0
    
//    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "Solid4Green12x12"))
    let imgAbsent = NSImage(named:NSImage.Name(rawValue: "git-annex-absent"))
    let imgPresentNotNumCopies = NSImage(named:NSImage.Name(rawValue: "git-annex-present-not-numcopies"))
    let imgAbsentNotNumCopies = NSImage(named:NSImage.Name(rawValue: "git-annex-absent-not-numcopies"))
    let imgPresentCalculatingNumCopies = NSImage(named:NSImage.Name(rawValue: "git-annex-present-calculating-numcopies"))
    let imgAbsentCalculatingNumCopies = NSImage(named:NSImage.Name(rawValue: "git-annex-absent-calculating-numcopies"))

    let imgUnknown = NSImage(named:NSImage.Name(rawValue: "git-annex-unknown"))
    let imgFullyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-fully-present-directory"))
    let imgPartiallyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-partially-present-directory"))
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    
    override init() {
        statusCache = StatusCache(data: data)
        
        super.init()
        
        //
        // Badge Icons
        //
        // setup our badge icons
        //
        FIFinderSyncController.default().setBadgeImage(imgPresent!, label: "Present" , forBadgeIdentifier: Status.present.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsent!, label: "Absent", forBadgeIdentifier: Status.absent.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgPresentNotNumCopies!, label: "Present Not Numcopies" , forBadgeIdentifier: Status.presentNotNumcopies.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsentNotNumCopies!, label: "Absent Not Numcopies", forBadgeIdentifier: Status.absentNotNumcopies.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgPresentCalculatingNumCopies!, label: "Present Counting Copies…" , forBadgeIdentifier: Status.presentCalculatingNumcopies.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsentCalculatingNumCopies!, label: "Absent Counting Copies…", forBadgeIdentifier: Status.absentCalculatingNumcopies.rawValue)
        
        FIFinderSyncController.default().setBadgeImage(imgUnknown!, label: "Unknown", forBadgeIdentifier: Status.unknown.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgPartiallyPresentDirectory!, label: "Partially Present", forBadgeIdentifier: Status.partiallyPresentDirectory.rawValue)
        
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
        //
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleDatabaseUpdatesIfAny()
                sleep(1)
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

            NSLog("Finder Sync is now watching: [\(WatchedFolder.pretty(watchedFolders))]")
        }
    }
    
    func handleDatabaseUpdatesIfAny() {
        let queries = Queries(data: self.data)
        if let moreRecentUpdatesTime = queries.timeOfMoreRecentUpdatesBlocking(lastHandled: lastHandledDatabaseChangesDateSinceEpochAsDouble) {
            NSLog("Handling updates from \(moreRecentUpdatesTime) \(id())")
            // save this new time, marking it as handled (for this process)
            lastHandledDatabaseChangesDateSinceEpochAsDouble = moreRecentUpdatesTime

            updateWatchedFolders(queries: queries)
            
            for watchedFolder in self.watchedFolders {
                let statuses: [(path: String, status: String)] = queries.allNonRequestStatusesBlocking(in: watchedFolder)
                //            NSLog("found \(statuses.count) statuses \(self.id)")
                for status in statuses {
                    if let cachedStatus = statusCache.get(for: status.path), cachedStatus.rawValue == status.status {
                        // OK, this value is identical to the one in our cache, ignore
                    } else {
                        //                    NSLog("found a new status \(status.status) \(self.id)")
                        // updated value
                        let url = PathUtils.url(for: status.path)
                        statusCache.put(statusString: status.status, for: status.path)
                        updateBadge(for: url, with: status.status)
                    }
                }
            }
        }
    }
    
    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
        NSLog("beginObservingDirectory for \(url) \(id())")
        if let path = PathUtils.path(for: url) {
            for watchedFolder in watchedFolders {
                if path.starts(with: watchedFolder.pathString) {
                    Queries(data: data).addVisibleFolderAsync(for: path, in: watchedFolder)
                    return
                }
            }
        } else {
            NSLog("beginObservingDirectory: error, could not generate path for URL '\(url)'")
        }
        NSLog("beginObservingDirectory: error, could not find watched folder for URL '\(url)' path='\(PathUtils.path(for: url) ?? "")' in watched folders \(WatchedFolder.pretty(watchedFolders))")
    }
    
    // The user is no longer seeing the container's contents.
    override func endObservingDirectory(at url: URL) {
        NSLog("endObservingDirectory for \(url) \(id())")
        if let path = PathUtils.path(for: url) {
            Queries(data: data).removeVisibleFolderAsync(for: path)
        } else {
            NSLog("endObservingDirectory could not generate path string for url '\(url)'")
        }
    }
    
    private func updateBadge(for url: URL, with status: String) {
        if (Thread.isMainThread) {
            FIFinderSyncController.default().setBadgeIdentifier(Status.status(from: status).rawValue, for: url)
        } else {
            DispatchQueue.main.async {
                FIFinderSyncController.default().setBadgeIdentifier(Status.status(from: status).rawValue, for: url)
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
        NSLog("requestBadgeIdentifier for \(url) \(id())")
        
        if let path = PathUtils.path(for: url) {
            if let watchedFolder = self.watchedFolderParent(for: path) {
                
                // already have the status? then use it
                if let status = self.statusCache.get(for: path) {
                    self.updateBadge(for: url, with: status.rawValue)
                    return
                }

                // OK, status is not in the cache, maybe it is in the Db?
                DispatchQueue.global(qos: .background).async {
                    if let status = self.statusCache.getAndCheckDb(for: path) {
                        self.updateBadge(for: url, with: status.rawValue)
                        return
                    }
                    
                    // OK, we don't have the status in the Db, lets request it
                    let queries = Queries(data: self.data)
                    queries.addRequestAsync(for: path, in: watchedFolder)
                }
            } else {
                NSLog("Finder Sync could not find watched parent for url= \(url)")
            }
        } else {
            NSLog("Finder Sync could not find path for url= \(url)")
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
                if let path = PathUtils.path(for: obj) {
                    for watchedFolder in watchedFolders {
                        if path.starts(with: watchedFolder.pathString) {
                            NSLog("submitting command request \(command) for \(path)")
                            queries.submitCommandRequest(for: path, in: watchedFolder, commandType: command.commandType, commandString: command.commandString)
                            break
                        }
                    }
                }
            }
        } else {
            NSLog("invalid context menu item for command \(command) and target \(target)")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        NSLog("quiting \(id())")
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return data.applicationShouldTerminate(sender)
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return data.windowWillReturnUndoManager(window: window)
    }
    
    func id() -> String {
        return String(UInt(bitPattern: ObjectIdentifier(self)))
    }
}
