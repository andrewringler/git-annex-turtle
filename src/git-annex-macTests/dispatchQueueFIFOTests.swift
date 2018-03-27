//
//  dispatchQueueFIFOTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/26/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class dispatchQueueFIFOTests: XCTestCase {
    func test_in_order_max1thread() {
        let q = DispatchQueueFIFO(maxConcurrentThreads: 1)
        let result = QueueThreadSafe<Int>()
        for i in 1...5 {
            q.submitTask {
               result.enqueue(i)
            }
        }
        wait(for: 1)
        
        XCTAssertEqual(result.toArray(), [1, 2, 3, 4, 5])
    }
    func test_anyOrder_max5thread_2() {
        let q = DispatchQueueFIFO(maxConcurrentThreads: 5)
        let result = QueueThreadSafe<Int>()
        for i in 1...5 {
            q.submitTask {
                result.enqueue(i)
            }
        }
        wait(for: 1)
        
        XCTAssertEqual(Set(result.toArray()), Set([1, 2, 3, 4, 5]))
    }
    func test_handlingRequests_false() {
        let q = DispatchQueueFIFO(maxConcurrentThreads: 5)
        let result = QueueThreadSafe<Int>()
        for i in 1...5 {
            q.submitTask {
                result.enqueue(i)
            }
        }
        wait(for: 1)
        
        XCTAssertFalse(q.handlingRequests())
    }
    func test_handlingRequests_true() {
        let q = DispatchQueueFIFO(maxConcurrentThreads: 5)
        let result = QueueThreadSafe<Int>()
        for i in 1...5 {
            q.submitTask {
                sleep(1)
                result.enqueue(i)
            }
        }
        XCTAssertTrue(q.handlingRequests())
        wait(for: 2)
        XCTAssertFalse(q.handlingRequests())
    }
    func test_handlingRequests_true_maxThread1() {
        let q = DispatchQueueFIFO(maxConcurrentThreads: 1)
        let result = QueueThreadSafe<Int>()
        for i in 1...5 {
            q.submitTask {
                sleep(1)
                result.enqueue(i)
            }
        }
        XCTAssertTrue(q.handlingRequests())
        wait(for: 6)
        XCTAssertFalse(q.handlingRequests())
    }
}
