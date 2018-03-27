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
        
        let uuid = UUID()
        repo1 = WatchedFolder(uuid: uuid, pathString: "/tmp/notarealpathrepo1-but-absolute-looking")
        queries!.updateWatchedFoldersBlocking(to: [repo1!])
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: PathUtils.CURRENT_DIR, key: nil, in: repo1!, isDir: true, needsUpdate: true)
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
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: file1, key: "some key", in: repo1!, isDir: false, needsUpdate: false)
        FolderTracking.handleFolderUpdates(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!)
        
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
        queries!.updateStatusForPathV2Blocking(presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 1, isGitAnnexTracked: true, for: file1, key: "some key", in: repo1!, isDir: false, needsUpdate: false)
        FolderTracking.handleFolderUpdatesFromFullScan(watchedFolder: repo1!, queries: queries!, gitAnnexQueries: gitAnnexQueries!, stopProcessingWatchedFolder: StopProcessingWatchedFolderNeverStop())
        
        if let status = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for root")
        }
    }
    
    // TODO, write test for BUG: FolderTracking is incorrectly assuming that every file in the db
    // needs to be up-to-date, this is not the case, since deleted files could potentially be up-to-date
    // and should actually be deleted from the database (too)
    
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
