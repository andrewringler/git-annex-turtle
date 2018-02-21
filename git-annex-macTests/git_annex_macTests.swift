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
    
    func testEnoughCopiesAndEnoughEnough() {
        XCTAssertEqual(EnoughCopies.enough && EnoughCopies.enough, EnoughCopies.enough)
    }
    func testEnoughCopiesAndEnoughLacking() {
        XCTAssertEqual(EnoughCopies.enough && EnoughCopies.lacking, EnoughCopies.lacking)
    }
    func testEnoughCopiesAndLackingEnough() {
        XCTAssertEqual(EnoughCopies.lacking && EnoughCopies.enough, EnoughCopies.lacking)
    }
    func testEnoughCopiesAndLackingLacking() {
        XCTAssertEqual(EnoughCopies.lacking && EnoughCopies.lacking, EnoughCopies.lacking)
    }
    
    func testPresentAndPresentPresent() {
        XCTAssertEqual(Present.present && Present.present, Present.present)
    }
    func testPresentAndPresentAbsent() {
        XCTAssertEqual(Present.present && Present.absent, Present.partialPresent)
    }
    func testPresentAndAbsentPresent() {
        XCTAssertEqual(Present.absent && Present.present, Present.partialPresent)
    }
    func testPresentAndAbsentAbsent() {
        XCTAssertEqual(Present.absent && Present.absent, Present.absent)
    }
    func testPresentAndPresentPartialPresent() {
        XCTAssertEqual(Present.present && Present.partialPresent, Present.partialPresent)
    }
    func testPresentAndPartialPresentPresent() {
        XCTAssertEqual(Present.partialPresent && Present.present, Present.partialPresent)
    }
    func testPresentAndPartialPresentPartialPresent() {
        XCTAssertEqual(Present.partialPresent && Present.partialPresent, Present.partialPresent)
    }
    func testPresentAndPartialPresentAbsent() {
        XCTAssertEqual(Present.partialPresent && Present.absent, Present.partialPresent)
    }
    func testPresentAndAbsentPartialPresent() {
        XCTAssertEqual(Present.absent && Present.partialPresent, Present.partialPresent)
    }
    func testPresentAndChainPartialPresent() {
        XCTAssertEqual(Present.absent && Present.absent && Present.present && Present.partialPresent,
                       Present.partialPresent)
    }
    func testPresentAndChainPresent() {
        XCTAssertEqual(Present.present && Present.present && Present.present && Present.present,
                       Present.present)
    }
    func testPresentAndChainAbsent() {
        XCTAssertEqual(Present.absent && Present.absent && Present.absent && Present.absent,
                       Present.absent)
    }
    
    func testPathUtilsParentNilCurrent() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertNil(PathUtils.parent(for: PathUtils.CURRENT_DIR, in: a))
    }
    func testPathUtilsParentB() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertEqual(PathUtils.parent(for: "b", in: a), PathUtils.CURRENT_DIR)
    }
    func testPathUtilsParentBC() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertEqual(PathUtils.parent(for: "b/c", in: a), "b")
    }
    func testPathUtilsParentBCDPng() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertEqual(PathUtils.parent(for: "b/c/d.png", in: a), "b/c")
    }

    func testGitAnnexBinAbsolutePath() {
        XCTAssertEqual(GitAnnexQueries.gitAnnexBinAbsolutePath(), "/Applications/git-annex.app/Contents/MacOS/git-annex")
    }
    func testGitBinAbsolutePath() {
        XCTAssertEqual(GitAnnexQueries.gitBinAbsolutePath(), "/Applications/git-annex.app/Contents/MacOS/git")
    }
}
