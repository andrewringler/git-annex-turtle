//
//  watchGitAndFinderForUpdatesTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/14/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class watchGitAndFinderForUpdatesTests: XCTestCase {
    var fullScan: FullScan?
    var testDir: String?
    var repo1: WatchedFolder?
    var repo2: WatchedFolder?
    var queries: Queries?
    var gitAnnexQueries: GitAnnexQueries?
    var watchGitAndFinderForUpdates: WatchGitAndFinderForUpdates?
    var config: Config?
    var preferences: Preferences?
    var timeAtDoneOptional: Date? = nil

    override func setUp() {
        super.setUp()
        
        TurtleLog.setLoggingLevel(.debug)
        
        testDir = TestingUtil.createTmpDir()
        
        
        TurtleLog.info("Using testing dir: \(testDir!)")
        config = Config(dataPath: "\(testDir!)/turtle-monitor")
        preferences = Preferences(gitBin: config!.gitBin(), gitAnnexBin: config!.gitAnnexBin())

        let databaseParentFolder  = "\(testDir!)/database"
        TestingUtil.createDir(absolutePath: databaseParentFolder)
        let storeURL = PathUtils.urlFor(absolutePath: "\(databaseParentFolder)/db")
        let persistentContainer = TestingUtil.persistentContainer(mom: managedObjectModel, storeURL: storeURL)
        let data = DataEntrypoint(persistentContainer: persistentContainer, absolutePath: databaseParentFolder)
        queries = Queries(data: data)
        let visibleFolders = VisibleFolders(queries: queries!)
        gitAnnexQueries = GitAnnexQueries(preferences: preferences!)
        fullScan = FullScan(gitAnnexQueries: gitAnnexQueries!, queries: queries!)

        watchGitAndFinderForUpdates = WatchGitAndFinderForUpdates(gitAnnexTurtle: GitAnnexTurtleStub(), config: config!, data: data, fullScan: fullScan!, gitAnnexQueries: gitAnnexQueries!, dialogs: DialogTestingStubFailOnMessage(), visibleFolders: visibleFolders, preferences: preferences!)
        
        repo1 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo1", gitAnnexQueries: gitAnnexQueries!)
        repo2 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo2", gitAnnexQueries: gitAnnexQueries!)
        TestingUtil.setDirectMode(for: repo2!, gitAnnexQueries: gitAnnexQueries!)
    }
    
    override func tearDown() {
        fullScan?.stop()
        fullScan = nil
        queries?.stop()
        queries = nil
        gitAnnexQueries = nil
        watchGitAndFinderForUpdates?.stop()
        watchGitAndFinderForUpdates = nil
        
        wait(for: 10)        
        TestingUtil.removeDir(testDir)
        
        super.tearDown()
    }
    
    func testWatchedFoldersList() {
        let watchedFolders = watchGitAndFinderForUpdates!.watchedFolders

        XCTAssertTrue(config!.watchRepo(repo: repo1!.pathString), "unable to add repo1 to config file")
        XCTAssertTrue(config!.watchRepo(repo: repo2!.pathString), "unable to add repo2 to config file")

        waitForIncrementalScanToStartAndFinish()
        
        XCTAssertEqual(watchedFolders.getWatchedFolders().map {
            $0.pathString
        }.sorted(), [repo1!.pathString, repo2!.pathString].sorted())
        
        // Create a new repo nested inside an existing one
        let repo3 = TestingUtil.createInitGitAnnexRepo(at: "\(repo1!.pathString)/repo3", gitAnnexQueries: gitAnnexQueries!)
        
        // Add to config file
        XCTAssertTrue(config!.watchRepo(repo: repo3!.pathString), "unable to add repo3 to config file")
        XCTAssertEqual(repo3!.pathString, "\(repo1!.pathString)/repo3")
        
        // The Config file now contains our new repo
        XCTAssertEqual(config!.listWatchedRepos().sorted(),  [WatchedRepoConfig(repo1!.pathString, nil, nil), WatchedRepoConfig(repo2!.pathString, nil, nil), WatchedRepoConfig(repo3!.pathString, nil, nil)].sorted())
        
        // Add another valid one
        let repo4 = TestingUtil.createInitGitAnnexRepo(at: "\(testDir!)/repo4", gitAnnexQueries: gitAnnexQueries!)
        XCTAssertEqual(repo4!.pathString, "\(testDir!)/repo4")
        
        // Add to config file
        XCTAssertTrue(config!.watchRepo(repo: repo4!.pathString), "unable to add repo4 to config file")

        // The Config file now contains all 4 repos
        XCTAssertEqual(config!.listWatchedRepos().sorted(),  [WatchedRepoConfig(repo1!.pathString, nil, nil), WatchedRepoConfig(repo2!.pathString, nil, nil), WatchedRepoConfig(repo3!.pathString, nil, nil), WatchedRepoConfig(repo4!.pathString, nil, nil)].sorted())

        waitForIncrementalScanToStartAndFinish()

        // And, the 4th repo was added to our App, but the 3rd repo was ignored
        // since it is nested inside the 1st
        XCTAssertEqual(watchedFolders.getWatchedFolders().map {
            $0.pathString
            }.sorted(), [repo1!.pathString, repo2!.pathString, repo4!.pathString].sorted())
        
        // Remove repo 1
        XCTAssertTrue(config!.stopWatchingRepo(repo: repo1!.pathString))

        waitForIncrementalScanToStartAndFinish()

        // Now repo 3 will be added, since it is no longer nested
        XCTAssertEqual(watchedFolders.getWatchedFolders().map {
            $0.pathString
        }.sorted(), [repo2!.pathString, repo3!.pathString, repo4!.pathString].sorted())
    }
    
    func testUpdateConfigUpdatesPreferences() {
        // create some valid git and git-annex binaries
        let newGoodGitPath = "\(testDir!)/somegit"
        let newGoodGitAnnexPath = "\(testDir!)/somegitannex"
        XCTAssertTrue(TestingUtil.createSymlink(from: newGoodGitPath, to: config!.gitBin()!))
        XCTAssertTrue(TestingUtil.createSymlink(from: newGoodGitAnnexPath, to: config!.gitAnnexBin()!))

        // changing config updates preferences
        XCTAssertTrue(config!.setGitBin(gitBin: newGoodGitPath))
        XCTAssertTrue(config!.setGitAnnexBin(gitAnnexBin: newGoodGitAnnexPath))

        wait(for: 1)
        XCTAssertEqual(preferences!.gitBin(), newGoodGitPath)
        XCTAssertEqual(preferences!.gitAnnexBin(), newGoodGitAnnexPath)
        
        // create some invalid git and git-annex paths
        let newBadGitPath = "/tmp/notareadfolder23094sdfsdklj3dsfljk/git"
        let newBadGitAnnexPath = "/tmp/notareadfolderasdfsdf53fd23094sfljk/git-annex"
        
        // changing config doesn't update preferences, since invalid paths
        XCTAssertFalse(config!.setGitBin(gitBin: newBadGitPath))
        XCTAssertFalse(config!.setGitAnnexBin(gitAnnexBin: newBadGitAnnexPath))
        
        // paths will remain unchanged
        wait(for: 1)
        XCTAssertEqual(preferences!.gitBin(), newGoodGitPath)
        XCTAssertEqual(preferences!.gitAnnexBin(), newGoodGitAnnexPath)
    }
    
    func testWatchGitAndFinderForUpdates() {
        //
        // Repo 1
        //
        // set num copies to 2, so all files will be lacking
        XCTAssertTrue(gitAnnexQueries!.gitAnnexSetNumCopies(numCopies: 2, in: repo1!).success)
        let file1 = "a name with spaces.log"
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
        wait(for: 2)

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
        /// lets make some changes and see how
        /// our incremental scanner picks them up
        
        /// add a new file to existing folder
        let changeFile1 = "subdirA/changeFile1.log"
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

        wait(for: 15)

        // incremental scanner will only pick up new files once they are committed
        TestingUtil.gitCommit("added some files", in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        waitForIncrementalScanToStartAndFinish()

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
    
    func testWatchGitAndFinderForUpdatesAddingNewFolderWithoutInvalidatingRoot() {
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
        wait(for: 5)
        
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
        /// lets make some changes and see how
        /// our incremental scanner picks them up
        
        /// add a new folder to an existing sub-folder (from the full scan)
        /// and a file to it
        TestingUtil.createDir(dir: "subdirA/subdirNew2", in: repo1!)
        let changeFile3 = "subdirA/subdirNew2/changeFile3.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "changeFile3 content", to: changeFile3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        // incremental scanner will only pick up new files once they are committed
        TestingUtil.gitCommit("added some files", in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        
        waitForIncrementalScanToStartAndFinish()

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
    }
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))] )!
        return managedObjectModel
    }()
    
    func doneScanning() -> Bool {
        return fullScan!.isScanning(watchedFolder: repo1!) == false
            && fullScan!.isScanning(watchedFolder: repo2!) == false
    }
    
    func waitForIncrementalScanToStartAndFinish() {
        // wait for the incremental scans to start
        wait(for: 3)

        // wait for the incremental scans to complete
        timeAtDoneOptional = nil
        let doneWithIncremental = NSPredicate(format: "doneWithIncrementalScan == true")
        expectation(for: doneWithIncremental, evaluatedWith: self, handler: nil)
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func doneWithIncrementalScan() -> Bool {
        let handlingRequests = watchGitAndFinderForUpdates!.handlingStatusRequests()

        // if we are still handling requests, we are not done
        if handlingRequests {
            timeAtDoneOptional = nil // reset timer
            return false
        }
        
        if let timeAtDone = timeAtDoneOptional {
            // if we have been done for more than 1 seconds, we are done
            if Date().timeIntervalSince(timeAtDone) > 1 {
                return true
            }
        } else {
            timeAtDoneOptional = Date()
        }
        
        return false
    }
}
