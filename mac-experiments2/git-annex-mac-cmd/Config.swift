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
    
    init() {
        // Create configuration file
        // at ~/.config/git-annex/turtle-watch
        // to store list of git-annex directories to watch
        // http://stackoverflow.com/questions/29695496/create-folder-in-home-directory
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
        
        //        let towrite = "\r\n\(repo)"
        //        let os = OutputStream(toFileAtPath: self.configFile, append: true)!
        //        os.open()
        //        let success = os.write(towrite, maxLength: towrite.lengthOfBytes(using: .utf8))
        //        os.close()
        //        if success == -1 {
        //            print("Unable to add repository to configuration file at \(configFile)")
        //            print(os.streamError!.localizedDescription)
        //            exit(-1)
        //        }
    }
    
    func listWatchedRepos() -> [String] {
        // http://stackoverflow.com/questions/31778700/read-a-text-file-line-by-line-in-swift
        do {
            let data = try String(contentsOfFile: configFile, encoding: .utf8)
            let repos = data.components(separatedBy: .newlines)
            return repos
        } catch {
            print("Unable to list watched repos from config file at \(configFile)")
            print(error)
            exit(-1)
        }
    }
}
