//
//  HandleVisibleFolderUpdates.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 4/9/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class HandleVisibleFolderUpdates: StoppableService {
    private let hasWatchedFolders: HasWatchedFolders
    private let visibleFolders: VisibleFolders
    private var handler: RunNowOrAgain?
    
    init(hasWatchedFolders: HasWatchedFolders, visibleFolders: VisibleFolders) {
        self.hasWatchedFolders = hasWatchedFolders
        self.visibleFolders = visibleFolders
        super.init()
        handler = RunNowOrAgain({
            self.visibleFolders.updateListOfVisibleFolders(with: self.hasWatchedFolders.getWatchedFolders())
        })
    }
    
    public func handleNewRequests() {
        handler?.runTaskAgain()
    }
    
    public override func stop() {
        handler?.stop()
        super.stop()
    }
}
