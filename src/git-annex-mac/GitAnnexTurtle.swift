//
//  GitAnnexTurtle.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 3/13/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

protocol GitAnnexTurtle {
    func updateMenubarData(with watchedFolders: Set<WatchedFolder>)

    func applicationDidFinishLaunching(_ aNotification: Notification)
    func applicationWillTerminate(_ aNotification: Notification)
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager?
}

class GitAnnexTurtleStub: GitAnnexTurtle {
    func applicationDidFinishLaunching(_ aNotification: Notification) {}
    func applicationWillTerminate(_ aNotification: Notification) {}
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return nil
    }
    
    func updateMenubarData(with watchedFolders: Set<WatchedFolder>) {}
}
