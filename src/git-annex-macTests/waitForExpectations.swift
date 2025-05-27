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
    class func removeDir(_ absolutePath: String?, file: StaticString = #file, line: UInt = #line) {
        if let path = absolutePath {
            let directory = PathUtils.urlFor(absolutePath: path)
            do {
                // add write bit to all files recursively
                // since git-annex repos have write bit removed on annexed objects
                // see http://git-annex.branchable.com/internals/
                // otherwise we can't delete the directory with the removeItem command below
                let task = Process()
                task.launchPath = "/bin/chmod"
                task.currentDirectoryPath = path
                task.arguments = ["-R", "a+w", "."]
                task.launch()
                task.waitUntilExit()
                
                try FileManager.default.removeItem(at: directory)
            } catch {
                XCTFail("Unable to cleanup remove folder after tests folder=\(path)", file: file, line: line)
            }
            return
        }
        XCTFail("Invalid path, Unable to cleanup remove folder after tests", file: file, line: line)
    }
    
    class func createTmpDir(file: StaticString = #file, line: UInt = #line) -> String? {
        do {
            let directoryURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)!
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            if let path = PathUtils.path(for: directoryURL) {
                return path
            }
        } catch {
            XCTFail("unable to create a new temp folder \(error)", file: file, line: line)
            return nil
        }
        XCTFail("unable to create a new temp folder", file: file, line: line)
        return nil
    }
    
    class func createInitGitAnnexRepo(at path: String, gitAnnexQueries: GitAnnexQueries, file: StaticString = #file, line: UInt = #line) -> WatchedFolder? {
        do {
            let url = PathUtils.urlFor(absolutePath: path)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            XCTAssertTrue(gitAnnexQueries.createRepo(at: path), "could not initialize repository at \(path)", file: file, line: line)
            if let uuid = gitAnnexQueries.gitGitAnnexUUID(in: path) {
                return WatchedFolder(uuid: uuid, pathString: path)
            } else {
                XCTFail("could not retrieve UUID for folder \(path)", file: file, line: line)
            }
        } catch {
            XCTFail("unable to create a new git annex repo in temp folder \(error)", file: file, line: line)
        }
        return nil
    }
    
    class func createDirectorySpecialRemoteExportTree(watchedFolder watchedFolder: WatchedFolder, at specialRemotePath: String, named: String, gitAnnexQueries: GitAnnexQueries, file: StaticString = #file, line: UInt = #line) -> ExportTreeRemote? {
        do {
            let url = PathUtils.urlFor(absolutePath: specialRemotePath)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            let (success, _, _, _) = gitAnnexQueries.gitAnnexCommand(in: watchedFolder.pathString, cmd: CommandString.initRemote, with: "\(named) type=directory directory=\(specialRemotePath) encryption=none exporttree=yes", limitToMasterBranch: true)
            if success {
                return ExportTreeRemote(name: named, path: specialRemotePath)
            }
        } catch {
            XCTFail("could not add new special directory exporttree remote \(named) at '\(specialRemotePath)' to \(watchedFolder)", file: file, line: line)
        }
        XCTFail("could not add new special directory exporttree remote \(named) at '\(specialRemotePath)' to \(watchedFolder)", file: file, line: line)
        return nil
    }
    
    class func setDirectMode(for watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries, file: StaticString = #file, line: UInt = #line) {
        let addUnlocked = gitAnnexQueries.gitCommand(in: watchedFolder.pathString, cmd: CommandString.addUnlocked, limitToMasterBranch: false)
        if !addUnlocked.success { XCTFail("unable to switch to add unlocked mode \(addUnlocked.error)", file: file, line: line)}
        let thin = gitAnnexQueries.gitCommand(in: watchedFolder.pathString, cmd: CommandString.thin, limitToMasterBranch: false)
        if !thin.success { XCTFail("unable to switch to thin mode \(addUnlocked.error)", file: file, line: line)}
    }
    
    class func writeToFile(content: String, to fileName: String, in watchedFolder: WatchedFolder, file: StaticString = #file, line: UInt = #line) {
        let url = PathUtils.url(for: fileName, in: watchedFolder)
        do {
            try content.write(to: url, atomically: false, encoding: .utf8)
        }
        catch {
            XCTFail("unable to create file='\(fileName)' in repo \(watchedFolder)", file: file, line: line)
        }
    }
    
    class func readFile(from fileURL: URL, file: StaticString = #file, line: UInt = #line) -> String {
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        }
        catch {
            XCTFail("unable to read file='\(fileURL)'", file: file, line: line)
        }
        return ""
    }
    
    class func createSymlink(from fromRelativePath: String, to toRelativePath: String, in watchedFolder: WatchedFolder, file: StaticString = #file, line: UInt = #line) -> Bool {
        do {
            let fromAbsolutePath = PathUtils.absolutePath(for: fromRelativePath, in: watchedFolder)
            let toAbsolutePath = PathUtils.absolutePath(for: toRelativePath, in: watchedFolder)
            try FileManager.default.createSymbolicLink(atPath: fromAbsolutePath, withDestinationPath: toAbsolutePath)
            return true
        } catch {
            XCTFail("Unable to create symlink from=\(fromRelativePath) to=\(toRelativePath) in \(watchedFolder)", file: file, line: line)
            return false
        }
    }
    
    class func createSymlink(from fromAbsolutePath: String, to toAbsolutePath: String, file: StaticString = #file, line: UInt = #line) -> Bool {
        do {
            try FileManager.default.createSymbolicLink(atPath: fromAbsolutePath, withDestinationPath: toAbsolutePath)
            return true
        } catch {
            XCTFail("Unable to create symlink from=\(fromAbsolutePath) to=\(toAbsolutePath)", file: file, line: line)
            return false
        }
    }
    
    class func gitAnnexAdd(file: String, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries, sourcefile: StaticString = #file, sourceline: UInt = #line) {
        let gitAddResult = gitAnnexQueries.gitAnnexCommand(for: file, in: watchedFolder.pathString, cmd: CommandString.add, limitToMasterBranch: false)
        if !gitAddResult.success { XCTFail("unable to add file \(gitAddResult.error)", file: sourcefile, line: sourceline)}
    }

    class func gitCommit(_ commitMessage: String, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries, file: StaticString = #file, line: UInt = #line) {
        let result = gitAnnexQueries.gitCommit(in: watchedFolder.pathString, commitMessage: commitMessage, limitToMasterBranch: false)
        if !result.success { XCTFail("unable to git commit \(result.error)", file: file, line: line)}
    }

    static let maxThreads = 20
    class func createAndAddFiles(numFiles: Int, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries, file: StaticString = #file, line: UInt = #line) -> [String] {
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

    class func createDir(dir: String, in watchedFolder: WatchedFolder, file: StaticString = #file, line: UInt = #line) {
        do {
            let url = PathUtils.url(for: dir, in: watchedFolder)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Unable to create new directory '\(dir)' in \(watchedFolder)", file: file, line: line)
        }
    }
    
    class func createDir(absolutePath: String, file: StaticString = #file, line: UInt = #line) {
        do {
            let url = PathUtils.urlFor(absolutePath: absolutePath)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Unable to create new directory '\(absolutePath)'", file: file, line: line)
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
    
    func dialogGitAnnexWarn(title: String, message: String) {
        self.title = title
        self.message = message
        TurtleLog.info("title=\(title) message=\(message)")
    }
    func dialogOSWarn(title: String, message: String) {
        self.title = title
        self.message = message
        TurtleLog.info("title=\(title) message=\(message)")
    }
    func about() {}
}

class DialogTestingStubFailOnMessage: Dialogs {
    func dialogGitAnnexWarn(title: String, message: String) {
        XCTFail("title=\(title) message=\(message)")
    }
    func dialogOSWarn(title: String, message: String) {
        XCTFail("title=\(title) message=\(message)")
    }
    func about() {}
}
