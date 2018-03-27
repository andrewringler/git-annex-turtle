//
//  PriorityQueue.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/26/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class DispatchQueueFIFO: StoppableService {
    private let limitConcurrentThreadsSemaphore: DispatchSemaphore
    private let workQueue: DispatchQueue
    private var taskLoader: RunNowOrAgain?
    private var waitingTasks = QueueThreadSafe<(() -> Void)>()
    private (set) var executingTaskCount : Int32 = 0
    
    init(maxConcurrentThreads: Int) {
        guard maxConcurrentThreads > 0 else { fatalError("maxConcurrentThreads must be 1 or greater, but received \(maxConcurrentThreads)") }
        
        workQueue = DispatchQueue(label: "com.andrewringler.git-annex-mac.PriorityQueue-\(UUID().uuidString)", attributes: .concurrent)
        limitConcurrentThreadsSemaphore = DispatchSemaphore(value: maxConcurrentThreads)
        
        super.init()
        taskLoader = RunNowOrAgain({self.loadTasks()})
    }
    
    public func submitTask(_ task: @escaping (() -> Void)) {
        waitingTasks.enqueue(task)
        
        // let our task loader know there is potentially another task to run
        taskLoader!.runTaskAgain()
    }
    
    public func handlingRequests() -> Bool {
        return !waitingTasks.isEmpty || executingTaskCount > 0
    }
    
    private func loadTasks() {
        while let task = waitingTasks.dequeue() {
            guard running.isRunning() else { return }
            limitConcurrentThreadsSemaphore.wait()
            OSAtomicIncrement32(&executingTaskCount)
            workQueue.async {
                task()
                // we'll just implement our own completion block, here
                // since notify() and DispatchWorkItem seem questionable
                // see: https://stackoverflow.com/a/43131159/8671834
                OSAtomicDecrement32(&self.executingTaskCount)
                self.limitConcurrentThreadsSemaphore.signal()
            }
        }
    }
}
