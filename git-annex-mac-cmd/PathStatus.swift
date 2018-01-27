//
//  PathStatus2.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/24/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class PathStatus: Equatable, Hashable, CustomStringConvertible {
    let isGitAnnexTracked: Bool
    let presentStatus: Present?
    let enoughCopies: EnoughCopies?
    let numberOfCopies: UInt8?
    let path: String
    let parentWatchedFolderUUIDString: String
    let modificationDate: Double
    
    init(isGitAnnexTracked: Bool, presentStatus: Present?, enoughCopies: EnoughCopies?, numberOfCopies: UInt8?, path: String, parentWatchedFolderUUIDString: String, modificationDate: Double) {
        self.isGitAnnexTracked = isGitAnnexTracked
        self.presentStatus = presentStatus
        self.enoughCopies = enoughCopies
        self.numberOfCopies = numberOfCopies
        self.path = path
        self.parentWatchedFolderUUIDString = parentWatchedFolderUUIDString
        self.modificationDate = modificationDate
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
    public var description: String {
        return "PathStatus: tracked:\(isGitAnnexTracked) present:\(presentStatus) enough-copies:\(enoughCopies) number-of-copies:\(numberOfCopies) path:\(path) in:\(parentWatchedFolderUUIDString) last-modified:\(modificationDate)"
    }
}
