//
//  fullScanTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 2/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class fullScanTests: XCTestCase {
    var fullScan: FullScan?
    var testDir: String?
    
    override func setUp() {
        super.setUp()
        
        testDir = TestingUtil.createTmpDir()
        let config = Config(dataPath: "\(testDir!)/turtle-monitor")
        let storeURL = PathUtils.urlFor(absolutePath: "\(testDir!)/testingDatabase")
        let data = DataEntrypoint(storeURL: storeURL)
        let queries = Queries(data: data)
        let gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: config.gitAnnexBin()!, gitCmd: config.gitBin()!)
        fullScan = FullScan(gitAnnexQueries: gitAnnexQueries, queries: queries)
    }
    
    override func tearDown() {
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
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
    
    func testFullScan() {
        XCTAssertTrue(true)
    }

}
