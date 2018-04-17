//
//  git_annex_macTests.swift
//  git-annex-macTests
//
//  Created by Andrew Ringler on 11/22/16.
//  Copyright © 2016 Andrew Ringler. All rights reserved.
//

import XCTest

class git_annex_turtleTests: XCTestCase {
    var testDir: String?
    
    override func setUp() {
        super.setUp()
        
        TurtleLog.setLoggingLevel(.debug)
        testDir = TestingUtil.createTmpDir()
    }
    
    override func tearDown() {
        TestingUtil.removeDir(testDir)
        super.tearDown()
    }

    func testWatchedFolder_equals_equal_sameobject() {
        let uuidString = UUID().uuidString
        let a = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        
        XCTAssertEqual(a, a)
    }

    func testWatchedFolder_equals_equal() {
        let uuidString = UUID().uuidString
        let a = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        let b = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        
        XCTAssertEqual(a, b)
    }
    
    func testWatchedFolder_not_equals_path_different() {
        let uuidString = UUID().uuidString
        let a = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "a")
        let b = WatchedFolder(uuid: UUID(uuidString: uuidString)!, pathString: "b")
        
        XCTAssertNotEqual(a, b)
    }
    
    func testWatchedFolder_equals_not_equal_uuid() {
        let a = WatchedFolder(uuid: UUID(), pathString: "a")
        let b = WatchedFolder(uuid: UUID(), pathString: "a")
        
        XCTAssertNotEqual(a, b)
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testEnoughCopiesAndEnoughEnough() {
        XCTAssertEqual(EnoughCopies.enough && EnoughCopies.enough, EnoughCopies.enough)
    }
    func testEnoughCopiesAndEnoughLacking() {
        XCTAssertEqual(EnoughCopies.enough && EnoughCopies.lacking, EnoughCopies.lacking)
    }
    func testEnoughCopiesAndLackingEnough() {
        XCTAssertEqual(EnoughCopies.lacking && EnoughCopies.enough, EnoughCopies.lacking)
    }
    func testEnoughCopiesAndLackingLacking() {
        XCTAssertEqual(EnoughCopies.lacking && EnoughCopies.lacking, EnoughCopies.lacking)
    }
    
    func testPresentAndPresentPresent() {
        XCTAssertEqual(Present.present && Present.present, Present.present)
    }
    func testPresentAndPresentAbsent() {
        XCTAssertEqual(Present.present && Present.absent, Present.partialPresent)
    }
    func testPresentAndAbsentPresent() {
        XCTAssertEqual(Present.absent && Present.present, Present.partialPresent)
    }
    func testPresentAndAbsentAbsent() {
        XCTAssertEqual(Present.absent && Present.absent, Present.absent)
    }
    func testPresentAndPresentPartialPresent() {
        XCTAssertEqual(Present.present && Present.partialPresent, Present.partialPresent)
    }
    func testPresentAndPartialPresentPresent() {
        XCTAssertEqual(Present.partialPresent && Present.present, Present.partialPresent)
    }
    func testPresentAndPartialPresentPartialPresent() {
        XCTAssertEqual(Present.partialPresent && Present.partialPresent, Present.partialPresent)
    }
    func testPresentAndPartialPresentAbsent() {
        XCTAssertEqual(Present.partialPresent && Present.absent, Present.partialPresent)
    }
    func testPresentAndAbsentPartialPresent() {
        XCTAssertEqual(Present.absent && Present.partialPresent, Present.partialPresent)
    }
    func testPresentAndChainPartialPresent() {
        XCTAssertEqual(Present.absent && Present.absent && Present.present && Present.partialPresent,
                       Present.partialPresent)
    }
    func testPresentAndChainPresent() {
        XCTAssertEqual(Present.present && Present.present && Present.present && Present.present,
                       Present.present)
    }
    func testPresentAndChainAbsent() {
        XCTAssertEqual(Present.absent && Present.absent && Present.absent && Present.absent,
                       Present.absent)
    }
    
    func testPathUtilsParentNilCurrent() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertNil(PathUtils.parent(for: PathUtils.CURRENT_DIR, in: a))
    }
    func testPathUtilsParentB() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertEqual(PathUtils.parent(for: "b", in: a), PathUtils.CURRENT_DIR)
    }
    func testPathUtilsParentBC() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertEqual(PathUtils.parent(for: "b/c", in: a), "b")
    }
    func testPathUtilsParentBCDPng() {
        let a = WatchedFolder(uuid: UUID(), pathString: "/Users/a")
        XCTAssertEqual(PathUtils.parent(for: "b/c/d.png", in: a), "b/c")
    }
    
    func testParentForAbsolutePathFile() {
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp/afile"), "/tmp")
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp/afile with spaces"), "/tmp")
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp/afile with spaces and accènts"), "/tmp")
    }
    func testParentForAbsolutePathAFolder() {
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp/"), "/")
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp a folder with spaces/"), "/")
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp a folder with spaces and accénts/"), "/")
    }
    func testParentForAbsolutePathANestedFolder() {
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp/who/what/where"), "/tmp/who/what")
        XCTAssertEqual(PathUtils.parent(absolutePath: "/tmp/who/what and some spaces/where"), "/tmp/who/what and some spaces")
    }
    func testParentForAbsolutePathRoot() {
        XCTAssertNil(PathUtils.parent(absolutePath: "/"))
    }
    func testParentForAbsolutePathInvalidAbsolutePath() {
        XCTAssertNil(PathUtils.parent(absolutePath: "aRelativePath"))
        XCTAssertNil(PathUtils.parent(absolutePath: "aFolder/"))
        XCTAssertNil(PathUtils.parent(absolutePath: "aFolder/aNotherFolder/"))
        XCTAssertNil(PathUtils.parent(absolutePath: "aFolder/aNotherFolder"))
        XCTAssertNil(PathUtils.parent(absolutePath: "aFolder/aNotherFolder/afile"))
    }

    func testGitAnnexBinAbsolutePath() {
        XCTAssertNotNil(GitAnnexQueries.gitAnnexBinAbsolutePath(workingDirectory: testDir!))
    }
    func testGitBinAbsolutePath() {
        XCTAssertNotNil(GitAnnexQueries.gitBinAbsolutePath(workingDirectory: testDir!, gitAnnexPath: nil))
    }
    
    func testParseConfigisTurtleSection() {
        XCTAssertTrue(TurtleConfigV1.isTurtleSection("[turtle]"))
    }
    func testParseConfigisTurtleSectionFalse() {
        XCTAssertFalse(TurtleConfigV1.isTurtleSection("[turtley]"))
    }
    func testParseConfigTurtleMonitorSectionTrueNoName() {
        let expected: (turtleMonitorSection: Bool, name: String?) = (turtleMonitorSection: true, name: nil)
        let actual: (turtleMonitorSection: Bool, name: String?) = TurtleConfigV1.turtleMonitorSection("[turtle-monitor]")
        XCTAssertTrue(equalsT(expected,actual), "actual: \(actual)")
    }
    func testParseConfigTurtleMonitorSectionTrueName() {
        let expected: (turtleMonitorSection: Bool, name: String?) = (turtleMonitorSection: true, name: "a nice name")
        let actual: (turtleMonitorSection: Bool, name: String?) = TurtleConfigV1.turtleMonitorSection("[turtle-monitor \"a nice name\"]")
        XCTAssertTrue(equalsT(expected,actual), "actual: \(actual)")
    }
    func testParseConfigTurtleGitAnnexBin() {
        let config: [String] = """
        [turtle]
        git-annex-bin = /Applications/git-annex.app/Contents/MacOS/git-annex
        """.components(separatedBy: CharacterSet.newlines)
        
        let expected = TurtleConfigV1(gitAnnexBin: "/Applications/git-annex.app/Contents/MacOS/git-annex", gitBin: nil, monitoredRepo: [])
        
        let actual = TurtleConfigV1.parse(from: config)
        
        XCTAssertNotNil(actual, "Config was nil")
        if let actualConfig = actual {
            XCTAssertEqual(expected, actualConfig)
        }
    }
    func testParseConfigTurtleSection() {
        let config: [String] = """
        [turtle]
        git-annex-bin = /Applications/git-annex.app/Contents/MacOS/git-annex
        git-bin = /Applications/git-annex.app/Contents/MacOS/git
        """.components(separatedBy: CharacterSet.newlines)
        
        let expected = TurtleConfigV1(gitAnnexBin: "/Applications/git-annex.app/Contents/MacOS/git-annex", gitBin: "/Applications/git-annex.app/Contents/MacOS/git", monitoredRepo: [])
        
        let actual = TurtleConfigV1.parse(from: config)
        
        XCTAssertNotNil(actual, "Config was nil")
        if let actualConfig = actual {
            XCTAssertEqual(expected, actualConfig)
        }
    }
    func testParseConfigTurtleSectionSpaces() {
        // some wierd spacing that should be ignored
        let config: [String] = "[turtle]\n    git-annex-bin   =/Applications/git-annex.app/Contents/MacOS/git-annex  \ngit-bin=        /Applications/git-annex.app/Contents/MacOS/git ".components(separatedBy: CharacterSet.newlines)
        
        let expected = TurtleConfigV1(gitAnnexBin: "/Applications/git-annex.app/Contents/MacOS/git-annex", gitBin: "/Applications/git-annex.app/Contents/MacOS/git", monitoredRepo: [])
        
        let actual = TurtleConfigV1.parse(from: config)
        
        XCTAssertNotNil(actual, "Config was nil")
        if let actualConfig = actual {
            XCTAssertEqual(expected, actualConfig)
        }
    }
    func testParseConfigTurtleSectionRepo() {
        let config: [String] = """
        [turtle-monitor]
        path = /therepo
        """.components(separatedBy: CharacterSet.newlines)
        
        let expected = TurtleConfigV1(gitAnnexBin: nil, gitBin: nil, monitoredRepo: [TurtleConfigMonitoredRepoV1(name: nil, path: "/therepo", finderIntegration: false, contextMenus: false, trackFolderStatus: false, trackFileStatus: false)])
        
        let actual = TurtleConfigV1.parse(from: config)
        
        XCTAssertNotNil(actual, "Config was nil")
        if let actualConfig = actual {
            XCTAssertEqual(expected, actualConfig)
        }
    }

    func testParseConfigEmpty() {
        let config: [String] = "   \n\t\t    \n \n   ".components(separatedBy: CharacterSet.newlines)
        let expected = TurtleConfigV1(gitAnnexBin: nil, gitBin: nil, monitoredRepo: [])
        let actual = TurtleConfigV1.parse(from: config)
        
        XCTAssertNotNil(actual, "Config was nil")
        if let actualConfig = actual {
            XCTAssertEqual(expected, actualConfig)
        }
    }
    
    func testParseConfigValid() {
        let config: [String] = """
        [turtle]
        git-annex-bin = /Applications/git-annex.app/Contents/MacOS/git-annex
        git-bin = /Applications/git-annex.app/Contents/MacOS/git
        
        [turtle-monitor "another remote yeah.hmm"]
        path = /Users/Shared/anotherremote
        finder-integration = true
        context-menus = true
        track-folder-status = true
        track-file-status = true
        [turtle-monitor]
        path = /Users/Shared/another remote2
        finder-integration = false
        context-menus = false
        track-folder-status = true
        track-file-status = true
        """.components(separatedBy: CharacterSet.newlines)
        
        let expected = TurtleConfigV1(gitAnnexBin: "/Applications/git-annex.app/Contents/MacOS/git-annex", gitBin: "/Applications/git-annex.app/Contents/MacOS/git", monitoredRepo: [TurtleConfigMonitoredRepoV1(name: "another remote yeah.hmm", path: "/Users/Shared/anotherremote", finderIntegration: true, contextMenus: true, trackFolderStatus: true, trackFileStatus: true),TurtleConfigMonitoredRepoV1(name: nil, path: "/Users/Shared/another remote2", finderIntegration: false, contextMenus: false, trackFolderStatus: true, trackFileStatus: true)])
        
        let actual = TurtleConfigV1.parse(from: config)
        
        XCTAssertNotNil(actual, "Config was nil")
        if let actualConfig = actual {
            XCTAssertEqual(expected, actualConfig)
        }
    }
    
    func testParseConfigInValid() {
        XCTAssertNil(TurtleConfigV1.parse(from: ["invalid configuration file"]))
    }
    
    func testConfigEmpty() {
        if let configDir = TestingUtil.createTmpDir() {
          let config = Config(dataPath: "\(configDir)/turtle-monitor")
          XCTAssertEqual(config.dataPath, "\(configDir)/turtle-monitor")
          return
        }
        XCTFail()
    }
    func testConfigWatchRepo() {
        let repo = "/anewrepo"
        if let configDir = TestingUtil.createTmpDir() {
            let config = Config(dataPath: "\(configDir)/turtle-monitor")
            XCTAssertTrue(config.watchRepo(repo: repo))
            XCTAssertEqual(config.listWatchedRepos(), [repo])
            return
        }
        XCTFail()
    }
    func testConfigWatchTwoRepos() {
        let repo1 = "/anewrepo"
        let repo2 = "/anewrepo2"
        
        if let configDir = TestingUtil.createTmpDir() {
            let config = Config(dataPath: "\(configDir)/turtle-monitor")
            XCTAssertTrue(config.watchRepo(repo: repo1))
            XCTAssertTrue(config.watchRepo(repo: repo2))
            
            XCTAssertEqual(Set(config.listWatchedRepos()), Set([repo1, repo2]))
            return
        }
        XCTFail()
    }
    func testConfigRemoveARepo() {
        let repo1 = "/anewrepo"
        let repo2 = "/anewrepo2"
        
        if let configDir = TestingUtil.createTmpDir() {
            let config = Config(dataPath: "\(configDir)/turtle-monitor")
            XCTAssertTrue(config.watchRepo(repo: repo1))
            XCTAssertTrue(config.watchRepo(repo: repo2))
            
            XCTAssertEqual(Set(config.listWatchedRepos()), Set([repo1, repo2]))
            
            XCTAssertTrue(config.stopWatchingRepo(repo: repo1))
            XCTAssertEqual(config.listWatchedRepos(), [repo2])

            return
        }
        XCTFail()
    }
    func testConfigGitBin() {
        if let configDir = TestingUtil.createTmpDir() {
            let config = Config(dataPath: "\(configDir)/turtle-monitor")
            XCTAssertTrue(config.setGitBin(gitBin: "/usr/bin/git"))
            XCTAssertEqual(config.gitBin(), "/usr/bin/git")
            return
        }
        XCTFail()
    }
    func testConfigGitAnnexBin() {
        if let configDir = TestingUtil.createTmpDir() {
            let config = Config(dataPath: "\(configDir)/turtle-monitor")
            XCTAssertTrue(config.setGitAnnexBin(gitAnnexBin: "/usr/bin/git-annex"))
            XCTAssertEqual(config.gitAnnexBin(), "/usr/bin/git-annex")
            return
        }
        XCTFail()
    }

    func testSortedByLongestPath() {
        let paths = ["a/a/b", "a", ".", "d/e", "a/b/c/d"]
        let sorted = PathUtils.sortedDeepestDirFirst(paths)
        XCTAssertEqual(sorted, ["a/b/c/d", "a/a/b", "d/e", "a", "."])
        
        let paths2 = [".", "a", "d/e", "a/b/c/d", "a/a/b"]
        let sorted2 = PathUtils.sortedDeepestDirFirst(paths2)
        XCTAssertEqual(sorted2, ["a/b/c/d", "a/a/b", "d/e", "a", "."])
    }
    
    func equalsT(_ tuple1:(Bool,String?),_ tuple2:(Bool,String?)) -> Bool {
        return (tuple1.0 == tuple2.0) && (tuple1.1 == tuple2.1)
    }
}
