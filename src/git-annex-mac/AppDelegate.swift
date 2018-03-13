//
//  AppDelegate.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    let gitAnnexTurtle = GitAnnexTurtle()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        gitAnnexTurtle.applicationDidFinishLaunching(aNotification)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        gitAnnexTurtle.applicationWillTerminate(aNotification)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return gitAnnexTurtle.applicationShouldTerminate(sender)
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return gitAnnexTurtle.windowWillReturnUndoManager(window: window)
    }
}
