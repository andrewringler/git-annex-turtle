//
//  shareButtonTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 12/25/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class shareButtonTests: XCTestCase {
    var fullScan: FullScan?
    var testDir: String?
    var repo1: WatchedFolder?
    var repo2: WatchedFolder?
    var exportRemote1: ExportTreeRemote?
    var queries: Queries?
    var gitAnnexQueries: GitAnnexQueries?
    var watchGitAndFinderForUpdates: WatchGitAndFinderForUpdates?
    var config: Config?
    var preferences: Preferences?
    var timeAtDoneOptional: Date? = nil
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: type(of: self))] )!
        return managedObjectModel
    }()

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
        exportRemote1 = TestingUtil.createDirectorySpecialRemoteExportTree(watchedFolder: repo1!, at: "\(testDir!)/exportRemote1", named: "exportremote1", gitAnnexQueries: gitAnnexQueries!)
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
    
    func testShareSharesAlreadyAddedFileNotInShareFolder() {
        repo1!.shareRemote = ShareSettings(shareRemote: exportRemote1!.name, shareLocalPath: "public-share")
        XCTAssertTrue(config!.updateShareRemote(repo: repo1!.pathString, shareRemote: repo1!.shareRemote.shareRemote!), "Unable to update share remote")
        XCTAssertTrue(config!.updateShareRemoteLocalPath(repo: repo1!.pathString, shareLocalPath: repo1!.shareRemote.shareLocalPath!), "Unable to update share remote local path")

        let fileToShare = "a_file.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "some file content", to: fileToShare, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        let (success, error, output, commandRun) = gitAnnexQueries!.gitAnnexShare(for: fileToShare, in: repo1!)
        XCTAssertTrue(success, error.description)
        
        // Verify exported file
        let exportedFileInExportTree = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare)
        let exportFileContentsAtRemote = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree))
        XCTAssertEqual(exportFileContentsAtRemote, "some file content")
    }
    
    func testShareSharesNotAddedFileNotInShareFolder() {
        repo1!.shareRemote = ShareSettings(shareRemote: exportRemote1!.name, shareLocalPath: "public-share")
        XCTAssertTrue(config!.updateShareRemote(repo: repo1!.pathString, shareRemote: repo1!.shareRemote.shareRemote!), "Unable to update share remote")
        XCTAssertTrue(config!.updateShareRemoteLocalPath(repo: repo1!.pathString, shareLocalPath: repo1!.shareRemote.shareLocalPath!), "Unable to update share remote local path")

        let fileToShare = "a_file.txt"
        TestingUtil.writeToFile(content: "some file content", to: fileToShare, in: repo1!)
        let (success, error, output, commandRun) = gitAnnexQueries!.gitAnnexShare(for: fileToShare, in: repo1!)
        XCTAssertTrue(success, error.description)

        // Verify exported file
        let exportedFileInExportTree = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare)
        let exportFileContentsAtRemote = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree))
        XCTAssertEqual(exportFileContentsAtRemote, "some file content")
    }
    
    func testShareSharesNotAddedFileAlreadyInShareFolder() {
        repo1!.shareRemote = ShareSettings(shareRemote: exportRemote1!.name, shareLocalPath: "public-share")
        XCTAssertTrue(config!.updateShareRemote(repo: repo1!.pathString, shareRemote: repo1!.shareRemote.shareRemote!), "Unable to update share remote")
        XCTAssertTrue(config!.updateShareRemoteLocalPath(repo: repo1!.pathString, shareLocalPath: repo1!.shareRemote.shareLocalPath!), "Unable to update share remote local path")
        
        TestingUtil.createDir(dir: "public-share", in: repo1!)
        let fileToShare = "a_file.txt"
        let fileToShareLocalFullPath = "public-share/a_file.txt"
        TestingUtil.writeToFile(content: "some file content", to: fileToShareLocalFullPath, in: repo1!)
        let (success, error, output, commandRun) = gitAnnexQueries!.gitAnnexShare(for: fileToShareLocalFullPath, in: repo1!)
        XCTAssertTrue(success, error.description)
        
        // Verify exported file
        let exportedFileInExportTree = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare)
        let exportFileContentsAtRemote = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree))
        XCTAssertEqual(exportFileContentsAtRemote, "some file content")
    }
    
    func testShareSharesAddedFileAlreadyInShareFolder() {
        XCTAssertNotNil(exportRemote1)
        repo1!.shareRemote = ShareSettings(shareRemote: exportRemote1!.name, shareLocalPath: "public-share")
        XCTAssertTrue(config!.updateShareRemote(repo: repo1!.pathString, shareRemote: repo1!.shareRemote.shareRemote!), "Unable to update share remote")
        XCTAssertTrue(config!.updateShareRemoteLocalPath(repo: repo1!.pathString, shareLocalPath: repo1!.shareRemote.shareLocalPath!), "Unable to update share remote local path")
        
        TestingUtil.createDir(dir: "public-share", in: repo1!)
        let fileToShare = "a_file.txt"
        let fileToShareLocalFullPath = "public-share/a_file.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "some file content", to: fileToShareLocalFullPath, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        let (success, error, output, commandRun) = gitAnnexQueries!.gitAnnexShare(for: fileToShareLocalFullPath, in: repo1!)
        XCTAssertTrue(success, error.description)
        
        // Verify exported file
        let exportedFileInExportTree = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare)
        let exportFileContentsAtRemote = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree))
        XCTAssertEqual(exportFileContentsAtRemote, "some file content")
    }
    
    func testSharingSequenceOfShares() {
        repo1!.shareRemote = ShareSettings(shareRemote: exportRemote1!.name, shareLocalPath: "public-share")
        XCTAssertTrue(config!.updateShareRemote(repo: repo1!.pathString, shareRemote: repo1!.shareRemote.shareRemote!), "Unable to update share remote")
        XCTAssertTrue(config!.updateShareRemoteLocalPath(repo: repo1!.pathString, shareLocalPath: repo1!.shareRemote.shareLocalPath!), "Unable to update share remote local path")
        
        let fileToShare1 = "a_file.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "some file content", to: fileToShare1, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        let (success, error, output, commandRun) = gitAnnexQueries!.gitAnnexShare(for: fileToShare1, in: repo1!)
        XCTAssertTrue(success, error.description)
 
        let fileToShare2 = "a_file2.txt"
        TestingUtil.gitAnnexCreateAndAdd(content: "some file content 2", to: fileToShare2, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        let (success2, error2, output2, commandRun2) = gitAnnexQueries!.gitAnnexShare(for: fileToShare2, in: repo1!)
        XCTAssertTrue(success2, error2.description)

        let fileToShare3 = "subdir1/a_file3.txt"
        let fileToShare3BareFileName = "a_file3.txt"
        TestingUtil.createDir(dir: "subdir1", in: repo1!)
        TestingUtil.gitAnnexCreateAndAdd(content: "some file content 3", to: fileToShare3, in: repo1!, gitAnnexQueries: gitAnnexQueries!)
        let (success3, error3, output3, commandRun3) = gitAnnexQueries!.gitAnnexShare(for: fileToShare3, in: repo1!)
        XCTAssertTrue(success3, error3.description)

        // Verify exported files
        let exportedFileInExportTree = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare1)
        let exportFileContentsAtRemote = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree))
        XCTAssertEqual(exportFileContentsAtRemote, "some file content")
        
        let exportedFileInExportTree2 = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare2)
        let exportFileContentsAtRemote2 = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree2))
        XCTAssertEqual(exportFileContentsAtRemote2, "some file content 2")

        // File in subdirectory just gets placed at share folder root
        let exportedFileInExportTree3 = PathUtils.joinPaths(prefixPath: exportRemote1!.path, suffixPath: fileToShare3BareFileName)
        let exportFileContentsAtRemote3 = TestingUtil.readFile(from: PathUtils.urlFor(absolutePath: exportedFileInExportTree3))
        XCTAssertEqual(exportFileContentsAtRemote3, "some file content 3")
    }
}
