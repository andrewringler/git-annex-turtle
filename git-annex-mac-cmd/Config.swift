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
                print("Unable to create configuration file at \(dataPath)")
                exit(-1)
            }
        } else {
            configFile = dataPath
        }
    }
    
    convenience init() {
        // Create configuration file
        // at ~/.config/git-annex/turtle-monitor
        // to store list of git-annex directories to watch
        self.init(dataPath: "\(NSHomeDirectory())/.config/git-annex/turtle-monitor")
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
    
    func stopWatchingRepo(repo: String) {
        let currentRepos = listWatchedRepos().filter { $0 != repo } // remove repo
        let towrite = currentRepos.joined(separator: "\n")
        let os = OutputStream(toFileAtPath: self.configFile, append: false)!
        os.open()
        let success = os.write(towrite, maxLength: towrite.lengthOfBytes(using: .utf8))
        os.close()
        if success == -1 {
            print("Unable to remove repository '\(repo)' to configuration file at '\(configFile)'")
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
