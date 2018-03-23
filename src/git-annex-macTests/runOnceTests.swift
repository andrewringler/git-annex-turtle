//
//  runOnceTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/22/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class runOnceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testRunNowOrAgain_2x() {
        var runs: Int32 = 0
        
        let runNowOrAgain = RunNowOrAgain({
            sleep(2)
            OSAtomicIncrement32(&runs)
        })
        
        runNowOrAgain.runTaskAgain()
        wait(for: 1)
        runNowOrAgain.runTaskAgain()
        
        wait(for: 6)
        XCTAssertEqual(runs, 2)
    }
    
    func testRunNowOrAgain_ignoresWhileRunning() {
        var runs: Int32 = 0
        
        let runNowOrAgain = RunNowOrAgain({
            sleep(3)
            OSAtomicIncrement32(&runs)
        })
        
        runNowOrAgain.runTaskAgain()
        runNowOrAgain.runTaskAgain()
        runNowOrAgain.runTaskAgain()
        wait(for: 1)
        runNowOrAgain.runTaskAgain()
        wait(for: 1)
        runNowOrAgain.runTaskAgain()
        
        wait(for: 10)
        XCTAssertEqual(runs, 2)
    }
}
