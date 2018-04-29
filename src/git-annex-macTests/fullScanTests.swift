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
        
        TurtleLog.setLoggingLevel(.debug)
        
        testDir = TestingUtil.createTmpDir()
        TurtleLog.info("Using testing dir: \(testDir!)")
        let config = Config(dataPath: "\(testDir!)/turtle-monitor")
        let preferences = Preferences(gitBin: config.gitBin(), gitAnnexBin: config.gitAnnexBin())
        
        let databaseParentFolder  = "\(testDir!)/database"
        TestingUtil.createDir(absolutePath: databaseParentFolder)
        let storeURL = PathUtils.urlFor(absolutePath: "\(databaseParentFolder)/db")
        
        let persistentContainer = TestingUtil.persistentContainer(mom: managedObjectModel, storeURL: storeURL)
        let data = DataEntrypoint(persistentContainer: persistentContainer, absolutePath: databaseParentFolder)
        queries = Queries(data: data)
        gitAnnexQueries = GitAnnexQueries(preferences: preferences)
        fullScan = FullScan(gitAnnexQueries: gitAnnexQueries!, queries: queries!)
        
        repo1 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo1", gitAnnexQueries: gitAnnexQueries!)
        repo2 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo2", gitAnnexQueries: gitAnnexQueries!)
    }
    
    override func tearDown() {
        fullScan?.stop()
        fullScan = nil
        queries?.stop()
        queries = nil
        gitAnnexQueries = nil
        wait(for: 5)
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
    }
   
    func testVisibleFolderQueries() {
        let pid: String = "process 1"
        
        // add folders to git-annex repo
        let folder1 = "folder1"
        let file1 = "folder1/afile1.txt"
        TestingUtil.createDir(dir: "folder1", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        // add folders and files that will not be visible to git-annex repo
        let folder2 = "folder2"
        let file2 = "folder2/afile2.txt"
        TestingUtil.createDir(dir: folder2, in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file2 content", to: file2, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        // add some more nested folders, that will be visible
        let folder3 = "folder2/folder3"
        let file3 = "folder2/folder3/afile3.txt"
        TestingUtil.createDir(dir: folder3, in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file3 content", to: file3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        DispatchQueue.main.async {
            self.queries!.addVisibleFolderAsync(for: folder1, in: self.repo1!, processID: pid)
            self.queries!.addVisibleFolderAsync(for: folder3, in: self.repo1!, processID: pid)
            self.queries!.addVisibleFolderAsync(for: PathUtils.CURRENT_DIR, in: self.repo1!, processID: pid)
        }
        wait(for: 5) // wait for visible folders to be added (in background thread)
        
        // do a full scan, to add our folders and files to the database
        fullScan!.startFullScan(watchedFolder: repo1!, success: {})
        
        let done = NSPredicate(format: "doneScanning == true")
        expectation(for: done, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 30, handler: nil)

        // Grab visible folders
        let statuses = queries!.allVisibleStatusesV2Blocking(in: repo1!, processID: pid)
        XCTAssertEqual(statuses.count, 6)
        let sorted = statuses.sorted { $0.path < $1.path }

        if let file = sorted[safe: 0] {
            XCTAssertEqual(file.path, PathUtils.CURRENT_DIR)
            XCTAssertEqual(file.presentStatus, Present.present)
            XCTAssertEqual(file.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(file.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for file 3")
        }
        if let file = sorted[safe: 1] {
            XCTAssertEqual(file.path, folder1)
            XCTAssertEqual(file.presentStatus, Present.present)
            XCTAssertEqual(file.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(file.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for root folder")
        }
        if let file = sorted[safe: 2] {
            XCTAssertEqual(file.path, file1)
            XCTAssertEqual(file.presentStatus, Present.present)
            XCTAssertEqual(file.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(file.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for file 1")
        }
        if let file = sorted[safe: 3] {
            XCTAssertEqual(file.path, folder2)
            XCTAssertEqual(file.presentStatus, Present.present)
            XCTAssertEqual(file.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(file.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for folder 2")
        }
        if let file = sorted[safe: 4] {
            XCTAssertEqual(file.path, folder3)
            XCTAssertEqual(file.presentStatus, Present.present)
            XCTAssertEqual(file.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(file.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for folder 3")
        }
        if let file = sorted[safe: 5] {
            XCTAssertEqual(file.path, file3)
            XCTAssertEqual(file.presentStatus, Present.present)
            XCTAssertEqual(file.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(file.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for file 3")
        }

        

        // "folder2/afile2.txt" is not visible, but still has valid data
        if let status1 = queries!.statusForPathV2Blocking(path: file2, in: repo1!) {
            XCTAssertEqual(status1.presentStatus, Present.present)
            XCTAssertEqual(status1.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status1.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file2)")
        }
    }
    
    func testFullScan() {
        //
        // Repo 1
        //
        // set num copies to 2, so all files will be lacking
        XCTAssertTrue(gitAnnexQueries!.gitAnnexSetNumCopies(numCopies: 2, in: repo1!).success)
        let file1 = "a name with spaces.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file1 content", to: file1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file2 = "b ∆∆ söme unicode too.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file2 content", to: file2, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file3 = "subdirA/c.txt"
        TestingUtil.createDir(dir: "subdirA", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file3 content", to: file3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let file4 = "subdirA/dirC/d.txt"
        TestingUtil.createDir(dir: "subdirA/dirC", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "file4 content", to: file4, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        let file5 = "subdirA/e.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file5 content", to: file5, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        //
        // Repo 2
        //
        let file6 = "a.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file6 content", to: file6, in: repo2!, gitAnnexQueries: gitAnnexQueries!)
        let file7 = "b.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "file7 content", to: file7, in: repo2!, gitAnnexQueries: gitAnnexQueries!)
        
        TestingUtil.createDir(dir: "anEmptyDir", in: repo2!)

        TestingUtil.createDir(dir: "anEmptyDirWithEmptyDirs", in: repo2!)
        TestingUtil.createDir(dir: "anEmptyDirWithEmptyDirs/a", in: repo2!)
        TestingUtil.createDir(dir: "anEmptyDirWithEmptyDirs/b", in: repo2!)
        
        // Start a full scan on both repos
        fullScan!.startFullScan(watchedFolder: repo1!, success: {})
        fullScan!.startFullScan(watchedFolder: repo2!, success: {})
        
        let done = NSPredicate(format: "doneScanning == true")
        expectation(for: done, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 30, handler: nil)

        // Repo 1
        if let status1 = queries!.statusForPathV2Blocking(path: file1, in: repo1!) {
            XCTAssertEqual(status1.presentStatus, Present.present)
            XCTAssertEqual(status1.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status1.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file1)")
        }
        if let status2 = queries!.statusForPathV2Blocking(path: file2, in: repo1!) {
            XCTAssertEqual(status2.presentStatus, Present.present)
            XCTAssertEqual(status2.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status2.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file2)")
        }
        if let status3 = queries!.statusForPathV2Blocking(path: file3, in: repo1!) {
            XCTAssertEqual(status3.presentStatus, Present.present)
            XCTAssertEqual(status3.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status3.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file3)")
        }
        
        if let statusSubdirA = queries!.statusForPathV2Blocking(path: "subdirA", in: repo1!) {
            XCTAssertEqual(statusSubdirA.presentStatus, Present.present)
            XCTAssertEqual(statusSubdirA.isDir, true)
            XCTAssertEqual(statusSubdirA.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(statusSubdirA.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for 'subdirA'")
        }
        
        if let status4 = queries!.statusForPathV2Blocking(path: file4, in: repo1!) {
            XCTAssertEqual(status4.presentStatus, Present.present)
            XCTAssertEqual(status4.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status4.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file4)")
        }
        if let status5 = queries!.statusForPathV2Blocking(path: file5, in: repo1!) {
            XCTAssertEqual(status5.presentStatus, Present.present)
            XCTAssertEqual(status5.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status5.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file5)")
        }

        if let statusSubdirC = queries!.statusForPathV2Blocking(path: "subdirA/dirC", in: repo1!) {
            XCTAssertEqual(statusSubdirC.presentStatus, Present.present)
            XCTAssertEqual(statusSubdirC.isDir, true)
            XCTAssertEqual(statusSubdirC.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(statusSubdirC.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for 'subdirA/dirC'")
        }
        
        
        
        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
            XCTAssertEqual(wholeRepo.isDir, true)
            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(wholeRepo.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for whole repo1")
        }
        
        
        // Repo 2
        if let status6 = queries!.statusForPathV2Blocking(path: file6, in: repo2!) {
            XCTAssertEqual(status6.presentStatus, Present.present)
            XCTAssertEqual(status6.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status6.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file6)")
        }
        if let status7 = queries!.statusForPathV2Blocking(path: file7, in: repo2!) {
            XCTAssertEqual(status7.presentStatus, Present.present)
            XCTAssertEqual(status7.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(status7.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(file7)")
        }
        // An empty directory is always good :)
        if let dir = queries!.statusForPathV2Blocking(path: "anEmptyDir", in: repo2!) {
            XCTAssertEqual(dir.presentStatus, Present.present)
            XCTAssertEqual(dir.isDir, true)
            XCTAssertEqual(dir.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for 'anEmptyDir'")
        }
        
        // An empty directory with empty directories inside it
        if let dir = queries!.statusForPathV2Blocking(path: "anEmptyDirWithEmptyDirs/a", in: repo2!) {
            XCTAssertEqual(dir.presentStatus, Present.present)
            XCTAssertEqual(dir.isDir, true)
            XCTAssertEqual(dir.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for 'anEmptyDirWithEmptyDirs/a'")
        }
        if let dir = queries!.statusForPathV2Blocking(path: "anEmptyDirWithEmptyDirs/b", in: repo2!) {
            XCTAssertEqual(dir.presentStatus, Present.present)
            XCTAssertEqual(dir.isDir, true)
            XCTAssertEqual(dir.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for 'anEmptyDirWithEmptyDirs/b'")
        }
        if let dir = queries!.statusForPathV2Blocking(path: "anEmptyDirWithEmptyDirs", in: repo2!) {
            XCTAssertEqual(dir.presentStatus, Present.present)
            XCTAssertEqual(dir.isDir, true)
            XCTAssertEqual(dir.enoughCopies, EnoughCopies.enough)
        } else {
            XCTFail("could not retrieve folder status for 'anEmptyDirWithEmptyDirs'")
        }

        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo2!) {
            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
            XCTAssertEqual(wholeRepo.isDir, true)
            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.enough)
            XCTAssertEqual(wholeRepo.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for whole repo2")
        }
    }
    
    // improvements, oldest top:
    //
    // 10 files     6.44 seconds
    // 100 files    46.75 seconds
    // 1000 files   509.81 seconds
    //
    // 1000 files   220.74 seconds
    // 100 files    22 seconds
    // 50 files     11.46
    //
    // 100 files    2.08 seconds
    // 1000 files   13.65
    //
    // added back in lacking copies query:
    // 100 files    3.10 seconds
    // 1000 files   10.59 seconds
    //
    // my personal 60,000 file repo, ~20min.
    //
    func testLargeRepoPerformance() {
        gitAnnexQueries!.gitAnnexSetNumCopies(numCopies: 2, in: repo1!)
        let files = TestingUtil.createAndAddFiles(numFiles: 100, in: repo1!, gitAnnexQueries: gitAnnexQueries!)

        let startTime = Date()
        fullScan!.startFullScan(watchedFolder: repo1!, success: {})
        
        let done = NSPredicate(format: "doneScanning == true")
        expectation(for: done, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 3000, handler: nil)
        TurtleLog.info("Full scan took \(Date().timeIntervalSince(startTime)) seconds.")
        
        // Repo 1
        for file in files {
            if let status = queries!.statusForPathV2Blocking(path: file, in: repo1!) {
                XCTAssertEqual(status.presentStatus, Present.present)
                XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            } else {
                XCTFail("could not retrieve status for \(file)")
            }
        }
        
        if let wholeRepo = queries!.statusForPathV2Blocking(path: PathUtils.CURRENT_DIR, in: repo1!) {
            XCTAssertEqual(wholeRepo.presentStatus, Present.present)
            XCTAssertEqual(wholeRepo.isDir, true)
            XCTAssertEqual(wholeRepo.enoughCopies, EnoughCopies.lacking)
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
