//
//  TestingUtil.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 2/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation
import XCTest

class TestingUtil {
    class func removeDir(_ absolutePath: String?) {
        if let path = absolutePath {
            let directory = PathUtils.urlFor(absolutePath: path)
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                NSLog("Unable to cleanup folder after tests \(path)")
            }
        }
    }
    
    class func createTmpDir() -> String? {
        do {
            let directoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)!
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            if let path = PathUtils.path(for: directoryURL) {
                return path
            }
        } catch {
            XCTFail("unable to create a new temp folder \(error)")
            return nil
        }
        XCTFail("unable to create a new temp folder")
        return nil
    }
    
    class func createInitGitAnnexRepo(at path: String, gitAnnexQueries: GitAnnexQueries) -> WatchedFolder? {
        do {
            let url = PathUtils.urlFor(absolutePath: path)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            XCTAssertTrue(gitAnnexQueries.createRepo(at: path), "could not initialize repository at \(path)")
            if let uuid = gitAnnexQueries.gitGitAnnexUUID(in: path) {
                return WatchedFolder(uuid: uuid, pathString: path)
            } else {
                XCTFail("could not retrieve UUID for folder \(path)")
            }
        } catch {
            XCTFail("unable to create a new git annex repo in temp folder \(error)")
        }
        return nil
    }
    
    class func writeToFile(content: String, to fileName: String, in watchedFolder: WatchedFolder) {
        let url = PathUtils.url(for: fileName, in: watchedFolder)
        do {
            try content.write(to: url, atomically: false, encoding: .utf8)
        }
        catch {
            XCTFail("unable to create file='\(fileName)' in repo \(watchedFolder)")
        }
    }
    
    class func createDir(dir: String, in watchedFolder: WatchedFolder) {
        do {
            let url = PathUtils.url(for: dir, in: watchedFolder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("Unable to create new directory '\(dir)' in \(watchedFolder)")
        }
    }
}
