//
//  WatchedFolder.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Foundation

struct ShareSettings {
    let shareRemote: String?
    let shareLocalPath: String?
    
    public func isValid() -> Bool {
        if let r = shareRemote, let l = shareLocalPath {
            return !r.isEmpty && !l.isEmpty
        }
        return false
    }
    
    public var description: String { return "'\(String(describing: shareRemote))' '\(String(describing: shareLocalPath))'" }
}

class WatchedFolder: Equatable, Hashable, Comparable, CustomStringConvertible, Swift.Codable {
    public var handleStatusRequests: HandleStatusRequests? = nil
    public lazy var shortName: String = {
       return PathUtils.lastPathComponent(pathString)
    }()
    let uuid: UUID
    let pathString: String
    var shareRemote = ShareSettings(shareRemote: nil, shareLocalPath: nil)
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case pathString
    }
    
    init(uuid: UUID, pathString: String) {
        self.uuid = uuid
        self.pathString = pathString
    }
    
    static func pretty<T>(_ watchedFolders: T) -> String where T: Sequence, T.Iterator.Element : WatchedFolder {
        return  watchedFolders.map { "<\($0.pathString) \($0.uuid.uuidString) \(String(describing: $0.shareRemote))>" }.joined(separator: ",")
    }
    static func ==(lhs: WatchedFolder, rhs: WatchedFolder) -> Bool {
        return lhs.uuid == rhs.uuid && lhs.pathString == rhs.pathString
    }
    static func <(lhs: WatchedFolder, rhs: WatchedFolder) -> Bool {
        return lhs.pathString < rhs.pathString
    }
    var hashValue: Int {
        return uuid.hashValue
    }
    
    public var description: String { return "WatchedFolder: '\(pathString)' \(uuid.uuidString) '\(String(describing: shareRemote))'" }
}

struct ExportTreeRemote {
    let name: String
    let path: String
}

