//
//  git_annex_macTests.swift
//  git-annex-macTests
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import XCTest
@testable import git_annex_turtle

class git_annex_turtleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testWatchedFolder_equals_equal() {
        let uuidString = UUID().uuidString
        let a = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        let b = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        
        XCTAssertEqual(a, b)
    }
    
    func testWatchedFolder_equals_path_ignored() {
        let uuidString = UUID().uuidString
        let a = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        let b = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "b")
        
        XCTAssertEqual(a, b)
    }
    
    func testWatchedFolder_equals_not_equal_uuid() {
        let a = WatchedFolder(uuid: UUID(), pathString: "a")
        let b = WatchedFolder(uuid: UUID(), pathString: "a")
        
        XCTAssertNotEqual(a, b)
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
