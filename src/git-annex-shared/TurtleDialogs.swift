//
//  TurtleDialogs.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/14/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa
import Foundation

class TurtleDialogs: Dialogs {
    let gitAnnexLogoSquareColor = NSImage(named:NSImage.Name(rawValue: "git-annex-logo-square-color"))
    let gitAnnexTurtleLogo = NSImage(named:NSImage.Name(rawValue: "git-annex-logo"))

    func about() {
        // UI elements must always be on the main queue
        DispatchQueue.main.async {
            // https://stackoverflow.com/questions/29433487/create-an-nsalert-with-swift
            let alert = NSAlert()
            alert.messageText = "git-annex-turtle"
            alert.informativeText = """
            Version \(versionString)

            git-annex-turtle provides Apple Finder integration for git-annex on macOS, including custom badge icons, contextual menus and a Menubar icon. It is free, open-source and licensed under The MIT License.

            contains:
            Bitter font by Sol Matas, Huerta Tipográfica OFL

            uses:
            git-annex by Joey Hess GPLv3+,AGPLv3+,…
            git by Linus Torvalds GPLv2
            
            ©2017—2018 Andrew Ringler
            public@andrewringler.com
            https://github.com/andrewringler/git-annex-turtle
            """
            alert.alertStyle = .informational
            alert.icon = self.gitAnnexTurtleLogo
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func dialogOK(title: String, message: String) {
        // UI elements must always be on the main queue
        DispatchQueue.main.async {
            // https://stackoverflow.com/questions/29433487/create-an-nsalert-with-swift
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.icon = self.gitAnnexLogoSquareColor
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
