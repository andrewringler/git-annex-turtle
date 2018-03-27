//
//  Cancellable.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

protocol StopProcessingWatchedFolder {
    func shouldStop(_ watchedFolder: WatchedFolder) -> Bool
}
