//
//  WatchedFolder.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Foundation

class WatchedFolder: Equatable, Hashable, Swift.Codable {
    let uuid: UUID
    let pathString: String
    
    init(uuid: UUID, pathString: String) {
        self.uuid = uuid
        self.pathString = pathString
    }    
    static func ==(lhs: WatchedFolder, rhs: WatchedFolder) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    var hashValue: Int {
        return uuid.hashValue
    }
}

