//
//  Finder.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

class Finder {
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
                    let dir = CommandLine.arguments[2]
                    
                    if dir.isGitAnnexRepository() {
                        consoleIO.writeMessage("\(dir) is a git-annex repository")
                    } else {
                        consoleIO.writeMessage("\(dir) is not a git-annex repository")
                    }
                }
            case .unwatch:
                // TODO
                consoleIO.writeMessage("TODO")
            case .list:
                // TODO
                consoleIO.writeMessage("TODO")
            case .help:
                ConsoleIO.printUsage()
            case .unknown, .quit:
                consoleIO.writeMessage("Unkonwn option \(value)", to: .error)
                consoleIO.writeMessage("")
                ConsoleIO.printUsage()
            }
        }
    }
}
