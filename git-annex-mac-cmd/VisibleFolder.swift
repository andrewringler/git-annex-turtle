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
    let relativePath: String
    let absolutePath: String
    
    init(relativePath: String, parent: WatchedFolder) {
        self.relativePath = relativePath
        self.parent = parent
        self.absolutePath = PathUtils.absolutePath(for: relativePath, in: parent)
    }
    
    static func pretty<T>(_ visibleFolders: T) -> String where T: Sequence, T.Iterator.Element : VisibleFolder {
        return  visibleFolders.map { "\($0.absolutePath)" }.joined(separator: ",")
    }
    static func ==(lhs: VisibleFolder, rhs: VisibleFolder) -> Bool {
        return lhs.absolutePath == rhs.absolutePath
    }
    static func <(lhs: VisibleFolder, rhs: VisibleFolder) -> Bool {
        return lhs.absolutePath < rhs.absolutePath
    }
    var hashValue: Int {
        return absolutePath.hashValue
    }
    
    public var description: String { return "VisibleFolder: '\(relativePath)' \(parent.uuid.uuidString)" }
}
