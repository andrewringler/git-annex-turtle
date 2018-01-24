//
//  PathStatus2.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/24/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class PathStatus: Equatable, Hashable {
    
    let isGitAnnexTracked: Bool
    let presentStatus: Present?
    let enoughCopies: EnoughCopies?
    let numberOfCopies: UInt8?
    let path: String
    let parentWatchedFolderUUIDString: String
    
    init(isGitAnnexTracked: Bool, presentStatus: Present?, enoughCopies: EnoughCopies?, numberOfCopies: UInt8?, path: String, parentWatchedFolderUUIDString: String) {
        self.isGitAnnexTracked = isGitAnnexTracked
        self.presentStatus = presentStatus
        self.enoughCopies = enoughCopies
        self.numberOfCopies = numberOfCopies
        self.path = path
        self.parentWatchedFolderUUIDString = parentWatchedFolderUUIDString
    }
    
    static func ==(lhs: PathStatus, rhs: PathStatus) -> Bool {
        return lhs.isGitAnnexTracked == rhs.isGitAnnexTracked
            && lhs.presentStatus == rhs.presentStatus
        && lhs.enoughCopies == rhs.enoughCopies
        && lhs.numberOfCopies == lhs.numberOfCopies
        && lhs.path == rhs.path
        && lhs.parentWatchedFolderUUIDString == rhs.parentWatchedFolderUUIDString
    }
    var hashValue: Int {
        return path.hashValue
    }
}
