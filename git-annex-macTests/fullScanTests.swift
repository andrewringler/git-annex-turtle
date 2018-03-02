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
    var repo2: WatchedFolder?
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
        repo2 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo2", gitAnnexQueries: gitAnnexQueries!)
    }
    
    override func tearDown() {
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
    }

    func testFullScan() {
        //
        // Repo 1
        //
        let file1 = "a.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file2 = "b.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file2 content", to: file2, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file3 = "subdirA/c.txt"
        TestingUtil.createDir(dir: "subdirA", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file3 content", to: file3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        //
        // Repo 2
        //
        let file4 = "a.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file4 content", to: file4, in: repo2!, gitAnnexQueries: gitAnnexQueries!)
        let file5 = "b.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file5 content", to: file5, in: repo2!, gitAnnexQueries: gitAnnexQueries!)
        
        // Start a full scan on both repos
        fullScan!.startFullScan(watchedFolder: repo1!)
        fullScan!.startFullScan(watchedFolder: repo2!)
        
        let done = NSPredicate(format: "doneScanning == true")
        expectation(for: done, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 30, handler: nil)

        // Repo 1
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
            XCTFail("could not retrieve folder status for whole repo1")
        }
        
        
        // Repo 2
        if let status4 = queries!.statusForPathV2Blocking(path: file4, in: repo2!) {
            XCTAssertEqual(status4.presentStatus, Present.present)
        } else {
            XCTFail("could not retrieve status for \(file4)")
        }
        if let status5 = queries!.statusForPathV2Blocking(path: file5, in: repo2!) {
            XCTAssertEqual(status5.presentStatus, Present.present)
        } else {
            XCTFail("could not retrieve status for \(file5)")
        }
        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo2!) {
            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
            XCTAssertEqual(wholeRepo.isDir, true)
            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for whole repo2")
        }
    }
    
    // 10 files     6.44 seconds
    // 100 files    46.75 seconds
    // 1000 files   509.81 seconds
    func testLargeRepoPerformance() {
        let numFiles = 1000
        for i in 1...numFiles {
            let file = "file-\(i).txt"
            TestingUtil.gitAnnexCreateAndAdd(content: "\(file) content", to: file, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        }
        
        let startTime = Date()
        fullScan!.startFullScan(watchedFolder: repo1!)
        
        let done = NSPredicate(format: "doneScanning == true")
        expectation(for: done, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 3000, handler: nil)
        NSLog("Full scan took \(Date().timeIntervalSince(startTime)) seconds.")
        
        // Repo 1
        for i in 1...numFiles {
            let file = "file-\(i).txt"
            if let status = queries!.statusForPathV2Blocking(path: file, in: repo1!) {
                XCTAssertEqual(status.presentStatus, Present.present)
            } else {
                XCTFail("could not retrieve status for \(file)")
            }
        }
        
        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
            XCTAssertEqual(wholeRepo.isDir, true)
            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for whole repo1")
        }
    }
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))] )!
        return managedObjectModel
    }()
    
    func doneScanning() -> Bool {
        return fullScan!.isScanning(watchedFolder: repo1!) == false
        && fullScan!.isScanning(watchedFolder: repo2!) == false
    }
}
