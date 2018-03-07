//
//  Finder.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

class Finder {
    let config = Config()
    let consoleIO = ConsoleIO()
    
    func staticMode() {
        let argCount = CommandLine.argc
        
        if argCount < 2 {
            ConsoleIO.printUsage()
        } else {
            let argument = CommandLine.arguments[1]
            let (option, value) = consoleIO.getOption(argument.substring(from: argument.characters.index(argument.startIndex, offsetBy: 1)))
            
            switch option {
            case .watch:
                if argCount != 3 {
                    if argCount > 3 {
                        consoleIO.writeMessage("Too many arguments for option \(option.rawValue)", to: .error)
                    } else {
                        consoleIO.writeMessage("too few arguments for option \(option.rawValue)", to: .error)
                    }
                    consoleIO.writeMessage("")
                    ConsoleIO.printUsage()
                } else {
                    let repo = CommandLine.arguments[2]
                    
                    if isGitAnnexRepository(repo: repo) {
                        config.watchRepo(repo: repo)
                        consoleIO.writeMessage("watching \(repo)")
                    } else {
                        consoleIO.writeMessage("\(repo) is not a git-annex repository")
                    }
                }
            case .unwatch:
                // TODO
                consoleIO.writeMessage("TODO")
            case .list:
                let repos = config.listWatchedRepos()
                print("watched repositories: ")
                for repo in repos {
                    print(repo)
                }
            case .help:
                ConsoleIO.printUsage()
            case .unknown, .quit:
                consoleIO.writeMessage("Unkonwn option \(value)", to: .error)
                consoleIO.writeMessage("")
                ConsoleIO.printUsage()
            }
        }
    }
    
    func isGitAnnexRepository(repo: String) -> Bool {
        // TODO
        return true
    }
}
