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
    var repo1: WatchedFolder?
    var queries: Queries?
    var gitAnnexQueries: GitAnnexQueries?
    
    override func setUp() {
        super.setUp()
        
        testDir = TestingUtil.createTmpDir()
        NSLog("Using testing dir: \(testDir!)")
        let config = Config(dataPath: "\(testDir!)/turtle-monitor")
        let storeURL = PathUtils.urlFor(absolutePath: "\(testDir!)/testingDatabase")
        
        let persistentContainer = TestingUtil.persistentContainer(mom: managedObjectModel, storeURL: storeURL)
        let data = DataEntrypoint(persistentContainer: persistentContainer)
        queries = Queries(data: data)
        gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: config.gitAnnexBin()!, gitCmd: config.gitBin()!)
        fullScan = FullScan(gitAnnexQueries: gitAnnexQueries!, queries: queries!)
        
        repo1 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo1", gitAnnexQueries: gitAnnexQueries!)
    }
    
    override func tearDown() {
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
    }

    func testFullScan() {
        let file1 = "a.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file2 = "b.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file2 content", to: file2, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file3 = "subdirA/c.txt"
        TestingUtil.createDir(dir: "subdirA", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file3 content", to: file3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        fullScan!.startFullScan(watchedFolder: repo1!)
        let done = NSPredicate(format: "doneScanning == true")
        expectation(for: done, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 30, handler: nil)
        
        if let status1 = queries!.statusForPathV2Blocking(path: file1, in: repo1!) {
            XCTAssertEqual(status1.presentStatus, Present.present)
        } else {
            XCTFail("could not retrieve status for \(file1)")
        }
        if let status2 = queries!.statusForPathV2Blocking(path: file2, in: repo1!) {
            XCTAssertEqual(status2.presentStatus, Present.present)
        } else {
            XCTFail("could not retrieve status for \(file2)")
        }
        if let status3 = queries!.statusForPathV2Blocking(path: file3, in: repo1!) {
            XCTAssertEqual(status3.presentStatus, Present.present)
        } else {
            XCTFail("could not retrieve status for \(file3)")
        }
        
        if let statusSubdirA = queries!.statusForPathV2Blocking(path: "subdirA", in: repo1!) {
            XCTAssertEqual(statusSubdirA.presentStatus, Present.present)
            XCTAssertEqual(statusSubdirA.isDir, true)
            XCTAssertEqual(statusSubdirA.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for 'subdirA'")
        }
        
        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
            XCTAssertEqual(wholeRepo.isDir, true)
            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for whole repo")
        }
    }
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))] )!
        return managedObjectModel
    }()
    
    func doneScanning() -> Bool {
        return fullScan!.isScanning(watchedFolder: repo1!) == false
    }
}
