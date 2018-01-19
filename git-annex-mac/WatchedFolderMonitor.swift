//
//  WatchedFolderMonitor.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/18/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class WatchedFolderMonitor {
    let watchedFolder: WatchedFolder
    let fileMonitor: Witness
    
    init(watchedFolder: WatchedFolder, app: AppDelegate) {
        self.watchedFolder = watchedFolder
        let queue = DispatchQueue(label: watchedFolder.uuid.uuidString, attributes: .concurrent)
        let checkForGitAnnexUpdatesDebounce = debounce1(delay: .milliseconds(120), queue: queue, action: app.checkForGitAnnexUpdates)
        
        fileMonitor = Witness(paths: [watchedFolder.pathString], flags: .FileEvents, latency: 0.1) { events in
            var shouldUpdate = false
            for event in events {
                if event.path.contains(".git/annex/misctmp") ||
                    event.path.contains(".git/annex/mergedrefs") ||
                    event.path.contains(".git/annex/tmp")
                {
                    // ignore, these can change just by read-only querying git-annex
                } else {
                    shouldUpdate = true // there is at least one change event we care about
                    continue
                }
            }
            if shouldUpdate {
                NSLog("Calling checkForGitAnnexUpdatesDebounce \(watchedFolder.pathString)")
                checkForGitAnnexUpdatesDebounce(watchedFolder)
            }
        }
    }
}
