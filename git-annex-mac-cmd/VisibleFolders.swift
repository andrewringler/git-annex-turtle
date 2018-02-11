//
//  VisibleFolders.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/20/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class VisibleFolders {
    let data: DataEntrypoint
    let app: AppDelegate
    
    private var absolutePaths = Set<String>()
    private var visibleFolders = Set<VisibleFolder>()
    private let lock = NSLock() // set is NOT thread-safe, use a lock
    
    init(data: DataEntrypoint, app: AppDelegate) {
        self.data = data
        self.app = app
    }
    
    //
    // A path could be visible if it matches exactly a visible folder
    // or if it is an immediate child of a visible folder
    // this will over-eagerly catching some paths that are beyond
    // the current scroll view in a visible Finder window, that is OK
    //
    func isVisible(relativePath: String, in watchedFolder: WatchedFolder) -> Bool {
        var ret = false
        let absolutePath = PathUtils.absolutePath(for: relativePath, in: watchedFolder)
        
        lock.lock()
        if absolutePaths.contains(absolutePath) {
            ret = true
        } else if let parentPath = PathUtils.parent(for: relativePath, in: watchedFolder), absolutePaths.contains(parentPath) {
            ret = true
        }
        lock.unlock()
        
        return ret
    }
    
    //
    // Visible Folder Updates
    //
    // update our list of visible folders
    //
    func updateListOfVisibleFolders() {
        let visibleFoldersTuples = Queries(data: data).getVisibleFoldersBlocking()
        var newVisibleFolders = Set<VisibleFolder>()
        for visibleFolderTuple in visibleFoldersTuples {
            if let parent = app.watchedFolderFrom(uuid: visibleFolderTuple.watchedFolderParentUUID) {
                newVisibleFolders.insert(VisibleFolder(relativePath: visibleFolderTuple.path, parent: parent))
            } else {
                NSLog("updateListOfVisibleFolders: could not find WatchedFolder for \(visibleFolderTuple)")
            }
        }
        lock.lock()
        if visibleFolders != newVisibleFolders {
            visibleFolders = newVisibleFolders
            absolutePaths = Set(visibleFolders.map { $0.absolutePath })
            NSLog("Updated Visible: \(VisibleFolder.pretty(visibleFolders))")
        }
        lock.unlock()
    }
    
    // parent is this path, minus one component
    private func parent(for relativePath: String, in watchedFolder: WatchedFolder) -> String? {
        if PathUtils.isCurrent(relativePath) {
            return nil // no parent, we are at the root
        }
        let absolutePath = PathUtils.absolutePath(for: relativePath, in: watchedFolder)
        var url = PathUtils.urlFor(absolutePath: absolutePath)
        url.deleteLastPathComponent()
        return PathUtils.path(for: url)
    }
}
