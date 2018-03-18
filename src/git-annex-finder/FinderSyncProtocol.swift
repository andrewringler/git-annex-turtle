//
//  FinderSyncProtocol.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 3/16/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

protocol FinderSyncProtocol {
    func updateBadge(for url: URL, with status: PathStatus)
    func setWatchedFolders(to: Set<URL>)

    func id() -> String
}
