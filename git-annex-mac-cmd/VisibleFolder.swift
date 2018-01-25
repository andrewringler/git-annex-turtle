//
//  VisibleFolder.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/20/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class VisibleFolder: Equatable, Hashable, Comparable, CustomStringConvertible {
    let parent: WatchedFolder
    let path: String
    
    init(path: String, parent: WatchedFolder) {
        self.path = path
        self.parent = parent
    }
    
    static func pretty<T>(_ visibleFolders: T) -> String where T: Sequence, T.Iterator.Element : VisibleFolder {
        return  visibleFolders.map { "\($0.path)" }.joined(separator: ",")
    }
    static func ==(lhs: VisibleFolder, rhs: VisibleFolder) -> Bool {
        return lhs.path == rhs.path
    }
    static func <(lhs: VisibleFolder, rhs: VisibleFolder) -> Bool {
        return lhs.path < rhs.path
    }
    var hashValue: Int {
        return path.hashValue
    }
    
    public var description: String { return "VisibleFolder: '\(path)' \(parent.uuid.uuidString)" }
}
