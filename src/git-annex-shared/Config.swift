//
//  Config.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

struct WatchedRepoConfig {
    let path: String
    let shareRemote: String?
    let shareLocalPath: String?

    init(_ path: String, _ shareRemote: String?, _ shareLocalPath: String?) {
        self.path = path
        self.shareRemote = shareRemote
        self.shareLocalPath = shareLocalPath
    }
    
    lazy var description = "\(path) shareRemote: '\(String(describing: shareRemote))', shareLocalPath: '\(String(describing: shareLocalPath))'"
}
extension WatchedRepoConfig: Equatable, Hashable, Comparable {
    static func == (lhs: WatchedRepoConfig, rhs: WatchedRepoConfig) -> Bool {
        return lhs.path == rhs.path &&
            lhs.shareRemote == rhs.shareRemote
            && lhs.shareLocalPath == rhs.shareLocalPath
    }
    static func < (lhs: WatchedRepoConfig, rhs: WatchedRepoConfig) -> Bool {
        return lhs.path < rhs.path
    }
    var hashValue: Int {
        return path.hashValue
    }
}


class Config {
    // Create configuration file
    // at ~/.config/git-annex/turtle-monitor
    // to store list of git-annex directories to watch
    public static let DEFAULT_DATA_PATH = "\(NSHomeDirectory())/.config/git-annex/turtle-monitor"
    let dataPath: String
    
    init(dataPath: String) {
        self.dataPath = dataPath
        
        if (!FileManager.default.fileExists(atPath: dataPath)) {
            do {
                if let parentDir = PathUtils.parent(absolutePath: dataPath) {
                    try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
                } else {
                    TurtleLog.error("Unable to create configuration file parent folder for \(dataPath)")
                    exit(-1)
                }
            } catch {
                TurtleLog.error("Unable to create configuration file parent folder for \(dataPath)")
                exit(-1)
            }
            let success = FileManager.default.createFile(atPath: dataPath, contents: Data.init())
            if success == false {
                TurtleLog.error("Unable to create configuration file at \(dataPath)")
                exit(-1)
            }
        }
        
        setupPaths()
    }
    
    fileprivate func setupPaths() {
        var gitAnnexBin = self.gitAnnexBin()

        if gitAnnexBin == nil {
            if let workingDirectory = PathUtils.parent(absolutePath: dataPath), let newGitAnnexBin = FindBinaries.gitAnnexBinAbsolutePath(workingDirectory: workingDirectory) {
                _ = setGitAnnexBin(gitAnnexBin: newGitAnnexBin)
                gitAnnexBin = newGitAnnexBin
            }
        }
        if self.gitBin() == nil {
            if let workingDirectory = PathUtils.parent(absolutePath: dataPath), let newGitBin = FindBinaries.gitBinAbsolutePath(workingDirectory: workingDirectory, gitAnnexPath: gitAnnexBin) {
                _ = setGitBin(gitBin: newGitBin)
            }
        }
    }
    
    func setGitBin(gitBin: String) -> Bool {
        if let config = readConfig() {
            if let workingDirectory = PathUtils.parent(absolutePath: dataPath), FindBinaries.validGit(workingDirectory: workingDirectory, gitAbsolutePath: gitBin) {
                return writeConfig(config.setGitBin(gitBin))
            }
            TurtleLog.debug("not setting git bin, invalid binary at \(gitBin)")
        }
        TurtleLog.error("setGitBin: unable to read config")
        return false
    }
    func setGitAnnexBin(gitAnnexBin: String) -> Bool {
        if let config = readConfig() {
            if let workingDirectory = PathUtils.parent(absolutePath: dataPath), FindBinaries.validGitAnnex(workingDirectory: workingDirectory, gitAnnexAbsolutePath: gitAnnexBin) {
                return writeConfig(config.setGitAnnexBin(gitAnnexBin))
            }
        }
        TurtleLog.error("setGitAnnexBin: unable to read config")
        return false
    }
    func gitBin() -> String? {
        return readConfig()?.gitBin
    }
    func gitAnnexBin() -> String? {
        return readConfig()?.gitAnnexBin
    }

    func watchRepo(repo: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.addRepo(repo))
        }
        TurtleLog.error("watchRepo: unable to read config")
        return false
    }
    
    func updateShareRemoteLocalPath(repo: String, shareLocalPath: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.setShareRemoteLocalPath(repo, shareLocalPath))
        }
        TurtleLog.error("updateShareRemoteLocalPath: unable to read config")
        return false
    }
    func updateShareRemote(repo: String, shareRemote: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.setShareRemote(repo, shareRemote))
        }
        TurtleLog.error("updateShareRemote: unable to read config")
        return false
    }
    
    func stopWatchingRepo(repo: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.removeRepo(repo))
        }
        TurtleLog.error("stopWatchingRepo: unable to read config")
        return false
    }
    
    func listWatchedRepos() -> [WatchedRepoConfig] {
        if let config = readConfig() {
            return config.repoPaths()
        }
        
        TurtleLog.error("Unable to list watched repos from config file at \(dataPath)")
        return []
    }
    
    fileprivate func readConfig() -> TurtleConfigV1? {
        do {
            let data = try String(contentsOfFile: dataPath, encoding: .utf8)
            if let config = TurtleConfigV1.parse(from: data.components(separatedBy: .newlines)) {
                return config
            }
        } catch {
            TurtleLog.error("Unable to read config at \(dataPath) \(error)")
            return nil
        }
        TurtleLog.error("Unable to read config at \(dataPath)")
        return nil
    }
    
    fileprivate func writeConfig(_ newConfig: TurtleConfigV1) -> Bool {
        let towrite = newConfig.toFileString()
        let os = OutputStream(toFileAtPath: dataPath, append: false)!
        os.open()
        let success = os.write(towrite, maxLength: towrite.lengthOfBytes(using: .utf8))
        os.close()
        if success == -1 {
            TurtleLog.error("writeConfig: unable to write new config=\(self) to '\(dataPath)'")
            TurtleLog.error(os.streamError!.localizedDescription)
            return false
        }
        return true
    }
}
