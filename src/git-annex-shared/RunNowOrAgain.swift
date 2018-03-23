//
//  RunNowOrAgain.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/22/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

/* Runs a task asynchronously
 * never more than once simultaneously
 * and repeats the tasks once it is done
 * as long as new requests come in
 */
class RunNowOrAgain {
    private var lock = NSLock()
    private var runningNow: Bool = false
    private var runAgain: Bool = false
    private let task: (() -> Void)
    
    init(_ task: @escaping (() -> Void)) {
        self.task = task
    }
    
    public func runTaskAgain() {
        lock.lock()
        if runningNow {
            // we are already running
            // just enqueue to happen again
            runAgain = true
        } else {
            // not currently running
            // lets run it
            runningNow = true
            DispatchQueue.global(qos: .background).async {
                self.runIt()
            }
        }
        lock.unlock()
    }
    
    private func runIt() {
        repeat {
            lock.lock()
            runAgain = false
            lock.unlock()
            
            task()
            
            lock.lock()
            runningNow = false
            lock.unlock()
        } while ({ () in
            var shouldRepeat = false
            lock.lock()
            shouldRepeat = runAgain
            lock.unlock()
            return shouldRepeat
            }())
    }
}

class RunNowOrAgain1<T> {
    private var lock = NSLock()
    private var runningNow: Bool = false
    private var runAgain: Bool = false
    private let task: ((T) -> Void)
    
    init(_ task: @escaping ((T) -> Void)) {
        self.task = task
    }
    
    public func runTaskAgain(p1: T) {
        lock.lock()
        if runningNow {
            // we are already running
            // just enqueue to happen again
            runAgain = true
        } else {
            // not currently running
            // lets run it
            runningNow = true
            DispatchQueue.global(qos: .background).async {
                self.runIt(p1: p1)
            }
        }
        lock.unlock()
    }
    
    private func runIt(p1: T) {
        repeat {
            lock.lock()
            runAgain = false
            lock.unlock()
            
            task(p1)
            
            lock.lock()
            runningNow = false
            lock.unlock()
        } while ({ () in
            var shouldRepeat = false
            lock.lock()
            shouldRepeat = runAgain
            lock.unlock()
            return shouldRepeat
            }())
    }
}
