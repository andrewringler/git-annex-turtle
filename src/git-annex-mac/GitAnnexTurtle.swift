//
//  GitAnnexTurtle.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 3/13/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

protocol GitAnnexTurtleSwift {
    func updateMenubarData(with watchedFolders: Set<WatchedFolder>)
    
    func commandRequestsArePending()
    func badgeRequestsArePending()
    func visibleFolderUpdatesArePending()
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    func applicationWillTerminate(_ aNotification: Notification)
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager?
}
@objc protocol GitAnnexTurtleViewModel: class {
    func showPreferencesWindow(_ sender: Any?)
    func showAboutWindow(_ sender: Any?)
    func showInFinder(_ sender: NSMenuItem)
}
typealias GitAnnexTurtle = GitAnnexTurtleSwift & GitAnnexTurtleViewModel

// for testing
class GitAnnexTurtleStub: GitAnnexTurtle {
    var updateMenubarDataCalled: Int32 = 0
    var commandRequestsArePendingCalled: Int32 = 0
    var badgeRequestsArePendingCalled: Int32 = 0
    var visibleFolderUpdatesArePendingCalled: Int32 = 0

    func applicationDidFinishLaunching(_ aNotification: Notification) {}
    func applicationWillTerminate(_ aNotification: Notification) {}
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        return nil
    }
    
    func updateMenubarData(with watchedFolders: Set<WatchedFolder>) { OSAtomicIncrement32(&updateMenubarDataCalled) }
    func commandRequestsArePending() { OSAtomicIncrement32(&commandRequestsArePendingCalled) }
    func badgeRequestsArePending() { OSAtomicIncrement32(&badgeRequestsArePendingCalled) }
    func visibleFolderUpdatesArePending() { OSAtomicIncrement32(&visibleFolderUpdatesArePendingCalled) }
    
    @objc func showPreferencesWindow(_ sender: Any?) {}
    @objc func showAboutWindow(_ sender: Any?) {}
    @objc func showInFinder(_ sender: NSMenuItem) {}
}
