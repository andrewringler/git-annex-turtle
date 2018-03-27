//
//  folderTrackingTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation
import XCTest

class folderTrackingTests: XCTestCase {
    var testDir: String?
    var queries: Queries?
    var gitAnnexQueries: GitAnnexQueries?
    var repo1: WatchedFolder?

    override func setUp() {
        super.setUp()
        TurtleLog.setLoggingLevel(.debug)
        
        testDir = TestingUtil.createTmpDir()
        
        TurtleLog.info("Using testing dir: \(testDir!)")
        let config = Config(dataPath: "\(testDir!)/turtle-monitor")
        
        let databaseParentFolder  = "\(testDir!)/database"
        TestingUtil.createDir(absolutePath: databaseParentFolder)
        let storeURL = PathUtils.urlFor(absolutePath: "\(databaseParentFolder)/db")
        let persistentContainer = TestingUtil.persistentContainer(mom: managedObjectModel, storeURL: storeURL)
        let data = DataEntrypoint(persistentContainer: persistentContainer, absolutePath: databaseParentFolder)
        queries = Queries(data: data)
        gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: config.gitAnnexBin()!, gitCmd: config.gitBin()!)
        
        repo1 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo1", gitAnnexQueries: gitAnnexQueries!)
        
        queries!.updateWatchedFoldersBlocking(to: [repo1!])
        queries!.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: PathUtils.CURRENT_DIR, key: nil, in: repo1!, isDir: true, needsUpdate: true)
    }
    
    override func tearDown() {
        queries?.stop()
        queries = nil
        gitAnnexQueries = nil
        
        wait(for: 1)
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
    }
    
    func testHandleFolderUpdates_up_to_date() {
        let file1 = "a name with spaces.log"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: file1, key: "some key", in: repo1!, isDir: false, needsUpdate: false)
        XCTAssertTrue(FolderTracking.handleFolderUpdates(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
    func testHandleFolderUpdates_not_up_to_date() {
        let file1 = "a name with spaces.log"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        queries!.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: file1, key: nil, in: repo1!, isDir: false, needsUpdate: true)
        XCTAssertTrue(FolderTracking.handleFolderUpdates(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, nil)
            XCTAssertEqual(status.enoughCopies, nil)
            XCTAssertEqual(status.numberOfCopies, nil)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
    func testHandleFolderUpdates_up_to_date_aDeletedFile_DoesNotNeedToBeUpToDate() {
        let file1 = "a name with spaces.log"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: file1, key: "some key", in: repo1!, isDir: false, needsUpdate: false)
        
        let aDeletedFile = "not present deleted file.txt"
        queries!.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: aDeletedFile, key: nil, in: repo1!, isDir: false, needsUpdate: true)
        
        XCTAssertTrue(FolderTracking.handleFolderUpdates(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
    
    func testHandleFolderUpdatesFromFullScan_up_to_date() {
        let file1 = "a name with spaces.log"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: file1, key: "some key", in: repo1!, isDir: false, needsUpdate: false)
        XCTAssertTrue(FolderTracking.handleFolderUpdatesFromFullScan(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!, stopProcessingWatchedFolder: StopProcessingWatchedFolderNeverStop()))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
    
    /* here we are simulating the case in which a file was deleted during a full scan
     * but after the full scan had enumerated it, in this case the fullscan method will return incomplete
     * but the more rigorous scan during our incremental scan will pick up the change */
    func testHandleFolderUpdatesFromFullScan_up_to_date_aDeletedFile_MeansUpdateLater() {
        let file1 = "a name with spaces.log"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: file1, key: "some key", in: repo1!, isDir: false, needsUpdate: false)
        
        let aDeletedFile = "not present deleted file.txt"
        queries!.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: aDeletedFile, key: nil, in: repo1!, isDir: false, needsUpdate: true)
        
        XCTAssertTrue(FolderTracking.handleFolderUpdatesFromFullScan(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!, stopProcessingWatchedFolder: StopProcessingWatchedFolderNeverStop()))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, nil)
            XCTAssertEqual(status.enoughCopies, nil)
            XCTAssertEqual(status.numberOfCopies, nil)
        } else {
            XCTFail("could not retrieve status for root")
        }
        
        XCTAssertTrue(FolderTracking.handleFolderUpdates(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
    func testHandleFolderUpdatesFromFullScan_not_up_to_date() {
        let file1 = "a name with spaces.log"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        queries!.updateStatusForPathV2Blocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: file1, key: nil, in: repo1!, isDir: false, needsUpdate: true)
        XCTAssertTrue(FolderTracking.handleFolderUpdatesFromFullScan(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!, stopProcessingWatchedFolder: StopProcessingWatchedFolderNeverStop()))
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, nil)
            XCTAssertEqual(status.enoughCopies, nil)
            XCTAssertEqual(status.numberOfCopies, nil)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
        
    lazy var managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))] )!
        return managedObjectModel
    }()
}

class StopProcessingWatchedFolderNeverStop: StopProcessingWatchedFolder {
    func shouldStop(_ watchedFolder: WatchedFolder) -> Bool {
        return false
    }
}
