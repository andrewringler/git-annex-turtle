//
//  PathStatus2.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/24/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class PathStatus: Equatable, Hashable, CustomStringConvertible {
    let isDir: Bool
    let isGitAnnexTracked: Bool
    let presentStatus: Present?
    let enoughCopies: EnoughCopies?
    let numberOfCopies: UInt8?
    let path: String
    let watchedFolder: WatchedFolder
    let parentPath: String?
    let key: String? /* folders don't have a key */
    let modificationDate: Double
    let needsUpdate: Bool
    
    init(isDir: Bool, isGitAnnexTracked: Bool, presentStatus: Present?, enoughCopies: EnoughCopies?, numberOfCopies: UInt8?, path: String, watchedFolder: WatchedFolder, modificationDate: Double, key: String?, needsUpdate: Bool) {
        self.isDir = isDir
        self.isGitAnnexTracked = isGitAnnexTracked
        self.presentStatus = presentStatus
        self.enoughCopies = enoughCopies
        self.numberOfCopies = numberOfCopies
        self.path = path
        self.parentPath = PathUtils.parent(for: path, in: watchedFolder)
        self.watchedFolder = watchedFolder
        self.modificationDate = modificationDate
        self.key = key
        self.needsUpdate = needsUpdate
    }
    
    static func ==(lhs: PathStatus, rhs: PathStatus) -> Bool {
        return lhs.isGitAnnexTracked == rhs.isGitAnnexTracked
            && lhs.presentStatus == rhs.presentStatus
        && lhs.enoughCopies == rhs.enoughCopies
        && lhs.numberOfCopies == lhs.numberOfCopies
        && lhs.path == rhs.path
        && lhs.watchedFolder == rhs.watchedFolder
        && lhs.parentPath == rhs.parentPath
        && lhs.key == rhs.key
        && lhs.isDir == rhs.isDir
    }
    
    var hashValue: Int {
        return path.hashValue
    }
    
    public var description: String {
        return "PathStatus: tracked:\(isGitAnnexTracked) present:\(String(describing: presentStatus)) enough-copies:\(String(describing: enoughCopies)) number-of-copies:\(String(describing: numberOfCopies)) path:\(path) in:\(watchedFolder) parentPath:\(String(describing: parentPath)) last-modified:\(modificationDate) key:\(String(describing: key)) isDir: \(isDir) needsUpdate: \(needsUpdate)"
    }
    
    public func isEmptyFolder() -> Bool {
        return isDir
            && presentStatus?.isPresent() ?? false
            && enoughCopies?.isEnough() ?? false
            && numberOfCopies == nil
    }
}
