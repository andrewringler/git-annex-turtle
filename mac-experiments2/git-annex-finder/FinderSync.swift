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
    let defaults: UserDefaults
    var watchedFolders = Set<WatchedFolder>()
    
    let imgPresent = NSImage(named:NSImage.Name(rawValue: "git-annex-present"))
    let imgAbsent = NSImage(named:NSImage.Name(rawValue: "git-annex-absent"))
    let imgPresentNotNumCopies = NSImage(named:NSImage.Name(rawValue: "git-annex-present-not-numcopies"))
    let imgAbsentNotNumCopies = NSImage(named:NSImage.Name(rawValue: "git-annex-absent-not-numcopies"))
    let imgUnknown = NSImage(named:NSImage.Name(rawValue: "git-annex-unknown"))
    let imgFullyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-fully-present-directory"))
    let imgPartiallyPresentDirectory = NSImage(named:NSImage.Name(rawValue: "git-annex-partially-present-directory"))
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))

    func updateWatchedFolders() {
        if let decoded  = defaults.object(forKey: GitAnnexTurtleWatchedFoldersDbPrefix) as? Data {
            if let newWatchedFolders = try? JSONDecoder().decode(Set<WatchedFolder>.self, from: decoded) {
                if newWatchedFolders != watchedFolders {
                    watchedFolders = newWatchedFolders
                    FIFinderSyncController.default().directoryURLs = Set(newWatchedFolders.map { URL(fileURLWithPath: $0.pathString) })
                    
                    NSLog("Finder Sync is watching: ")
                    for watchedFolder in watchedFolders {
                        NSLog(watchedFolder.pathString)
                        NSLog(watchedFolder.uuid.uuidString)
                    }
                }
            }
        }
    }
    
    override init() {
        defaults = UserDefaults(suiteName: "group.com.andrewringler.git-annex-mac.sharedgroup")!
        super.init()
        
        // Set up the directory we are syncing
        updateWatchedFolders()
        
        FIFinderSyncController.default().setBadgeImage(imgPresent!, label: "Present" , forBadgeIdentifier: Status.present.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgAbsent!, label: "Absent", forBadgeIdentifier: Status.absent.rawValue)
        FIFinderSyncController.default().setBadgeImage(imgUnknown!, label: "Unknown", forBadgeIdentifier: Status.unknown.rawValue)
//        FIFinderSyncController.default().setBadgeImage(imgFullyPresentDirectory!, label: "Fully Present", forBadgeIdentifier: "fully-present-directory")
        FIFinderSyncController.default().setBadgeImage(imgPartiallyPresentDirectory!, label: "Partially Present", forBadgeIdentifier: Status.partiallyPresentDirectory.rawValue)
        
        // Poll for changes
        // https://stackoverflow.com/questions/36608645/call-function-when-if-value-in-nsuserdefaults-standarduserdefaults-changes
        // https://stackoverflow.com/questions/37805885/how-to-create-dispatch-queue-in-swift-3
        DispatchQueue.global(qos: .background).async {
            while true {
                let defaultsDict = self.defaults.dictionaryRepresentation()
                let allKeys = defaultsDict.keys
                
                for watchedFolder in self.watchedFolders {
                    // find all status update keys for this watched folder
                    for key in allKeys.filter({ $0.starts(with: GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder)) }) {
                        var path = key
                        path.removeFirst(GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in: watchedFolder).count)
                        if let status = self.defaults.string(forKey: key) {
                            // instantiating URL directly doesn't work, it prepends the container path
                            // see https://stackoverflow.com/questions/27062454/converting-url-to-string-and-back-again
                            let url = PathUtils.url(for: path)
                            self.updateBadge(for: url, with: status)
                            
                            // remove this .updated key, we have handled it
                            self.defaults.removeObject(forKey: key)
                            
                            // replace with a standard status key, that we can check for
                            // when we receive a requestBadgeIdentifier from the OS
                            // this would happen if the user closes and re-opens the
                            // a finder window we already have data for
                            self.defaults.set(status, forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder))
                        } else {
                            NSLog("could not find value for key %@", key)
                        }
                    }
                }
                
                // TODO wait on updates flag? instead of sleep / polling?
                sleep(1)
                
                self.updateWatchedFolders()
            }
        }
    }
    
    // The user is now seeing the container's contents.
    override func beginObservingDirectory(at url: URL) {
//        if let path = (url as NSURL).path {
//            let key = "gitannex.observing." + path
//            defaults.set(url, forKey: key)
//        }
    }
    
    // The user is no longer seeing the container's contents.
    override func endObservingDirectory(at url: URL) {
//        if let path = (url as NSURL).path {
//            let key = "gitannex.observing." + path
//            defaults.removeObject(forKey: key)
//        }
    }
    
    private func updateBadge(for url: URL, with status: String) {
        FIFinderSyncController.default().setBadgeIdentifier(Status.status(from: status).rawValue, for: url)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        if let path = PathUtils.path(for: url) {
            for watchedFolder in watchedFolders {
                if path.starts(with: watchedFolder.pathString) {
                    // do we already have the status cached?
                    if let status = defaults.string(forKey: GitAnnexTurtleStatusDbPrefix(for: path, in: watchedFolder)) {
                        updateBadge(for: url, with: status)
                        return
                    }
                    
                    // OK status is not available, lets request it
                    defaults.set(url, forKey: GitAnnexTurtleRequestBadgeDbPrefix(for: path, in: watchedFolder))
                    return
                }
            }
            NSLog("Finder Sync could not find watched parent for url '%@'", PathUtils.path(for: url) ?? "")
        } else {
            NSLog("unable to get path for url '%@'", url.absoluteString)
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
}
