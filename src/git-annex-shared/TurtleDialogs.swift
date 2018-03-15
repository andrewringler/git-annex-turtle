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
