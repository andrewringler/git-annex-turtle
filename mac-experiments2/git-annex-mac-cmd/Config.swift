//
//  Config.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
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

struct GitAnnexCommand {
    let cmdString :String, dbPrefix :String
    
    func dbPrefixWithUUID(for watchedFolder: WatchedFolder) -> String {
        return dbPrefix + "." + watchedFolder.uuid.uuidString + "."
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
struct GitCommand {
    let cmdString :String, dbPrefix :String
    
    func dbPrefixWithUUID(for watchedFolder: WatchedFolder) -> String {
        return dbPrefix + "." + watchedFolder.uuid.uuidString + "."
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

class PathUtils {
    class func path(for url: URL) -> String? {
        return (url as NSURL).path
    }
    class func url(for stringPath: String) -> URL {
//        return (NSURL(string: stringPath)! as URL).absoluteString)
        return URL(fileURLWithPath: stringPath)
    }
}

class Config {
    var configFile: String
    
    init() {
        // Create configuration file
        // at ~/.config/git-annex/turtle-watch
        // to store list of git-annex directories to watch
        let dataPath = "\(NSHomeDirectory())/.config/git-annex/turtle-watch"
        if (!FileManager.default.fileExists(atPath: dataPath)) {
            let success = FileManager.default.createFile(atPath: dataPath, contents: Data.init())
            if success {
                configFile = dataPath
            } else {
                print("Unable to create configuration file at \(dataPath)")
                exit(-1)
            }
        } else {
            configFile = dataPath
        }
    }
    
    func watchRepo(repo: String) {
        var currentRepos = listWatchedRepos()
        currentRepos.append(repo)
        let towrite = currentRepos.joined(separator: "\n")
        let os = OutputStream(toFileAtPath: self.configFile, append: false)!
        os.open()
        let success = os.write(towrite, maxLength: towrite.lengthOfBytes(using: .utf8))
        os.close()
        if success == -1 {
            print("Unable to add repository to configuration file at \(configFile)")
            print(os.streamError!.localizedDescription)
            exit(-1)
        }
    }
    
    func listWatchedRepos() -> [String] {
        do {
            let data = try String(contentsOfFile: configFile, encoding: .utf8)
            var repos = data.components(separatedBy: .newlines)
            repos = repos.filter { $0.count > 0 } // remove empty strings
            return repos
        } catch {
            print("Unable to list watched repos from config file at \(configFile)")
            print(error)
            exit(-1)
        }
    }
}
