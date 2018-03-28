//
//  pathUtilsTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class pathUtilsTests: XCTestCase {
    var testDir: String?
    var repo1: WatchedFolder?
    var gitAnnexQueries: GitAnnexQueries?
    
    override func setUp() {
        super.setUp()
        TurtleLog.setLoggingLevel(.debug)
        
        testDir = TestingUtil.createTmpDir()
        
        TurtleLog.info("Using testing dir: \(testDir!)")
        let config = Config(dataPath: "\(testDir!)/turtle-monitor")
        
        gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: config.gitAnnexBin()!, gitCmd: config.gitBin()!)
        repo1 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo1", gitAnnexQueries: gitAnnexQueries!)
    }
    
    override func tearDown() {
        gitAnnexQueries = nil
        TestingUtil.removeDir(testDir)
        super.tearDown()
    }
    
    func testPathExists() {
        XCTAssertFalse(PathUtils.pathExists(for: "nope.txt", in: repo1!))
        XCTAssertFalse(PathUtils.pathExists(for: "nope/nope", in: repo1!))
        XCTAssertFalse(PathUtils.pathExists(for: "nope/nope/stillNope.txt", in: repo1!))

        let normalFile = "normalFile.txt"
        TestingUtil.writeToFile(content: "some content", to: normalFile, in: repo1!)
        XCTAssertTrue(PathUtils.pathExists(for: normalFile, in: repo1!))

        let normalFolder = "aFolder"
        TestingUtil.createDir(dir: normalFolder, in: repo1!)
        XCTAssertTrue(PathUtils.pathExists(for: normalFolder, in: repo1!))

        let aFileInAFolder = "aFolder/AFileInAFolder.txt"
        TestingUtil.writeToFile(content: "some unique content o92rlkjsd93", to: aFileInAFolder, in: repo1!)
        XCTAssertTrue(PathUtils.pathExists(for: aFileInAFolder, in: repo1!))
        
        let symlinkToFile = "symlinkToFile.txt"
        XCTAssertTrue(TestingUtil.createSymlink(from: symlinkToFile, to: normalFile, in: repo1!))
        XCTAssertTrue(PathUtils.pathExists(for: symlinkToFile, in: repo1!))

        let symlinkToFileThatDoesNotExist = "symlinkToFileThatDoesNotExist.txt"
        XCTAssertTrue(TestingUtil.createSymlink(from: symlinkToFileThatDoesNotExist, to: "somePathThatDoesNotExist.txt", in: repo1!))
        XCTAssertTrue(PathUtils.pathExists(for: symlinkToFileThatDoesNotExist, in: repo1!))

        let anAnnexedPresentFile = "anAnnexedPresentFile.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "some unique file content sfdsd33qer", to: anAnnexedPresentFile, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        XCTAssertTrue(PathUtils.pathExists(for: anAnnexedPresentFile, in: repo1!))
        
        // TODO
        // Now test a not present file
        // by first adding, then dropping it
    }
}
