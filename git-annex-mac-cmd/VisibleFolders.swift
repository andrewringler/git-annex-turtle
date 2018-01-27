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
    
    private var paths = Set<String>()
    private var visibleFolders = Set<VisibleFolder>()
    private let lock = NSLock() // set is NOT thread-safe, use a lock
    
    init(data: DataEntrypoint, app: AppDelegate) {
        self.data = data
        self.app = app
    }
    
    //
    // A path is visible if it matches exactly a visible folder
    // or if it is an immediate child of a visible folder
    //
    func isVisible(path: String) -> Bool {
        var ret = false
        
        lock.lock()
        if paths.contains(path) {
            ret = true
        } else if let parentPath = parent(path), paths.contains(parentPath) {
            ret = true
        }
        lock.unlock()
        
        return ret
    }
    
    func updateListOfVisibleFolders() {
        let visibleFoldersTuples = Queries(data: data).getVisibleFoldersBlocking()
        var newVisibleFolders = Set<VisibleFolder>()
        for visibleFolderTuple in visibleFoldersTuples {
            if let parent = app.watchedFolderFrom(uuid: visibleFolderTuple.watchedFolderParentUUID) {
                newVisibleFolders.insert(VisibleFolder(path: visibleFolderTuple.path, parent: parent))
            } else {
                NSLog("updateListOfVisibleFolders: could not find WatchedFolder for \(visibleFolderTuple)")
            }
        }
        lock.lock()
        if visibleFolders != newVisibleFolders {
            visibleFolders = newVisibleFolders
            paths = Set(visibleFolders.map { $0.path })
            NSLog("Updated Visible: \(VisibleFolder.pretty(visibleFolders))")
        }
        lock.unlock()
    }
    
    // parent is this path, minus one component
    private func parent(_ path: String) -> String? {
        var url = PathUtils.url(for: path)
        url.deleteLastPathComponent()
        return PathUtils.path(for: url)
    }
}
