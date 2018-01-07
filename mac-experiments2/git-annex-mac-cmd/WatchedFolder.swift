//
//  WatchedFolder.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class WatchedFolder: NSObject, NSCoding {
    let uuid: UUID
    let pathString: String
    
    init(uuid: UUID, pathString: String) {
        self.uuid = uuid
        self.pathString = pathString
    }
    static func == (lhs: WatchedFolder, rhs: WatchedFolder) -> Bool {
        return lhs.uuid.uuidString == rhs.uuid.uuidString
    }
    override public var hashValue: Int {
        return uuid.hashValue
    }
    override public func isEqual(_ object: Any?) -> Bool {
        if object != nil {
            if let other = object as? WatchedFolder {
                return other.uuid.uuidString == uuid.uuidString
            }
        }
        return false
    }

    // NSCoding required for runtime archiving with NSKeyedArchiver to send across UserDefaults
    required convenience init?(coder aDecoder: NSCoder) {
        guard let pathString = aDecoder.decodeObject(forKey: "pathstring") as? String,
            let uuidString = aDecoder.decodeObject(forKey: "uuidstring") as? String
            else { return nil }
        
        self.init(uuid: UUID(uuidString: uuidString)!, pathString: pathString)
    }
    func encode(with aCoder: NSCoder) {
        aCoder.encode(pathString as String, forKey: "pathstring")
        aCoder.encode(uuid.uuidString as String, forKey: "uuidstring")
    }
}
