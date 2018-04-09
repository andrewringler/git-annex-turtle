//
//  HandleBadgeRequests.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 4/9/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class HandleBadgeRequests: StoppableService {
    private let hasWatchedFolders: HasWatchedFolders
    private let queries: Queries
    private let gitAnnexQueries: GitAnnexQueries
    private let dialogs: Dialogs
    private let fullScan: FullScan
    private var handler: RunNowOrAgain?
    
    init(hasWatchedFolders: HasWatchedFolders, fullScan: FullScan, queries: Queries, gitAnnexQueries: GitAnnexQueries, dialogs: Dialogs) {
        self.hasWatchedFolders = hasWatchedFolders
        self.fullScan = fullScan
        self.queries = queries
        self.gitAnnexQueries = gitAnnexQueries
        self.dialogs = dialogs
        super.init()
        handler = RunNowOrAgain({
            self.handleBadgeRequests()
        })
    }
    
    public func handleNewRequests() {
        handler?.runTaskAgain()
    }
    
    //
    // Badge Icon Requests
    //
    // handle requests for updated badge icons from our Finder Sync extension
    //
    private func handleBadgeRequests() -> Bool {
        var foundUpdates = false
        
        for watchedFolder in hasWatchedFolders.getWatchedFolders() {
            // Only handle badge requests for folders that aren't currently being scanned
            // TODO, give immediate feedback to the user here on some files?
            // TODO, we can miss some files if they appear after full scan enumeration
            if !fullScan.isScanning(watchedFolder: watchedFolder) {
                for path in queries.allPathRequestsV2Blocking(in: watchedFolder) {
                    foundUpdates = true
                    
                    if queries.statusForPathV2Blocking(path: path, in: watchedFolder) != nil {
                        // OK, we already have a status for this path, maybe
                        // Finder Sync missed it, lets update our last modified flag
                        // to ensure Finder Sync see it
                        queries.updateLastModifiedAsync.runTaskAgain()
                    } else {
                        // We have no information about this file
                        // enqueue it for inspection
                        watchedFolder.handleStatusRequests!.updateStatusFor(for: path, source: .badgerequest, isDir: nil, priority: .low)
                    }
                }
            }
        }
        
        return foundUpdates
    }
    
    public override func stop() {
        handler?.stop()
        super.stop()
    }
}
