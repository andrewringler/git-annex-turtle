//
//  queriesTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/15/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class queriesTests: XCTestCase {
    var testDir: String?
    var repo1 = WatchedFolder(uuid: UUID.init(), pathString: "/tmp/not a real path")
    var repo2 = WatchedFolder(uuid: UUID.init(), pathString: "/tmp/a different not a real path")
    var queries: Queries?
    
    override func setUp() {
        super.setUp()
        
        TurtleLog.setLoggingLevel(.debug)
        
        testDir = TestingUtil.createTmpDir()
        TurtleLog.info("Using testing dir: \(testDir!)")
        
        let databaseParentFolder  = "\(testDir!)/database"
        TestingUtil.createDir(absolutePath: databaseParentFolder)
        let storeURL = PathUtils.urlFor(absolutePath: "\(databaseParentFolder)/db")
        
        let persistentContainer = TestingUtil.persistentContainer(mom: managedObjectModel, storeURL: storeURL)
        let data = DataEntrypoint(persistentContainer: persistentContainer, absolutePath: databaseParentFolder)
        queries = Queries(data: data)
    }
    
    override func tearDown() {
        queries?.stop()
        queries = nil
        
        wait(for: 2) // wait for queries to finish
        TestingUtil.removeDir(testDir)

        super.tearDown()
    }
    
    func testAddAllMissingParentFolders() {
        //
        // should add 'a'
        //
        if let result = queries!.addAllMissingParentFolders(for: "a/b.txt", in: repo1) {
            XCTAssertEqual(result, ["a"])
        } else {
            XCTFail("could not addAllMissingParentFolders")
        }
        
        if let status = queries!.statusForPathV2Blocking(path: "a", in: repo1) {
            XCTAssertTrue(status.isDir)
            XCTAssertEqual(status.path, "a")
            XCTAssertEqual(status.parentPath, PathUtils.CURRENT_DIR) // parent is root
            XCTAssertTrue(status.needsUpdate)
            XCTAssertNil(status.enoughCopies)
            XCTAssertNil(status.numberOfCopies)
        } else {
            XCTFail("could not retrieve folder status for 'a'")
        }
        
        //
        // should do nothing
        //
        if let result = queries!.addAllMissingParentFolders(for: "a/b.txt", in: repo1) {
            XCTAssertEqual(result, [])
        } else {
            XCTFail("could not addAllMissingParentFolders")
        }
        if let result = queries!.addAllMissingParentFolders(for: "a", in: repo1) {
            XCTAssertEqual(result, [])
        } else {
            XCTFail("could not addAllMissingParentFolders")
        }

        
        //
        // should add 'a/c'
        //
        if let result = queries!.addAllMissingParentFolders(for: "a/c/b.png", in: repo1) {
            XCTAssertEqual(result, ["a/c"])
        } else {
            XCTFail("could not addAllMissingParentFolders")
        }
        
        if let status = queries!.statusForPathV2Blocking(path: "a/c", in: repo1) {
            XCTAssertTrue(status.isDir)
            XCTAssertEqual(status.path, "a/c")
            XCTAssertEqual(status.parentPath, "a") // a is root of, a/c
            XCTAssertTrue(status.needsUpdate)
            XCTAssertNil(status.enoughCopies)
            XCTAssertNil(status.numberOfCopies)
        } else {
            XCTFail("could not retrieve folder status")
        }
        

    }
        
        
        
        
//        if let dir = queries!.statusForPathV2Blocking(path: "anEmptyDirWithEmptyDirs", in: repo2!) {
//            XCTAssertEqual(dir.presentStatus, Present.present)
//            XCTAssertEqual(dir.isDir, true)
//            XCTAssertEqual(dir.enoughCopies, EnoughCopies.enough)
//        } else {
//            XCTFail("could not retrieve folder status for 'anEmptyDirWithEmptyDirs'")
//        }
//
//        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo2!) {
//            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
//            XCTAssertEqual(wholeRepo.isDir, true)
//            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.enough)
//            XCTAssertEqual(wholeRepo.numberOfCopies, 1)
//        } else {
//            XCTFail("could not retrieve folder status for whole repo2")
//        }
    
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))] )!
        return managedObjectModel
    }()
}

