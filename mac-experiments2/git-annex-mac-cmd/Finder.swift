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
        //1
        let argCount = CommandLine.argc
        //2
        let argument = CommandLine.arguments[1]
        //3
        let (option, value) = consoleIO.getOption(argument.substring(from: argument.characters.index(argument.startIndex, offsetBy: 1)))
        //4
//        print("Argument count: \(argCount) Option: \(option) value: \(value)")
        //1
        switch option {
        case .anagram:
            if argCount != 4 {
                if argCount > 4 {
                    consoleIO.writeMessage("Too many arguments for option \(option.rawValue)", to: .error)
                } else {
                    consoleIO.writeMessage("too few arguments for option \(option.rawValue)", to: .error)
                }
                ConsoleIO.printUsage()
            } else {
                let first = CommandLine.arguments[2]
                let second = CommandLine.arguments[3]
                
                if first.isAnagramOfString(second) {
                    consoleIO.writeMessage("\(second) is an anagram of \(first)")
                } else {
                    consoleIO.writeMessage("\(second) is not an anagram of \(first)")
                }
            }
        case .palindrome:
            if argCount != 3 {
                if argCount > 3 {
                    consoleIO.writeMessage("Too many arguments for option \(option.rawValue)", to: .error)
                } else {
                    consoleIO.writeMessage("too few arguments for option \(option.rawValue)", to: .error)
                }
            } else {
                let s = CommandLine.arguments[2]
                let isPalindrome = s.isPalindrome()
                consoleIO.writeMessage("\(s) is \(isPalindrome ? "" : "not ")a palindrome")
            }
        case .help:
            ConsoleIO.printUsage()
        case .unknown, .quit:
            consoleIO.writeMessage("Unkonwn option \(value)", to: .error)
            ConsoleIO.printUsage()
        }
    }
    
    func interactiveMode() {
        //1
        consoleIO.writeMessage("Welcome to Panagram. This program checks if an input string is an anagram or palindrome.")
        //2
        var shouldQuit = false
        while !shouldQuit {
            //3
            consoleIO.writeMessage("Type 'a' to check for anagrams or 'p' for palindromes type 'q' to quit.")
            let (option, value) = consoleIO.getOption(consoleIO.getInput())
            
            switch option {
            case .anagram:
                //4
                consoleIO.writeMessage("Type the first string:")
                let first = consoleIO.getInput()
                consoleIO.writeMessage("Type the second string:")
                let second = consoleIO.getInput()
                
                //5
                if first.isAnagramOfString(second) {
                    consoleIO.writeMessage("\(second) is an anagram of \(first)")
                } else {
                    consoleIO.writeMessage("\(second) is not an anagram of \(first)")
                }
            case .palindrome:
                consoleIO.writeMessage("Type a word or sentence:")
                let s = consoleIO.getInput()
                let isPalindrome = s.isPalindrome()
                consoleIO.writeMessage("\(s) is \(isPalindrome ? "" : "not ")a palindrome")
            case .quit:
                shouldQuit = true
            default:
                //6
                consoleIO.writeMessage("Unknown option \(value)", to: .error)
            }
        }
    }
}
