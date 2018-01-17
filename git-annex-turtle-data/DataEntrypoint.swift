//
//  DataEntrypoint.swift
//  git-annex-turtle-data
//
//  Created by Andrew Ringler on 1/16/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation
import Cocoa
import CoreData

class DataEntrypoint {
    static let groupID = "group.com.andrewringler.git-annex-mac.sharedgroup"
    public var copyModel = false
    
    // adapted from https://stackoverflow.com/questions/28708870/migrating-nspersistentstore-from-application-sandbox-to-shared-group-container
    public func moveDataStoreFromApplicationSandboxToSharedGroupContainer() {
        NSLog("moveDataStoreFromApplicationSandboxToSharedGroupContainer")
        let defaultContainer = containerAtDefaultLocation()
        let oldPersistentStoreCoordinator = defaultContainer.persistentStoreCoordinator
        if let oldStore = oldPersistentStoreCoordinator.persistentStores.first {
            let sharedGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DataEntrypoint.groupID)
            guard let newStoreURL = sharedGroupContainer?.appendingPathComponent("git_annex_turtle_data.sqlite") else {
                fatalError("Error loading model from bundle")
            }

            do {
                let oldStorePath = oldStore.url?.absoluteString ?? ""
                let newPath = PathUtils.path(for: newStoreURL) ?? ""
                let msg = "moving store to '\(newPath)' from '\(oldStorePath)'"
                NSLog(msg)
                try oldPersistentStoreCoordinator.migratePersistentStore(oldStore, to: newStoreURL, withType: NSSQLiteStoreType)
            } catch {
                let nserror = error as NSError
                NSLog("Error migrating datastore \(nserror)")
            }

        } else {
            NSLog("Error no store found!")
        }
    }

    private func containerAtDefaultLocation() -> NSPersistentContainer {
        // https://stackoverflow.com/a/42554741/8671834
        let momdName = "git_annex_turtle_data"
        guard let model = Bundle(for: type(of: self)).url(forResource: momdName, withExtension:"momd") else {
            fatalError("Error loading default model from bundle")
        }
        guard let mom = NSManagedObjectModel(contentsOf: model) else {
            fatalError("Error initializing mom from: \(model)")
        }
        
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
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

    lazy var persistentContainer: NSPersistentContainer = {
        // https://stackoverflow.com/a/42554741/8671834
        let momdName = "git_annex_turtle_data"
        guard let model = Bundle(for: type(of: self)).url(forResource: momdName, withExtension:"momd") else {
            fatalError("Error loading default model from bundle")
        }
        guard let mom = NSManagedObjectModel(contentsOf: model) else {
            fatalError("Error initializing mom from: \(model)")
        }
        
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
        // https://useyourloaf.com/blog/easier-core-data-setup-with-persistent-containers/

        let sharedGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DataEntrypoint.groupID)
        guard let newStoreURL = sharedGroupContainer?.appendingPathComponent("git_annex_turtle_data.sqlite") else {
            fatalError("Error loading model from bundle")
        }
        let description = NSPersistentStoreDescription(url: newStoreURL)
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
    }()
    
//    lazy var persistentContainer: NSPersistentContainer = {
//        // https://stackoverflow.com/a/42554741/8671834
//        let momdName = "git_annex_turtle_data"
//        guard let model = Bundle(for: type(of: self)).url(forResource: momdName, withExtension:"momd") else {
//            fatalError("Error loading default model from bundle")
//        }
//        guard let mom = NSManagedObjectModel(contentsOf: model) else {
//            fatalError("Error initializing mom from: \(model)")
//        }
//
//        /*
//         The persistent container for the application. This implementation
//         creates and returns a container, having loaded the store for the
//         application to it. This property is optional since there are legitimate
//         error conditions that could cause the creation of the store to fail.
//         */
//        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
//
//        let sharedGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DataEntrypoint.groupID)
//        guard let storeURLInSharedGroupContainer = sharedGroupContainer?.appendingPathComponent("git_annex_turtle_data.sqlite") else {
//            fatalError("Error loading model from bundle")
//        }
//        let oldStores = container.persistentStoreCoordinator.persistentStores
//        for oldStore in oldStores {
//            var oldStorePath = PathUtils.path(for: oldStore.url!) ?? ""
//            NSLog("removing old store '\(oldStorePath)'")
//            try! container.persistentStoreCoordinator.remove(oldStore)
//        }
//
////        container.persistentStoreCoordinator.remove
//        try! container.persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: "git_annex_turtle_data", at: storeURLInSharedGroupContainer)
//        var pathForUrl = PathUtils.path(for: storeURLInSharedGroupContainer) ?? ""
//        NSLog("add persistent store at '\(pathForUrl)'")
////        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
////            if let error = error {
////                // Replace this implementation with code to handle the error appropriately.
////                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
////
////                /*
////                 Typical reasons for an error here include:
////                 * The parent directory does not exist, cannot be created, or disallows writing.
////                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
////                 * The device is out of space.
////                 * The store could not be migrated to the current model version.
////                 Check the error message to determine what the actual problem was.
////                 */
////                fatalError("Unresolved error \(error)")
////            }
////        })
//        return container
//    }()
    
//    lazy var persistentContainer: NSPersistentContainer = {
//        // https://stackoverflow.com/a/42554741/8671834
//        let momdName = "git_annex_turtle_data"
//
//        // a new location of database inside our shared container
//        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DataEntrypoint.groupID)
//        guard let newModelURL = containerURL?.appendingPathComponent("git_annex_turtle_data.sqlite") else {
//            fatalError("Error loading model from bundle")
//        }
//
////        if self.copyModel {
////            // sqlite database container folder created by XCode
////            guard let modelURLCreatedByXcode = Bundle(for: type(of: self)).url(forResource: momdName, withExtension:"momd") else {
////                fatalError("Error loading default model from bundle")
////            }
////
////            // copy the database, if we haven't already
////            if containerURL != nil, let path = PathUtils.path(for: newModelURL) {
////                // https://gist.github.com/brennanMKE/a0a2ee6aa5a2e2e66297c580c4df0d66
////                var isDirectory = ObjCBool(true)
////                let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
////
////                if exists == false {
////                    try! FileManager().copyItem(at: modelURLCreatedByXcode, to: newModelURL)
////                }
////            }
////        }
//
//        /*
//         let sharedContainerURL :NSURL? = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier("group.etc.etc")  // replace "group.etc.etc" with your App Group's identifier
//         NSLog("sharedContainerURL = \(sharedContainerURL)")
//         if let sourceURL :NSURL = sharedContainerURL?.URLByAppendingPathComponent("store.sqlite")
//         {
//         if let destinationURL :NSURL = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0].URLByAppendingPathComponent("copyOfStore.sqlite")
//         {
//         try! NSFileManager().copyItemAtURL(sourceURL, toURL: destinationURL)
//         }
//         }
// */
//
//
//        guard let mom = NSManagedObjectModel(contentsOf: newModelURL) else {
//            fatalError("Error initializing mom from: \(newModelURL)")
//        }
//
//        /*
//         The persistent container for the application. This implementation
//         creates and returns a container, having loaded the store for the
//         application to it. This property is optional since there are legitimate
//         error conditions that could cause the creation of the store to fail.
//         */
////        NSPersistentContainer(
//        let container = NSPersistentContainer(name: momdName, managedObjectModel: mom)
//        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
//            if let error = error {
//                // Replace this implementation with code to handle the error appropriately.
//                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//
//                /*
//                 Typical reasons for an error here include:
//                 * The parent directory does not exist, cannot be created, or disallows writing.
//                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
//                 * The device is out of space.
//                 * The store could not be migrated to the current model version.
//                 Check the error message to determine what the actual problem was.
//                 */
//                fatalError("Unresolved error \(error)")
//            }
//        })
//        return container
//    }()
    
    // MARK: - Core Data Saving and Undo support
    
    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Customize this code block to include application-specific recovery steps.
                let nserror = error as NSError
//                NSApplication.shared.presentError(nserror)
            }
        }
    }
    
    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return persistentContainer.viewContext.undoManager
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !context.hasChanges {
            return .terminateNow
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            
            // Customize this code block to include application-specific recovery steps.
//            let result = sender.presentError(nserror)
//            if (result) {
//                return .terminateCancel
//            }
//
//            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
//            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
//            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
//            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
//            let alert = NSAlert()
//            alert.messageText = question
//            alert.informativeText = info
//            alert.addButton(withTitle: quitButton)
//            alert.addButton(withTitle: cancelButton)
//
//            let answer = alert.runModal()
//            if answer == .alertSecondButtonReturn {
//                return .terminateCancel
//            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }
}
