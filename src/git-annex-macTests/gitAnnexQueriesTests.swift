//
//  gitAnnexQueriesTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 2/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class gitAnnexQueriesTests: XCTestCase {
    var configDir: String?
    var watchedFolder: WatchedFolder?
    var gitAnnexQueries: GitAnnexQueries?
    
    override func setUpWithError() throws {
        super.setUp()
        self.continueAfterFailure = false
        
        TurtleLog.setLoggingLevel(.debug)
        
        configDir = TestingUtil.createTmpDir()
        let config = Config(dataPath: "\(configDir!)/turtle-monitor")
        let preferences = Preferences(gitBin: config.gitBin(), gitAnnexBin: config.gitAnnexBin())
        gitAnnexQueries = GitAnnexQueries(preferences: preferences)
        
        // Create git annex repo in TMP dir
        let directoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)!
        let path = PathUtils.path(for: directoryURL)!
        TurtleLog.info("Testing in \(path)")

        let newRepo = TestingUtil.createInitGitAnnexRepo(at: path, gitAnnexQueries: gitAnnexQueries!)
        XCTAssertNotNil(newRepo)
        watchedFolder = newRepo!
    }
    
    override func tearDownWithError() throws {
        TestingUtil.removeDir(configDir)
        
        super.tearDown()
    }

    func testPaths() {
        let folder = "ok'j\"&'!@#$% ^&* ()`~'"
        TestingUtil.createDir(dir: folder, in: watchedFolder!) // nested path
        XCTAssertTrue(GitAnnexQueries.directoryExistsAt(relativePath: folder, in: watchedFolder!))

        let file2Path = "\(folder)/b.txt"
        TestingUtil.writeToFile(content: "some text again", to: file2Path, in: watchedFolder!)
        XCTAssertTrue(GitAnnexQueries.fileExistsAt(relativePath: folder, in: watchedFolder!))

        let gitAddResult2 = gitAnnexQueries!.gitAnnexCommand(for: file2Path, in: watchedFolder!.pathString, cmd: CommandString.add, limitToMasterBranch: false)
        if !gitAddResult2.success { XCTFail("unable to add file \(gitAddResult2.error)")}
    }
    
    func testChildren() {
        let file1Path = "a.txt"
        TestingUtil.writeToFile(content: "some text", to: file1Path, in: watchedFolder!)
        
        let gitAddResult = gitAnnexQueries!.gitAnnexCommand(for: file1Path, in: watchedFolder!.pathString, cmd: CommandString.add, limitToMasterBranch: false)
        if !gitAddResult.success { XCTFail("unable to add file \(gitAddResult.error)")}
        
        // Path in Root
        let children = gitAnnexQueries!.immediateChildrenNotIgnored(relativePath: PathUtils.CURRENT_DIR, in: watchedFolder!)
        XCTAssertEqual(Set(children), Set([file1Path]))
        
        let folder = "ok"
        TestingUtil.createDir(dir: folder, in: watchedFolder!) // nested path
        
        let file2Path = "\(folder)/b.txt"
        TestingUtil.writeToFile(content: "some text again", to: file2Path, in: watchedFolder!)

        let gitAddResult2 = gitAnnexQueries!.gitAnnexCommand(for: file2Path, in: watchedFolder!.pathString, cmd: CommandString.add, limitToMasterBranch: false)
        if !gitAddResult2.success { XCTFail("unable to add file \(gitAddResult2.error)")}
        let children2 = gitAnnexQueries!.immediateChildrenNotIgnored(relativePath: folder, in: watchedFolder!)
        XCTAssertEqual(Set(children2), Set([file2Path]))
    }

    func testChildrenSpecialCharsInPath() {
        // nested path with space and other characters
        let path = "thedir a a $ & ! ~@#%^*()-_+ a'sdf'' \" \"\" f'"
        TestingUtil.createDir(dir: path, in: watchedFolder!)
        XCTAssertTrue(GitAnnexQueries.directoryExistsAt(relativePath: path, in: watchedFolder!))

        let filePath = "\(path)/b &jh'\"%l.txt"
        TestingUtil.writeToFile(content: "some text again", to: filePath, in: watchedFolder!)
        XCTAssertTrue(GitAnnexQueries.fileExistsAt(relativePath: filePath, in: watchedFolder!))

        let gitAddResult = gitAnnexQueries!.gitAnnexCommand(for: filePath, in: watchedFolder!.pathString, cmd: CommandString.add, limitToMasterBranch: false)
        if !gitAddResult.success { XCTFail("unable to add file \(gitAddResult.error)")}
        
        let gitAnnexInfo = gitAnnexQueries!.gitAnnexCommand(for: filePath, in: watchedFolder!.pathString, cmd: CommandString.annexInfo, limitToMasterBranch: false)
        if !gitAnnexInfo.success { XCTFail("unable to get status for added git-annex file \(gitAnnexInfo.error)")}

        let children = gitAnnexQueries!.immediateChildrenNotIgnored(relativePath: path, in: watchedFolder!)
        XCTAssertEqual(Set(children), Set([filePath]))
    }
    
    func testGitAnnexAllFilesLackingCopiesLacking() {
        TestingUtil.gitAnnexCreateAndAdd(content: "hello", to: "file1.txt", in: watchedFolder!, gitAnnexQueries: gitAnnexQueries!)
        TestingUtil.gitAnnexCreateAndAdd(content: "hello again", to: "file2.txt", in: watchedFolder!, gitAnnexQueries: gitAnnexQueries!)
        gitAnnexQueries!.gitAnnexCommand(for: "2", in: watchedFolder!.pathString, cmd: .numCopies, limitToMasterBranch: false)
        let filesLackingCopies = gitAnnexQueries!.gitAnnexAllFilesLackingCopies(in: watchedFolder!)
        XCTAssertEqual(filesLackingCopies, Set(["file1.txt", "file2.txt"]))
    }
    func testGitAnnexAllFilesLackingCopiesNotLacking() {
        TestingUtil.gitAnnexCreateAndAdd(content: "hello", to: "file1.txt", in: watchedFolder!, gitAnnexQueries: gitAnnexQueries!)
        TestingUtil.gitAnnexCreateAndAdd(content: "hello again", to: "file2.txt", in: watchedFolder!, gitAnnexQueries: gitAnnexQueries!)
        let filesLackingCopies = gitAnnexQueries!.gitAnnexAllFilesLackingCopies(in: watchedFolder!)
        XCTAssertEqual(filesLackingCopies, [])
    }
}
