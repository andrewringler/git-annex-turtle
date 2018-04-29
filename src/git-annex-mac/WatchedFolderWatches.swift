//
//  SetupFileSystemWatchesOnWatchedFolders.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 4/29/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class WatchedFolderWatches: StoppableService {
    lazy var runner = RunNowOrAgain {
        self.setupAnyMissingFilesystemWatchesOnWatchedFolders()
    }
    let app: WatchGitAndFinderForUpdates
    var fileSystemMonitors: [WatchedFolderMonitor] = []

    init(app: WatchGitAndFinderForUpdates) {
        self.app = app
    }
    
    public func setupMissingWatches() {
        runner.runTaskAgain()
    }
    
    public func checkAll() {
        fileSystemMonitors.forEach {
            $0.doUpdates()
        }
    }
    
    public func remove(_ watchedFolder: WatchedFolder) {
        if let index = fileSystemMonitors.index(where: { $0.watchedFolder == watchedFolder} ) {
            fileSystemMonitors.remove(at: index)
        }
    }
    
    // Setup file system watches for any folder that has completed its full scan
    // that we aren't already watching
    private func setupAnyMissingFilesystemWatchesOnWatchedFolders() {
        for watchedFolder in app.getWatchedFolders() {
            // A folder we need to start a file system watch for, is one
            // that has a commit hash in the database (meaning it is done with a full scan)
            // and one that isn't already being watched
            let handledCommits = app.queries.getLatestCommits(for: watchedFolder)
            if handledCommits.gitAnnexCommitHash != nil, (fileSystemMonitors.filter{ $0.watchedFolder == watchedFolder }).count == 0 {
                // Setup filesystem watch
                // must happen on main thread for Apple File System Events API to work
                if (Thread.isMainThread) {
                    let monitor = WatchedFolderMonitor(watchedFolder: watchedFolder, app: app)
                    self.fileSystemMonitors.append(monitor)
                    
                    // run once now, in case we missed some while setting up watch
                    monitor.doUpdates()
                } else {
                    DispatchQueue.main.sync {
                        let monitor = WatchedFolderMonitor(watchedFolder: watchedFolder, app: app)
                        self.fileSystemMonitors.append(monitor)
                        
                        // run once now, in case we missed some while setting up watch
                        monitor.doUpdates()
                    }
                }
            }
        }
    }
    
    override public func stop() {
        fileSystemMonitors.forEach { $0.stop() }
        fileSystemMonitors = []
    }
}
