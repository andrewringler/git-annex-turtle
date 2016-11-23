//
//  main.swift
//  git-annex-mac-cmd
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import Foundation

//print("Hello, World!")

let finder = Finder()
if CommandLine.argc < 2 {
    finder.interactiveMode()
} else {
    finder.staticMode() 
}

