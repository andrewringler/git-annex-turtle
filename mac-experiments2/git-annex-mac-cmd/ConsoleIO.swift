//
//  ConsoleIO.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/23/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

enum OutputType {
    case error
    case standard
}

enum OptionType: String {
    case watch = "w"
    case unwatch = "u"
    case list = "l"
    case help = "h"
    case quit = "q"
    case unknown
    
    init(value: String) {
        switch value {
        case "w": self = .watch
        case "u": self = .unwatch
        case "l": self = .list
        case "h": self = .help
        case "q": self = .quit
        default: self = .unknown
        }
    }
}

class ConsoleIO {
    class func printUsage() {
        let executableName = (CommandLine.arguments[0] as NSString).lastPathComponent
        
        print("Usage: \(executableName) COMMAND")
        print("")
        print("Commands:")
        print("")
        print("-w <path>        watch:   start watching a git-annex repository at path")
        print("-u <path>        unwatch: stop watching a git-annex repository at path")
        print("-l               list: list watched repositories")
        print("-h               show usage information")
    }
    
    func getOption(_ option: String) -> (option:OptionType, value: String) {
        return (OptionType(value: option), option)
    }
    
    func writeMessage(_ message: String, to: OutputType = .standard) {
        switch to {
        case .standard:
//            print("\u{001B}[;m\(message)")
            print("\(message)")
        case .error:
//            fputs("\u{001B}[0;31m\(message)\n", stderr)
//            print("\u{001B}[;m\(message)")
            print("\(message)")
        }
    }
}
