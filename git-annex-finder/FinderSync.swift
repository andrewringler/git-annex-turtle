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

extension UserDefaults {
    @objc dynamic var watchedFolderUpdated: Double {
        return double(forKey: GitAnnexTurtleUserDefaultsWatchedFoldersUpdated)
    }
}

class FinderSync: FIFinderSync {
    let defaults: UserDefaults
    let data = DataEntrypoint()

    var watchedFolders = Set<WatchedFolder>()
    var watchAppGroup: Witness?
    let statusCache: StatusCache
    var observeFolderUpdatedNotificationOnUserDefaults: NSKeyValueObservation?
    var lastHandledDatabaseChangesDateSinceEpochAsDouble: Double = 0
    
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
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
    
    func id() -> String {
        return String(UInt(bitPattern: ObjectIdentifier(self)))
    }
    
    func updateWatchedFolders(queries: Queries) {
        let newWatchedFolders: Set<WatchedFolder> = queries.allWatchedFoldersBlocking()
//        NSLog("New watched folders: '\(newWatchedFolders.map { $0.pathString })'")
        if newWatchedFolders != watchedFolders {
            watchedFolders = newWatchedFolders

            if (Thread.isMainThread) {
                FIFinderSyncController.default().directoryURLs = Set(newWatchedFolders.map { URL(fileURLWithPath: $0.pathString) })
            } else {
                DispatchQueue.main.sync {
                    FIFinderSyncController.default().directoryURLs = Set(newWatchedFolders.map { URL(fileURLWithPath: $0.pathString) })
                }
            }

            NSLog("Finder Sync is watching: ")
            for watchedFolder in watchedFolders {
                NSLog(watchedFolder.pathString)
                NSLog(watchedFolder.uuid.uuidString)
            }
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
    
    override init() {
        defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
        statusCache = StatusCache(data: data)

        super.init()

        // Set up the directories we are syncing on
        updateWatchedFolders(queries: Queries(data: data))
        
        // NOTE:
        // I tried using File System API monitors on the sqlite database
        // and I tried using observe on UserDefaults
        // none worked reliably, perhaps Finder Sync Extensions are designed to ignore/miss notifications?
        // or perhaps the Finder Sync extension is going into a background mode and not waking up?
        DispatchQueue.global(qos: .background).async {
            while true {
                self.handleDatabaseUpdatesIfAny()
                sleep(1)
            }
        }
        
        // Monitor File System for changes to the database on disk
        // NOTE: I tried observing UserDefaults for changes, but Finder Sync
        // seems to stop observing after the first observation
//        let queue = DispatchQueue.global(qos: .background)
//        let handleDatabaseUpdatesDebounce = debounce(delay: .milliseconds(300), queue: queue, action: handleDatabaseUpdates)
//        let sharedGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
//        watchAppGroup = Witness(paths: [PathUtils.path(for: sharedGroupContainer!)!], flags: .FileEvents, latency: 0.1) { events in
//            NSLog("Calling handleDatabaseUpdatesDebounce \(self.id)")
//            handleDatabaseUpdatesDebounce()
//        }
        
        // Listen for changes on watched folders
//        defaults.set("listening", forKey: "\(GitAnnexTurtleDbPrefix)\(String(id()))")
        
        // https://stackoverflow.com/a/47856467/8671834
//        defaults.observe
//        observeFolderUpdatedNotificationOnUserDefaults = defaults.observe(\.watchedFolderUpdated, options: [.initial, .new], changeHandler: { (defaults, change) in
//            // your change logic here
//            NSLog("Finally, got userDfeaults updates on observer for \(self.id())")
//        })
//        observeFolderUpdatedNotificationOnUserDefaults
        
        
        // doesn't work below!!
//        defaults.addObserver(self, forKeyPath: GitAnnexTurtleUserDefaultsWatchedFoldersUpdated, options: [.new, .initial], context: nil)
        
        FIFinderSyncController.default().setBadgeImage(imgPresent!, label: "Present" , forBadgeIdentifier: Status.present.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsent!, label: "Absent", forBadgeIdentifier: Status.absent.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgPresentNotNumCopies!, label: "Present Not Numcopies" , forBadgeIdentifier: Status.presentNotNumcopies.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsentNotNumCopies!, label: "Absent Not Numcopies", forBadgeIdentifier: Status.absentNotNumcopies.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgPresentCalculatingNumCopies!, label: "Present Counting Copies…" , forBadgeIdentifier: Status.presentCalculatingNumcopies.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsentCalculatingNumCopies!, label: "Absent Counting Copies…", forBadgeIdentifier: Status.absentCalculatingNumcopies.rawValue)

        FIFinderSyncController.default().setBadgeImage(imgUnknown!, label: "Unknown", forBadgeIdentifier: Status.unknown.rawValue)
//        FIFinderSyncController.default().setBadgeImage(imgFullyPresentDirectory!, label: "Fully Present", forBadgeIdentifier: "fully-present-directory")
        FIFinderSyncController.default().setBadgeImage(imgPartiallyPresentDirectory!, label: "Partially Present", forBadgeIdentifier: Status.partiallyPresentDirectory.rawValue)
        
        // Get notified on Db changes
        // see https://cocoacasts.com/how-to-observe-a-managed-object-context
//        let managedObjectContext = data.persistentContainer.viewContext
//        let notificationCenter = NotificationCenter.default
//        notificationCenter.addObserver(self, selector: #selector(managedObjectContextObjectsDidChange), name: NSManagedObjectContextObjectsDidChangeNotification, object: managedObjectContext)
//        notificationCenter.addObserver(self, selector: #selector(managedObjectContextWillSave), name: NSManagedObjectContextWillSaveNotification, object: managedObjectContext)
//        notificationCenter.addObserver(self, selector: #selector(managedObjectContextDidSave), name: NSNotification.Name.NSManagedObjectContextDidSave, object: managedObjectContext)
        
        // Poll for changes
        // https://stackoverflow.com/questions/36608645/call-function-when-if-value-in-nsuserdefaults-standarduserdefaults-changes
        // https://stackoverflow.com/questions/37805885/how-to-create-dispatch-queue-in-swift-3
//        DispatchQueue.global(qos: .background).async {
//            while true {
//                let defaultsDict = self.defaults.dictionaryRepresentation()
//                let allKeys = defaultsDict.keys
//
//                for watchedFolder in self.watchedFolders {
//                    // find all status update keys for this watched folder
//                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder)) }) {
//                        var path = key
//                        path.removeFirst(GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder).count)
//                        if let status = self.defaults.string(forKey: key) {
//                            // instantiating URL directly doesn't work, it prepends the container path
//                            // see https://stackoverflow.com/questions/27062454/converting-url-to-string-and-back-again
//                            let url = PathUtils.url(for: path)
//                            self.updateBadge(for: url, with: status)
//
//                            // remove this .updated key, we have handled it
//                            self.defaults.removeObject(forKey: key)
//
//                            // replace with a standard status key, that we can check for
//                            // when we receive a requestBadgeIdentifier from the OS
//                            // this would happen if the user closes and re-opens the
//                            // a finder window we already have data for
//                            self.defaults.set(status, forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder))
//                        } else {
//                            NSLog("could not find value for key %@", key)
//                        }
//                    }
//                }
//
//                // TODO wait on updates flag? instead of sleep / polling?
//                sleep(1)
//
//                self.updateWatchedFolders()
//            }
//        }
        
        // TODO trigger this by observing a property on UserDefaults
//        DispatchQueue.global(qos: .background).async {
//            while true {
////                NSLog("Checking for updates \(self.id())")
////                self.updateWatchedFolders()
//
//                let queries = Queries(data: self.data)
//                for watchedFolder in self.watchedFolders {
//                    let statuses: [(path: String, status: String)] = queries.allNonRequestStatusesBlocking(in: watchedFolder)
//                    for status in statuses {
//                        // TODO only update if changed?
//                        let url = PathUtils.url(for: status.path)
//                        self.statusCache.put(statusString: status.status, for: status.path)
//                        self.updateBadge(for: url, with: status.status)
//                    }
//                }
//
//                sleep(5)
//            }
//        }
    }
    
//    private func handleDbChange(changedObjects: Set<NSManagedObject>) {
//        for changed in changedObjects {
//            if let entityName = changed.entity.name, entityName == PathStatusEntityName  {
//                //                    NSLog("handling status update")
//                /*                     if let statusString = firstStatus.value(forKeyPath: "\(PathStatusAttributes.statusString.rawValue)") as? String {
//                 ret = Status.status(from: statusString)
//                 }
//                 */
//
//                let committedValues = changed.committedValues(forKeys: nil)
//                //PathStatusAttributesAll)
//                if let statusString = committedValues[PathStatusAttributes.statusString.rawValue] as? String, statusString != Status.request.rawValue,
//                    let watchedFolderUUIDString = committedValues[PathStatusAttributes.watchedFolderUUIDString.rawValue] as? String,
//                    let pathString = committedValues[PathStatusAttributes.pathString.rawValue] as? String {
//                    // are we still watching this path?
//                    for watchedFolder in watchedFolders {
//                        if watchedFolder.uuid.uuidString == watchedFolderUUIDString {
//                            let url = PathUtils.url(for: pathString)
//                            self.updateBadge(for: url, with: statusString)
//                        }
//                    }
//                }
////                else {
////                    NSLog("invalid entity \(String(describing: changed as AnyObject))")
////                }
//            }
//        }
//    }
    
    // TODO move into Queries class
    // TODO what thread is this on?
//    @objc func managedObjectContextDidSave(notification: NSNotification) {
//        NSLog("managedObjectContextDidSave")
//        guard let userInfo = notification.userInfo else {
//            NSLog("could not retrieve userInfo")
//            return
//        }
//
//        if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
//            handleDbChange(changedObjects: inserts)
//            NSLog("--- INSERTS ---")
//            NSLog(String(describing: inserts as AnyObject))
//            NSLog("+++++++++++++++")
//        }
//
//        if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, updates.count > 0 {
//            NSLog("--- UPDATES ---")
//            for update in updates {
//                NSLog(String(describing: update.changedValues()  as AnyObject))
//            }
//            NSLog("+++++++++++++++")
//            handleDbChange(changedObjects: updates)
//        }
//
//        if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, deletes.count > 0 {
//            NSLog("--- DELETES ---")
//            NSLog(String(describing: deletes as AnyObject))
//            NSLog("+++++++++++++++")
//            // ignore
//        }
//    }
    
    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
        NSLog("beginObservingDirectory for \(url) \(id())")
    }
    
    // The user is no longer seeing the container's contents.
    override func endObservingDirectory(at url: URL) {
        NSLog("endObservingDirectory for \(url) \(id())")
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

//
//                        // https://stackoverflow.com/a/43963368/8671834
//                        let waitOnKey = GitAnnexTurtleStatusUpdatedDbPrefix(for: path, in: watchedFolder)
//                        self.defaults.addObserver(self, forKeyPath: waitOnKey, options: [.initial, .new], context: nil)
//
//                        return
//                    }
//                }
//                NSLog("Finder Sync could not find watched parent for url '%@'", PathUtils.path(for: url) ?? "")
//            } else {
//                NSLog("unable to get path for url '%@'", url.absoluteString)
//            }
//        }}
//    }
    
//    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
//
//        NSLog("Received update on UserDefaults \(keyPath) for object \(object) \(id())")
//
//        if let key = keyPath {
//            if key == GitAnnexTurtleUserDefaultsWatchedFoldersUpdated {
//                NSLog("Finder Sync got notice to update list of watched folders \(id())")
//                updateWatchedFolders()
//            }
////            NSLog("observeValue, key='\(key)' object=\(object) change=\(change)")
//
//
////            for watchedFolder in watchedFolders {
////                if key.contains(watchedFolder.uuid.uuidString) {
////                    let prefix = GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder)
////                    if key.contains(prefix) {
////                        var path = key
////                        path.removeFirst(prefix.count)
////                        if let status = defaults.string(forKey: key) {
////
////                            let url = PathUtils.url(for: path)
////                            updateBadge(for: url, with: status)
////
////                            // remove this .updated key, we have handled it
////                            defaults.removeObject(forKey: key)
////
////                            // replace with a standard status key, that we can check for
////                            // when we receive a requestBadgeIdentifier from the OS
////                            // this would happen if the user closes and re-opens the
////                            // a finder window we already have data for
////                            defaults.set(status, forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder))
////                        } else {
////                            NSLog("could not find status for key='\(key)' \(id())")
////                        }
////                    }
////                }
////            }
//        }
//
//        if let key = keyPath {
//            var path = key
//            path.removeFirst(GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder).count)
//            if let status = self.defaults.string(forKey: key) {
//
//            }
//
//        }
//back-again
        //                            let url = PathUtils.url(for: path)
        //                            self.updateBadge(for: url, with: status)
        //
        //                            // remove this .updated key, we have handled it
        //                            self.defaults.removeObject(forKey: key)
        //
        //                            // replace with a standard status key, that we can check for
        //                            // when we receive a requestBadgeIdentifier from the OS
        //                            // this would happen if the user closes and re-opens the
        //                            // a finder window we already have data for
        //                            self.defaults.set(status, forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder))
        //                        } else {
        //                            NSLog("could not find value for key %@", key)
        //                        }

//    }
    
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
        commandRequest(with: GitAnnexCommands.Get, target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexAdd(_ sender: AnyObject?) {
        commandRequest(with: GitAnnexCommands.Add, target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexDrop(_ sender: AnyObject?) {
        commandRequest(with: GitAnnexCommands.Drop, target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexLock(_ sender: AnyObject?) {
        commandRequest(with: GitAnnexCommands.Lock, target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAnnexUnlock(_ sender: AnyObject?) {
        commandRequest(with: GitAnnexCommands.Unlock, target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    @IBAction func gitAdd(_ sender: AnyObject?) {
        commandRequest(with: GitCommands.Add, target: FIFinderSyncController.default().targetedURL(), item: sender as? NSMenuItem, items: FIFinderSyncController.default().selectedItemURLs())
    }
    
    private func commandRequest(with command: Command, target: URL?, item: NSMenuItem?, items: [URL]?) {
        if let items :[URL] = FIFinderSyncController.default().selectedItemURLs() {
            for obj: URL in items {
                if let path = PathUtils.path(for: obj) {
                    for watchedFolder in watchedFolders {
                        if path.starts(with: watchedFolder.pathString) {
                            let key = command.dbPrefixWithUUID(for: path, in: watchedFolder)
                            NSLog("git annex %@ \"%@\"", command.cmdString, key)
                            defaults.set(obj, forKey: command.dbPrefixWithUUID(for: path, in: watchedFolder))
                            break
                        }
                    }
                }
            }
        } else {
            NSLog("invalid context menu item for command %@", command.cmdString)
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
    
//    deinit {
//        observeFolderUpdatedNotificationOnUserDefaults?.invalidate()
//    }
}
