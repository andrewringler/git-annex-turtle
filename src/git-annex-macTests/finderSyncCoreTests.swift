//
//  finderSyncCoreTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/18/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class finderSyncCoreTests: XCTestCase {
    var fullScan: FullScan?
    var testDir: String?
    var repo1: WatchedFolder?
    var repo2: WatchedFolder?
    var queries: Queries?
    var gitAnnexQueries: GitAnnexQueries?
    var watchGitAndFinderForUpdates: WatchGitAndFinderForUpdates?
    var config: Config?
    var finderSyncCore: FinderSyncCore?
    var finderSyncTesting = FinderSyncTesting()
    
    override func setUp() {
        super.setUp()
        
        TurtleLog.setLoggingLevel(.debug)
        
        testDir = TestingUtil.createTmpDir()
        TurtleLog.info("Using testing dir: \(testDir!)")
        config = Config(dataPath: "\(testDir!)/turtle-monitor")
        
        let databaseParentFolder  = "\(testDir!)/database"
        TestingUtil.createDir(absolutePath: databaseParentFolder)
        let storeURL = PathUtils.urlFor(absolutePath: "\(databaseParentFolder)/db")
        
        let persistentContainer = TestingUtil.persistentContainer(mom: managedObjectModel, storeURL: storeURL)
        let data = DataEntrypoint(persistentContainer: persistentContainer, absolutePath: databaseParentFolder)
        queries = Queries(data: data)
        //        gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: config!.gitAnnexBin()!, gitCmd: config!.gitBin()!)
        gitAnnexQueries = GitAnnexQueries(gitAnnexCmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", gitCmd: "/Applications/git-annex.app/Contents/MacOS/git")
        fullScan = FullScan(gitAnnexQueries: gitAnnexQueries!, queries: queries!)
        let handleStatusRequests = HandleStatusRequests(queries: queries!, gitAnnexQueries: gitAnnexQueries!)
        
        finderSyncCore = FinderSyncCore(finderSync: finderSyncTesting, data: data)
        
        watchGitAndFinderForUpdates = WatchGitAndFinderForUpdates(gitAnnexTurtle: GitAnnexTurtleStub(), config: config!, data: data, fullScan: fullScan!, handleStatusRequests: handleStatusRequests, gitAnnexQueries: gitAnnexQueries!, dialogs: DialogTestingStubFailOnMessage())
        
        repo1 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo1", gitAnnexQueries: gitAnnexQueries!)
        repo2 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo2", gitAnnexQueries: gitAnnexQueries!)
    }
    
    override func tearDown() {
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
    }
    
    func testFinderSyncCore() {
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
        
        // Add repo to config, so we'll start the full scan
        // and then subsequently start the incremental scans
        
        XCTAssertTrue(config!.watchRepo(repo: repo1!.pathString), "unable to watch repo 1")
        XCTAssertTrue(config!.watchRepo(repo: repo2!.pathString), "unable to watch repo 2")
        
        // wait a few seconds for watchGitAndFinderForUpdates
        // to find the repos we just added and start a full scan on them
        // and waiting for watched folder list to make it to the Finder Sync extension
        wait(for: 10)
        
        // pretend these root folders have come into view
        // make root folder visible
        finderSyncCore!.beginObservingDirectory(at: PathUtils.urlFor(absolutePath: repo1!.pathString))
        finderSyncCore!.beginObservingDirectory(at: PathUtils.urlFor(absolutePath: repo2!.pathString))
        
        // wait for the full scans to complete
        // triggered by watchGitAndFinderForUpdates
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
        

        ///
        /// OK, repos have their full scan completed
        /// lets verify, that Finder Sync Core
        /// received all of the updates we were expecting
        
        // wait a few seconds for FinderSyncCore
        // to grab all changes
        wait(for: 10)
        
        // verify set WatchedFolders
        let expected: Set<URL> = Set([PathUtils.urlFor(absolutePath: repo1!.pathString), PathUtils.urlFor(absolutePath: repo2!.pathString)])
        XCTAssertEqual(finderSyncTesting.setWatchedFoldersHistory, [expected])
        
        // verify update badges
        assertCount(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, path: file1, for: repo1!, expectedCount: 1)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: file1, watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 1)
        assertCount(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, path: file2, for: repo1!, expectedCount: 1)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: file2, watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 1)
        

        
        
        
        
        
        
        ///
        /// OK, repos have their full scan completed
        /// lets make some changes and see how
        /// our incremental scanner picks them up
        /// and how our finder sync extension picks them up

        // make one folder visible already, before the changes are made
        finderSyncCore!.beginObservingDirectory(at: PathUtils.url(for: "subdirA", in: repo1!))

        
        /// add a new file to existing folder
        let changeFile1 = "subdirA/changeFile1.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "changeFile1 content", to: changeFile1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        /// add a new file to a new folder
        let changeFile2 = "subdirNew1/changeFile2.txt"
        TestingUtil.createDir(dir: "subdirNew1", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "changeFile2 content", to: changeFile2, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        /// add a new folder to a new folder
        TestingUtil.createDir(dir: "subdirNew1/subdirNew3", in: repo1!)
        let changeFile4 = "subdirNew1/subdirNew3/changeFile4.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "changeFile4 content", to: changeFile4, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        
        /// add a new folder to an existing sub-folder (from the full scan)
        /// and a file to it
        TestingUtil.createDir(dir: "subdirA/subdirNew2", in: repo1!)
        let changeFile3 = "subdirA/subdirNew2/changeFile3.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "changeFile3 content", to: changeFile3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        // incremental scanner will only pick up new files once they are committed
        TestingUtil.gitCommit("added some files", in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        /// pretend the new folders are visible in finder windows
        /// so that our finder sync extensions will see them
        finderSyncCore!.beginObservingDirectory(at: PathUtils.url(for: "subdirNew1", in: repo1!))

        // wait for incremental scan to complete
        // and for our Finder Sync extension to pick up the changes
        wait(for: 5)
        
        // make some folders visible after a wait
        finderSyncCore!.beginObservingDirectory(at: PathUtils.url(for: "subdirNew1/subdirNew3", in: repo1!))
        finderSyncCore!.beginObservingDirectory(at: PathUtils.url(for: "subdirA/subdirNew2", in: repo1!))

        wait(for: 15)

        /// verify Finder Sync Core picked up the new files
        /// from our incremental scanner
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: changeFile1, watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 1)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: changeFile2, watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 1)
        
        // directory get first update with incomplete information
        // then final update with full information
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: true, isGitAnnexTracked: true, presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, path: "subdirNew1", watchedFolder: repo1!, needsUpdate: true, occurenceOrderOfThisPath: 1)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: true, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: "subdirNew1", watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 2)
        
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: true, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: "subdirNew1/subdirNew3", watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 2)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: changeFile4, watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 1)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: true, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: "subdirA/subdirNew2", watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 2)
        assertContains(updateBadgeHistory: finderSyncTesting.updateBadgeHistory, isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 1, path: changeFile3, watchedFolder: repo1!, needsUpdate: false, occurenceOrderOfThisPath: 1)
        
        
        if let status = queries!.statusForPathV2Blocking(path: "subdirA", in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.isDir, true)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for 'subdirA'")
        }
        if let status = queries!.statusForPathV2Blocking(path: changeFile1, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(changeFile1)")
        }
        
        if let status = queries!.statusForPathV2Blocking(path: changeFile2, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(changeFile2)")
        }
        if let status = queries!.statusForPathV2Blocking(path: "subdirNew1", in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.isDir, true)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for 'subdirNew1'")
        }
        
        if let status = queries!.statusForPathV2Blocking(path: changeFile3, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(changeFile3)")
        }
        if let status = queries!.statusForPathV2Blocking(path: "subdirA/subdirNew2", in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.isDir, true)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for 'subdirA/subdirNew2'")
        }
        
        if let status = queries!.statusForPathV2Blocking(path: changeFile4, in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve status for \(changeFile4)")
        }
        if let status = queries!.statusForPathV2Blocking(path: "subdirNew1/subdirNew3", in: repo1!) {
            XCTAssertEqual(status.presentStatus, Present.present)
            XCTAssertEqual(status.isDir, true)
            XCTAssertEqual(status.enoughCopies, EnoughCopies.lacking)
            XCTAssertEqual(status.numberOfCopies, 1)
        } else {
            XCTFail("could not retrieve folder status for 'subdirNew1/subdirNew3'")
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
    
    func assertCount(updateBadgeHistory: [(url: URL, status: PathStatus)], path: String, for watchedFolder: WatchedFolder, expectedCount: Int, file: StaticString = #file, line: UInt = #line) {
        var occurenceCount = 0
        let url = PathUtils.url(for: path, in: watchedFolder)
        for entry in updateBadgeHistory {
            if entry.url == url {
                XCTAssertEqual(entry.status.path, path, "url matched but path didn't, this should never happen",
                               file: file, line: line)
                XCTAssertEqual(entry.status.watchedFolder, watchedFolder, "url matched but watchedFolder didn't, this should never happen",
                               file: file, line: line)
                
                occurenceCount = occurenceCount + 1
            }
        }

        XCTAssertEqual(occurenceCount, expectedCount,
                       file: file, line: line)
    }
    
    func assertContains(updateBadgeHistory: [(url: URL, status: PathStatus)], isDir: Bool, isGitAnnexTracked: Bool, presentStatus: Present?, enoughCopies: EnoughCopies?, numberOfCopies: UInt8?, path: String, watchedFolder: WatchedFolder, needsUpdate: Bool, occurenceOrderOfThisPath: Int, file: StaticString = #file, line: UInt = #line) {
        var s: PathStatus?
        var occurenceCount = 1
        let url = PathUtils.url(for: path, in: watchedFolder)
        for entry in updateBadgeHistory {
            if entry.url == url {
                XCTAssertEqual(entry.status.path, path, "url matched but path didn't, this should never happen",
                               file: file, line: line)
                XCTAssertEqual(entry.status.watchedFolder, watchedFolder, "url matched but watchedFolder didn't, this should never happen",
                               file: file, line: line)

                s = entry.status
                if occurenceCount == occurenceOrderOfThisPath {
                    break
                }
                occurenceCount = occurenceCount + 1
            }
        }
        
        if s == nil {
            XCTFail("could not find any status matching path \(path)",
                file: file, line: line)
            return
        }
        if occurenceCount != occurenceOrderOfThisPath {
            XCTFail("could not find occurence #\(occurenceOrderOfThisPath) for path \(path), max occurences was \(occurenceCount)",
                file: file, line: line)
            return
        }
        
        // verify match
        XCTAssertEqual(s!.isDir, isDir, "is dir",
                       file: file, line: line)
        XCTAssertEqual(s!.isGitAnnexTracked, isGitAnnexTracked, "is tracked",
                       file: file, line: line)
        XCTAssertEqual(s!.presentStatus, presentStatus, "present",
                       file: file, line: line)
        XCTAssertEqual(s!.enoughCopies, enoughCopies, "enough copies",
                       file: file, line: line)
        XCTAssertEqual(s!.numberOfCopies, numberOfCopies, "number of copies",
                       file: file, line: line)
        XCTAssertEqual(s!.needsUpdate, needsUpdate, "needs update",
                       file: file, line: line)
    }
}

class FinderSyncTesting: FinderSyncProtocol {
    let myID: String = UUID().uuidString
    var setWatchedFoldersHistory: [Set<URL>] = []
    var updateBadgeHistory: [(url: URL, status: PathStatus)] = []
    
    func updateBadge(for url: URL, with status: PathStatus) {
        updateBadgeHistory.append((url: url, status: status))
    }
    
    func setWatchedFolders(to newWatchedFolders: Set<URL>) {
        setWatchedFoldersHistory.append(newWatchedFolders)
    }
    
    func id() -> String {
        return myID
    }
}
