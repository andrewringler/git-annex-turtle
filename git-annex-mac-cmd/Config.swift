//
//  Config.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

class Config {
    var configFile: String
    let dataPath: String
    
    init(dataPath: String) {
        self.dataPath = dataPath
        
        if (!FileManager.default.fileExists(atPath: dataPath)) {
            let success = FileManager.default.createFile(atPath: dataPath, contents: Data.init())
            if success {
                configFile = dataPath
            } else {
                NSLog("Unable to create configuration file at \(dataPath)")
                exit(-1)
            }
        } else {
            configFile = dataPath
        }
        
        setupPaths()
    }
    
    convenience init() {
        // Create configuration file
        // at ~/.config/git-annex/turtle-monitor
        // to store list of git-annex directories to watch
        self.init(dataPath: "\(NSHomeDirectory())/.config/git-annex/turtle-monitor")
    }
    
    fileprivate func setupPaths() {
        let gitBin = self.gitBin()
        let gitAnnexBin = self.gitAnnexBin()

        if gitBin == nil {
            if let newGitBin = GitAnnexQueries.gitBinAbsolutePath() {
                _ = setGitBin(gitBin: newGitBin)
            }
        }
        if gitAnnexBin == nil {
            if let newGitAnnexBin = GitAnnexQueries.gitAnnexBinAbsolutePath() {
                _ = setGitAnnexBin(gitAnnexBin: newGitAnnexBin)
            }
        }
    }
    
    func setGitBin(gitBin: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.setGitBin(gitBin))
        }
        NSLog("setGitBin: unable to read config")
        return false
    }
    func setGitAnnexBin(gitAnnexBin: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.setGitAnnexBin(gitAnnexBin))
        }
        NSLog("setGitAnnexBin: unable to read config")
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
        NSLog("watchRepo: unable to read config")
        return false
    }
    
    func stopWatchingRepo(repo: String) -> Bool {
        if let config = readConfig() {
            return writeConfig(config.removeRepo(repo))
        }
        NSLog("stopWatchingRepo: unable to read config")
        return false
    }
    
    func listWatchedRepos() -> [String] {
        if let config = readConfig() {
            return config.repoPaths()
        }
        
        NSLog("Unable to list watched repos from config file at \(configFile)")
        return []
    }
    
    fileprivate func readConfig() -> TurtleConfigV1? {
        do {
            let data = try String(contentsOfFile: configFile, encoding: .utf8)
            if let config = TurtleConfigV1.parse(from: data.components(separatedBy: .newlines)) {
                return config
            }
        } catch {
            NSLog("Unable to read config at \(configFile) \(error)")
            return nil
        }
        NSLog("Unable to read config at \(configFile)")
        return nil
    }
    
    fileprivate func writeConfig(_ newConfig: TurtleConfigV1) -> Bool {
        let towrite = newConfig.toFileString()
        let os = OutputStream(toFileAtPath: self.configFile, append: false)!
        os.open()
        let success = os.write(towrite, maxLength: towrite.lengthOfBytes(using: .utf8))
        os.close()
        if success == -1 {
            NSLog("writeConfig: unable to write new config=\(self) to '\(configFile)'")
            NSLog(os.streamError!.localizedDescription)
            return false
        }
        return true
    }
}
