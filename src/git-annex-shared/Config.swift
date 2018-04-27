//
//  Config.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

class Config {
    // Create configuration file
    // at ~/.config/git-annex/turtle-monitor
    // to store list of git-annex directories to watch
    public static let DEFAULT_DATA_PATH = "\(NSHomeDirectory())/.config/git-annex/turtle-monitor"
    let dataPath: String
    
    init(dataPath: String) {
        self.dataPath = dataPath
        
        if (!FileManager.default.fileExists(atPath: dataPath)) {
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
            return writeConfig(config.setGitBin(gitBin))
        }
        TurtleLog.error("setGitBin: unable to read config")
        return false
    }
    func setGitAnnexBin(gitAnnexBin: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.setGitAnnexBin(gitAnnexBin))
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
    
    func stopWatchingRepo(repo: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.removeRepo(repo))
        }
        TurtleLog.error("stopWatchingRepo: unable to read config")
        return false
    }
    
    func listWatchedRepos() -> [String] {
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
