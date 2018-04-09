//
//  RunMessagePortServices.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 4/8/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class RunMessagePortServices: StoppableService {
    let serviceThreadPing: DispatchQueue
    let serviceThreadCommandRequests: DispatchQueue
    let serviceThreadBadgeRequests: DispatchQueue
    
    // hold onto to references to our CFMessagePort servers here
    // so they aren't garbage collected within the thread
    var turtleServerPing: TurtleServerPing?
    var turtleServerCommandRequests: TurtleServerCommandRequests?
    var turtleServerBadgeRequests: TurtleServerBadgeRequests?

    init(gitAnnexTurtle: GitAnnexTurtle) {
        serviceThreadPing = DispatchQueue(label: "com.andrewringler.git-annex-mac.MessagePortPing")
        serviceThreadCommandRequests = DispatchQueue(label: "com.andrewringler.git-annex-mac.MessagePortCommandRequests")
        serviceThreadBadgeRequests = DispatchQueue(label: "com.andrewringler.git-annex-mac.MessagePortBadgeRequests")

        super.init()
        
        // Ping requests from Finder Sync extensions
        serviceThreadPing.async {
            // CFMessagePort expects a runloop, so give it one inside a custom GCD thread
            // this seems like a reasonable way to interop with these Object-C libraries from Swift
            // see https://stackoverflow.com/a/38001438/8671834 for more discussions
            self.turtleServerPing = TurtleServerPing(toRunLoop: CFRunLoopGetCurrent())
            CFRunLoopRun()
        }
        
        // Notify of new Badge Requests from Finder Sync extensions
        serviceThreadBadgeRequests.async {
            self.turtleServerBadgeRequests = TurtleServerBadgeRequests(toRunLoop: CFRunLoopGetCurrent(), gitAnnexTurtle: gitAnnexTurtle)
            CFRunLoopRun()
        }
        
        // Notify of new Command Requests from Finder Sync extensions
        serviceThreadCommandRequests.async {
            self.turtleServerCommandRequests = TurtleServerCommandRequests(toRunLoop: CFRunLoopGetCurrent(), gitAnnexTurtle: gitAnnexTurtle)
            CFRunLoopRun()
        }
    }
    
    public override func stop() {
        turtleServerPing?.invalidate()
        turtleServerCommandRequests?.invalidate()
        turtleServerBadgeRequests?.invalidate()
        turtleServerPing = nil
        turtleServerCommandRequests = nil
        turtleServerBadgeRequests = nil
        
        super.stop()
    }
}
