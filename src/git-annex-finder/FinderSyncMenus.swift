//
//  FinderSyncMenus.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 5/1/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa
import FinderSync

class FinderSyncMenus {
    let finderSync: FinderSync
    let finderSyncCore: FinderSyncCore
    
    let gitLogoOrange = NSImage(named:NSImage.Name(rawValue: "git-logo-orange"))
    let gitAnnexLogoNoArrowsColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-no-arrows"))
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-turtle-logo"))

    init(finderSync: FinderSync) {
        self.finderSync = finderSync
        self.finderSyncCore = finderSync.finderSyncCore!
    }
    
    public func createMenu(for menuKind: FIMenuKind) -> NSMenu {
        switch menuKind {
        case .toolbarItemMenu: // Toolbar Menu
            return toolbarItemMenu()
        case .contextualMenuForContainer: // Finder Window Background
            return NSMenu(title: "background")
        case .contextualMenuForItems: // Selected Items
            return contextualMenuForItemsMenu()
        case .contextualMenuForSidebar: // Sidebar Menu
            return NSMenu(title: "sidebar")
        }
    }

    private func contextualMenuForItemsMenu() -> NSMenu {
        // If the user control clicked on a single file
        // grab its status, if we have it cached
        var statusOptional: PathStatus? = nil
        var singleFile: Bool = false
        var isSingleDirectory: Bool = false
        if let items :[URL] = FIFinderSyncController.default().selectedItemURLs(), items.count == 1, let item = items.first {
            singleFile = true
            statusOptional = finderSyncCore.status(for: item)
            isSingleDirectory = item.hasDirectoryPath
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
        
        menuItem = menu.addItem(withTitle: "git annex get", action: #selector(finderSync.gitAnnexGet(_:)), keyEquivalent: "g")
        menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.command
        menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        menuItem = menu.addItem(withTitle: "git annex add", action: #selector(finderSync.gitAnnexAdd(_:)), keyEquivalent: "a")
        menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.command
        menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        menuItem = menu.addItem(withTitle: "git annex lock", action: #selector(finderSync.gitAnnexLock(_:)), keyEquivalent: "l")
        menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.command
        menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        menuItem = menu.addItem(withTitle: "git annex unlock", action: #selector(finderSync.gitAnnexUnlock(_:)), keyEquivalent: "u")
        menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.command
        menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        menuItem = menu.addItem(withTitle: "git annex drop", action: #selector(finderSync.gitAnnexDrop(_:)), keyEquivalent: "d")
        menuItem.keyEquivalentModifierMask = NSEvent.ModifierFlags.command
        menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
        menuItem.image = gitAnnexLogoNoArrowsColor
        
        // TODO add copy and copy --to menu items
        //        menuItem = menu.addItem(withTitle: "git annex copy --to=", action: nil, keyEquivalent: "")
        //        menuItem.image = gitAnnexLogoColor
        //        let gitAnnexCopyToMenu = NSMenu(title: "")
        //        gitAnnexCopyToMenu.addItem(withTitle: "cloud", action: #selector(gitAnnexCopy(_:)), keyEquivalent: "")
        //        gitAnnexCopyToMenu.addItem(withTitle: "usb 2tb", action: #selector(gitAnnexCopy(_:)), keyEquivalent: "")
        //        menuItem.submenu = gitAnnexCopyToMenu
        
        menuItem = menu.addItem(withTitle: "git add", action: #selector(finderSync.gitAdd(_:)), keyEquivalent: "")
        menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
        menuItem.image = gitLogoOrange
        
        // TODO handle multiple selection with Share…
        // if we bundle them in a single folder they will have a single shareable URL
        // otherwise each selection would have its own URL?
        // TODO add submenu to support multiple share locations
        // TODO suport single files… https://git-annex.branchable.com/forum/export_single_file/
        // TODO hide menuitem if user has not specified a share folder for this repo
        if isSingleDirectory {
            menuItem = menu.addItem(withTitle: "Share…", action: #selector(finderSync.share(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.selectedItems.rawValue
            menuItem.image = gitAnnexTurtleLogo
        }
        
        return menu
    }
    
    private func toolbarItemMenu() -> NSMenu {
        if let currentPath = currentPath() {
            // Repo level commands (ie git annex get .)
            let menu = NSMenu(title: "")
            var menuItem = NSMenuItem()
            
            let rootMenuItem = menu.addItem(withTitle: currentPath.watchedFolder.pathString, action: nil, keyEquivalent: "")
            let rootSubmenu = NSMenu(title: "")
            
            menuItem = rootSubmenu.addItem(withTitle: "git annex get .", action: #selector(finderSync.gitAnnexGet(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.repoOfTarget.rawValue
            menuItem.image = gitAnnexLogoNoArrowsColor
            
            menuItem = rootSubmenu.addItem(withTitle: "git annex add .", action: #selector(finderSync.gitAnnexAdd(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.repoOfTarget.rawValue
            menuItem.image = gitAnnexLogoNoArrowsColor
            
            menuItem = rootSubmenu.addItem(withTitle: "git annex lock .", action: #selector(finderSync.gitAnnexLock(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.repoOfTarget.rawValue
            menuItem.image = gitAnnexLogoNoArrowsColor
            
            menuItem = rootSubmenu.addItem(withTitle: "git annex unlock .", action: #selector(finderSync.gitAnnexUnlock(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.repoOfTarget.rawValue
            menuItem.image = gitAnnexLogoNoArrowsColor
            
            menuItem = rootSubmenu.addItem(withTitle: "git annex drop .", action: #selector(finderSync.gitAnnexDrop(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.repoOfTarget.rawValue
            menuItem.image = gitAnnexLogoNoArrowsColor
            
            menuItem = rootSubmenu.addItem(withTitle: "git add .", action: #selector(finderSync.gitAdd(_:)), keyEquivalent: "")
            menuItem.tag = MenuCommandTypeTag.repoOfTarget.rawValue
            menuItem.image = gitLogoOrange
            
            rootMenuItem.submenu = rootSubmenu
            
            if !PathUtils.isCurrent(currentPath.path) {
                // If we aren't at the root of the repo
                // then show a sub-menu for the current folder shown in Finder
                
                let subpathName = PathUtils.lastPathComponent(currentPath.path)
                
                let subpathMenuItem = menu.addItem(withTitle: currentPath.path, action: nil, keyEquivalent: "")
                
                let submenu = NSMenu(title: "")
                menuItem = submenu.addItem(withTitle: "git annex get \(subpathName)", action: #selector(finderSync.gitAnnexGet(_:)), keyEquivalent: "")
                menuItem.tag = MenuCommandTypeTag.target.rawValue
                menuItem.image = gitAnnexLogoNoArrowsColor
                
                menuItem = submenu.addItem(withTitle: "git annex add \(subpathName)", action: #selector(finderSync.gitAnnexAdd(_:)), keyEquivalent: "")
                menuItem.tag = MenuCommandTypeTag.target.rawValue
                menuItem.image = gitAnnexLogoNoArrowsColor
                
                menuItem = submenu.addItem(withTitle: "git annex lock \(subpathName)", action: #selector(finderSync.gitAnnexLock(_:)), keyEquivalent: "")
                menuItem.tag = MenuCommandTypeTag.target.rawValue
                menuItem.image = gitAnnexLogoNoArrowsColor
                
                menuItem = submenu.addItem(withTitle: "git annex unlock \(subpathName)", action: #selector(finderSync.gitAnnexUnlock(_:)), keyEquivalent: "")
                menuItem.tag = MenuCommandTypeTag.target.rawValue
                menuItem.image = gitAnnexLogoNoArrowsColor
                
                menuItem = submenu.addItem(withTitle: "git annex drop \(subpathName)", action: #selector(finderSync.gitAnnexDrop(_:)), keyEquivalent: "")
                menuItem.tag = MenuCommandTypeTag.target.rawValue
                menuItem.image = gitAnnexLogoNoArrowsColor
                
                menuItem = submenu.addItem(withTitle: "git add \(subpathName)", action: #selector(finderSync.gitAdd(_:)), keyEquivalent: "")
                menuItem.tag = MenuCommandTypeTag.target.rawValue
                menuItem.image = gitLogoOrange
                
                subpathMenuItem.submenu = submenu
                
            }
            return menu
        }
        
        // We are not on any watched path, show the general git-annex-turtle menu
        // TODO
        return NSMenu(title: "")
    }
    
    private func currentPath() -> (path: String, watchedFolder: WatchedFolder)? {
        if let finderTargetURL = FIFinderSyncController.default().targetedURL(), let absolutePath = PathUtils.path(for: finderTargetURL), let watchedFolder = finderSyncCore.watchedFolderParent(for: absolutePath), let path = PathUtils.relativePath(for: absolutePath, in: watchedFolder) {
            return (path: path, watchedFolder: watchedFolder)
        }
        return nil
    }
}
