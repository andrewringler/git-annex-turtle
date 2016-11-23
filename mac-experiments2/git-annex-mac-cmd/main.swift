//
//  main.swift
//  git-annex-mac-cmd
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

//print("Hello, World!")

var error: NSError?

// Create configuration file
// at ~/.config/git-annex/turtle-watch
// to store list of git-annex directories to watch
let dataPath = "\(NSHomeDirectory())/.config/git-annex/turtle-watch"
if (!FileManager.default.fileExists(atPath: dataPath)) {
    var success = FileManager.default.createFile(atPath: dataPath, contents: Data.init())
}

let finder = Finder()
if CommandLine.argc < 2 {
    finder.interactiveMode()
} else {
    finder.staticMode()
}

