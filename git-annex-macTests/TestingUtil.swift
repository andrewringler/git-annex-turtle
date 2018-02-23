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
    
    class func gitAnnexAdd(file: String, in watchedFolder: WatchedFolder, gitAnnexQueries: GitAnnexQueries) {
        let gitAddResult = gitAnnexQueries.gitAnnexCommand(for: file, in: watchedFolder.pathString, cmd: CommandString.add)
        if !gitAddResult.success { XCTFail("unable to add file \(gitAddResult.error)")}
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
            NSLog("Unable to create new directory '\(dir)' in \(watchedFolder)")
        }
    }
    
    // https://medium.com/flawless-app-stories/cracking-the-tests-for-core-data-15ef893a3fee
//    class func persistentContainer(managedObjectModel: NSManagedObjectModel) -> NSPersistentContainer {
//        let container = NSPersistentContainer(name: "git_annex_turtle_data", managedObjectModel: managedObjectModel)
//        let description = NSPersistentStoreDescription()
//        description.type = NSInMemoryStoreType
//        description.shouldAddStoreAsynchronously = false // Make it simpler in test env
//
//        container.persistentStoreDescriptions = [description]
//        container.loadPersistentStores { (description, error) in
//            // Check if the data store is in memory
//            precondition( description.type == NSInMemoryStoreType )
//
//            // Check if creating container wrong
//            if let error = error {
//                fatalError("Create an in-mem coordinator failed \(error)")
//            }
//        }
//        return container
//    }
    
    class func persistentContainer(mom: NSManagedObjectModel, storeURL: URL) -> NSPersistentContainer {
//        let container = NSPersistentContainer(name: "git_annex_turtle_data", managedObjectModel: managedObjectModel)
//        let description = NSPersistentStoreDescription()
//        description.type = NSInMemoryStoreType
//        description.shouldAddStoreAsynchronously = false // Make it simpler in test env
//
//        container.persistentStoreDescriptions = [description]
//        container.loadPersistentStores { (description, error) in
//            // Check if the data store is in memory
//            precondition( description.type == NSInMemoryStoreType )
//
//            // Check if creating container wrong
//            if let error = error {
//                fatalError("Create an in-mem coordinator failed \(error)")
//            }
//        }
//        return container
        let momdName = "git_annex_turtle_data"
        
//        guard let mom = NSManagedObjectModel(contentsOf: managedObjectModel) else {
//            fatalError("Error initializing mom from: \(managedObjectModel)")
//        }
        
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
        // https://useyourloaf.com/blog/easier-core-data-setup-with-persistent-containers/
        
        // https://stackoverflow.com/a/42554741/8671834
//        let sharedGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
//        guard let storeURL = sharedGroupContainer?.appendingPathComponent(databaseName) else {
//            fatalError("Error loading model from bundle")
//        }
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
