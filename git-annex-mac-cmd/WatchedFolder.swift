//
//  WatchedFolder.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Foundation

class WatchedFolder: Equatable, Hashable, Comparable, Swift.Codable {
    let uuid: UUID
    let pathString: String
    
    init(uuid: UUID, pathString: String) {
        self.uuid = uuid
        self.pathString = pathString
    }
    static func pretty<T>(_ watchedFolders: T) -> String where T: Sequence, T.Iterator.Element : WatchedFolder {
        return  watchedFolders.map { "<\($0.pathString) \($0.uuid.uuidString)>" }.joined(separator: ",")
    }
    static func ==(lhs: WatchedFolder, rhs: WatchedFolder) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    static func <(lhs: WatchedFolder, rhs: WatchedFolder) -> Bool {
        return lhs.pathString < rhs.pathString
    }
    var hashValue: Int {
        return uuid.hashValue
    }
    
    public var description: String { return "WatchedFolder: '\(pathString)' \(uuid.uuidString)" }
}

