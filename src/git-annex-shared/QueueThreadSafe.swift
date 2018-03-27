//
//  Queue.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/26/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

// https://www.raywenderlich.com/148141/swift-algorithm-club-swift-queue-data-structure
public class QueueThreadSafe<T> {
    private let threadLocks = DispatchQueue(label: "QueueThreadSafe-\(UUID().uuidString)", attributes: .concurrent)
    private var list = LinkedList<T>()

    public var isEmpty: Bool {
        return threadLocks.sync() {
            return list.isEmpty
        }
    }
    
    public func enqueue(_ element: T) {
        threadLocks.async(flags: .barrier) {
            self.list.append(element)
        }
    }

    public func dequeue() -> T? {
        return threadLocks.sync(flags: .barrier) {
            guard !list.isEmpty, let element = list.first else { return nil }
            return list.remove(element)
        }
    }
    
    public func peek() -> T? {
        return threadLocks.sync() {
            return list.first?.value
        }
    }
    
    public func toArray() -> [T] {
        return threadLocks.sync() {
            list.toArray()
        }
    }
}
