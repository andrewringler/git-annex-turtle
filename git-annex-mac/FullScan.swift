//
//  FullScan.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 2/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class FullScan {
    let gitAnnexQueries: GitAnnexQueries
    let queries: Queries
    
    init(gitAnnexQueries: GitAnnexQueries, queries: Queries) {
        self.gitAnnexQueries = gitAnnexQueries
        self.queries = queries
    }
    
    func startFullScan(watchedFolder: WatchedFolder) {
    }

    func stopFullScan(watchedFolder: WatchedFolder) {
    }

    func isScanning(watchedFolder: WatchedFolder) -> Bool {
        return false
    }    
}
