//
//  Running.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/24/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

// apparently read/set Bool is not only not atomic in Swift
// but the compiler will optimize out the read checks
// so we need to wrap our bool, running check in a class with NSLock
// https://stackoverflow.com/a/41833015/8671834
class Running {
    private var lock = NSLock()
    private var running = true
    
    public func stop() {
        lock.lock()
        running = false
        lock.unlock()
    }
    
    public func isRunning() -> Bool {
        var stillRunning = true
        lock.lock()
        stillRunning = running
        lock.unlock()
        return stillRunning
    }
}

class StoppableService {
    lazy var running = {
        return Running()
    }()
    
    public func stop() {
        running.stop()
    }
    
    deinit {
        stop()
    }
}
