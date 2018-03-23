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
                TurtleLog.error("Unable to cleanup folder after tests \(path)")
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
    
    class func gitAnnexAdd(file: String, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries) {
        let gitAddResult = gitAnnexQueries.gitAnnexCommand(for: file, in: watchedFolder.pathString, cmd: CommandString.add)
        if !gitAddResult.success { XCTFail("unable to add file \(gitAddResult.error)")}
    }

    class func gitCommit(_ commitMessage: String, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries) {
        let result = gitAnnexQueries.gitCommit(in: watchedFolder.pathString, commitMessage: commitMessage)
        if !result.success { XCTFail("unable to git commit \(result.error)")}
    }

    static let maxThreads = 20
    class func createAndAddFiles(numFiles: Int, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries) -> [String] {
        // create subfolders
        createDir(dir: "a", in: watchedFolder)
        createDir(dir: "b", in: watchedFolder)
        createDir(dir: "c", in: watchedFolder)
        
        // enumate file names
        let files: [String] = Array(1...numFiles).map {
            let folder: String = {
                switch $0 % 4 {
                case 0:
                    return "a/"
                case 1:
                    return "b/"
                case 2:
                    return "c/"
                default:
                    return "" // root
                }
            }($0)
            return "\(folder)file-\($0).txt"
        }
        let queue = DispatchQueue(label: "com.andrewringler.git-annexmac.testing-\(watchedFolder.uuid.uuidString)", attributes: .concurrent)
        let maxConcurrency = DispatchSemaphore(value: maxThreads)
        let group = DispatchGroup()
        
        for file in files {
            maxConcurrency.wait()
            group.enter()
            queue.async {
                writeToFile(content: "\(file) content", to: file, in: watchedFolder)
                group.leave()
                maxConcurrency.signal()
            }
        }
        
        group.wait()
        gitAnnexAdd(file: ".", in: watchedFolder, gitAnnexQueries: gitAnnexQueries)
        
        return files
    }
    
    class func gitAnnexCreateAndAdd(content: String, to fileName: String, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries) {
        writeToFile(content: content, to: fileName, in: watchedFolder)
        gitAnnexAdd(file: fileName, in: watchedFolder, gitAnnexQueries: gitAnnexQueries)
    }
    
    class func createDir(dir: String, in watchedFolder: WatchedFolder) {
        do {
            let url = PathUtils.url(for: dir, in: watchedFolder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            TurtleLog.error("Unable to create new directory '\(dir)' in \(watchedFolder)")
        }
    }
    
    class func createDir(absolutePath: String) {
        do {
            let url = PathUtils.urlFor(absolutePath: absolutePath)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            TurtleLog.error("Unable to create new directory '\(absolutePath)'")
        }
    }
    
    class func persistentContainer(mom: NSManagedObjectModel, storeURL: URL) -> NSPersistentContainer {
        let momdName = "git_annex_turtle_data"
        
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
        // https://useyourloaf.com/blog/easier-core-data-setup-with-persistent-containers/
        // https://stackoverflow.com/a/42554741/8671834
        let description = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error)")
            }
        })
        return container
    }
}

// https://stackoverflow.com/a/30593673/8671834
extension Collection {
    
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// https://stackoverflow.com/a/42222302/8671834
extension XCTestCase {
    /* since tests run on the main thread
     * any waiting should be done on a different thread
     * so that we don't block processes we are trying to test, that depend on
     * the main thread being available, such as File System Events API
     */
    func wait(for duration: TimeInterval) {
        let waitExpectation = expectation(description: "Waiting")
        
        let when = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: when) {
            waitExpectation.fulfill()
        }
        
        // We use a buffer here to avoid flakiness with Timer on CI
        waitForExpectations(timeout: duration + 0.5)
    }
}

class DialogTestingStubCheckMessages: Dialogs {
    var title: String?
    var message: String?
    
    func dialogOK(title: String, message: String) {
        self.title = title
        self.message = message
        TurtleLog.info("title=\(title) message=\(message)")
    }
    func about() {}
}

class DialogTestingStubFailOnMessage: Dialogs {
    func dialogOK(title: String, message: String) {
        XCTFail("title=\(title) message=\(message)")
    }
    func about() {}
}
