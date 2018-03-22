//
//  AppDelegate.swift
//  git-annex-mac
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//
import Cocoa
import Foundation

/* AppDelegate
 * here we use AppDelegate to fork between testing code and production code
 * this setup is necessary, because Apple really wants to launch your AppDelegate class
 * from tests on occassion.
 */
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var window: NSWindow!
    let gitAnnexTurtle: GitAnnexTurtle

    override init() {
        // Here we use the classloader to determine if we are running in a test
        // this is a not uncommon hack.
        let isRunningTests = NSClassFromString("XCTestCase") != nil
        if isRunningTests {
            gitAnnexTurtle = GitAnnexTurtleStub()
        } else {
            gitAnnexTurtle = GitAnnexTurtleProduction()
        }
        
        super.init()
    }
    
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
