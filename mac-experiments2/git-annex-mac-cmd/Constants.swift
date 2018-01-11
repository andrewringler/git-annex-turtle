//
//  Constants.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 1/11/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

let GitAnnexTurtleDbPrefix = "gitannex."
let GitAnnexTurtleWatchedFoldersDbPrefix = "gitannex.watched-folders"
func GitAnnexTurtleRequestBadgeDbPrefixNoPath(in watchedFolder: WatchedFolder) -> String {
    return "gitannex.requestbadge." + watchedFolder.uuid.uuidString + "."
}
func GitAnnexTurtleRequestBadgeDbPrefix(for path: String, in watchedFolder: WatchedFolder) -> String {
    return "gitannex.requestbadge." + watchedFolder.uuid.uuidString + "." + path
}
func GitAnnexTurtleStatusUpdatedDbPrefix(for path: String, in watchedFolder: WatchedFolder) -> String {
    return "gitannex.statusupdated." + watchedFolder.uuid.uuidString + "." + path
}
func GitAnnexTurtleStatusUpdatedDbPrefixNoPath(in watchedFolder: WatchedFolder) -> String {
    return "gitannex.statusupdated." + watchedFolder.uuid.uuidString + "."
}
func GitAnnexTurtleStatusDbPrefix(for path: String, in watchedFolder: WatchedFolder) -> String {
    return "gitannex.statussaved." + watchedFolder.uuid.uuidString + "." + path
}
func GitAnnexTurtleStatusDbPrefixNoPath(in watchedFolder: WatchedFolder) -> String {
    return "gitannex.statussaved." + watchedFolder.uuid.uuidString + "."
}

protocol Command {
    var cmdString :String { get }
    func dbPrefixWithUUID(for path: String, in watchedFolder: WatchedFolder) -> String
    func dbPrefixWithUUID(in watchedFolder: WatchedFolder) -> String
}
class GitAnnexCommand: Equatable, Hashable, Command {
    let cmdString :String
    private let dbPrefix :String
    
    init(cmdString :String, dbPrefix :String) {
        self.cmdString = cmdString
        self.dbPrefix = dbPrefix
    }
    
    static func ==(lhs: GitAnnexCommand, rhs: GitAnnexCommand) -> Bool {
        return lhs.cmdString == rhs.cmdString
    }
    var hashValue: Int {
        return cmdString.hashValue
    }
    
    func dbPrefixWithUUID(in watchedFolder: WatchedFolder) -> String {
        return dbPrefix + watchedFolder.uuid.uuidString + "."
    }
    func dbPrefixWithUUID(for path: String, in watchedFolder: WatchedFolder) -> String {
        return dbPrefix + watchedFolder.uuid.uuidString + "." + path
    }
}
struct GitAnnexCommands {
    static let Get = GitAnnexCommand(cmdString: "get", dbPrefix: "gitannex.command.git-annex-get.")
    static let Add = GitAnnexCommand(cmdString: "add", dbPrefix: "gitannex.command.git-annex-add.")
    static let Drop = GitAnnexCommand(cmdString: "drop", dbPrefix: "gitannex.command.git-annex-drop.")
    static let Unlock = GitAnnexCommand(cmdString: "unlock", dbPrefix: "gitannex.command.git-annex-unlock.")
    static let Lock = GitAnnexCommand(cmdString: "lock", dbPrefix: "gitannex.command.git-annex-lock.")
    
    static let all = [Get, Add, Drop, Unlock, Lock]
}
class GitCommand: Equatable, Hashable, Command {
    let cmdString :String
    private let dbPrefix :String
    
    init(cmdString :String, dbPrefix :String) {
        self.cmdString = cmdString
        self.dbPrefix = dbPrefix
    }
    static func ==(lhs: GitCommand, rhs: GitCommand) -> Bool {
        return lhs.cmdString == rhs.cmdString
    }
    var hashValue: Int {
        return cmdString.hashValue
    }
    
    func dbPrefixWithUUID(in watchedFolder: WatchedFolder) -> String {
        return dbPrefix + watchedFolder.uuid.uuidString + "."
    }
    func dbPrefixWithUUID(for path: String, in watchedFolder: WatchedFolder) -> String {
        return dbPrefix + watchedFolder.uuid.uuidString + "." + path
    }
}
struct GitCommands {
    static let Add = GitCommand(cmdString: "add", dbPrefix: "gitannex.command.git-add.")
    
    static let all = [Add]
}
struct GitConfig {
    let name :String
}
struct GitConfigs {
    static let AnnexUUID = GitConfig(name: "annex.uuid")
}
enum Status: String {
    case present = "present"
    case absent = "absent"
    case unknown = "unknown"
    case partiallyPresentDirectory = "partially-present-directory"
    
    static let all = [present,absent,unknown,partiallyPresentDirectory]
    static func status(from: String) -> Status {
        for status in all {
            if status.rawValue == from {
                return status
            }
        }
        return unknown
    }
    static func status(fromOptional: String?) -> Status? {
        if let fromExists = fromOptional {
            return status(from: fromExists)
        }
        return nil
    }
}
enum GitAnnexJSON: String {
    case success = "success"
    case present = "present"
    case directory = "directory"
    case file = "file"
    case localAnnexKeys = "local annex keys"
    case annexedFilesInWorkingTree = "annexed files in working tree"
    case command = "command"
    case note = "note"
}

class PathUtils {
    class func path(for url: URL) -> String? {
        return (url as NSURL).path
    }
    class func url(for stringPath: String) -> URL {
        //        return (NSURL(string: stringPath)! as URL).absoluteString)
        return URL(fileURLWithPath: stringPath)
    }
}
