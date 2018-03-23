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
    let absoluteURL: URL
    let absolutePath: String
    lazy var persistentContainer: NSPersistentContainer = {
        return DataEntrypoint.createPersistentContainer(absoluteURL: absoluteURL)
    }()
    
    init(persistentContainer: NSPersistentContainer, absolutePath: String) {
        self.absolutePath = absolutePath
        self.absoluteURL = PathUtils.urlFor(absolutePath: absolutePath)
        self.persistentContainer = persistentContainer
    }
    
    init() {
        // https://stackoverflow.com/a/42554741/8671834
        if let sharedGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID), let path = PathUtils.path(for: sharedGroupContainer) {
            absoluteURL = sharedGroupContainer
            absolutePath = path
        } else {
            TurtleLog.error("could not find group container and path for database")
            fatalError("error finding group container and path")
        }
    }
    
    private static func createPersistentContainer(absoluteURL: URL) -> NSPersistentContainer {
        let momdName = "git_annex_turtle_data"

        guard let model = Bundle(for: DataEntrypoint.self).url(forResource: momdName, withExtension:"momd") else {
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
        
        let storeURL = absoluteURL.appendingPathComponent(databaseName)
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
    
    @IBAction func saveAction(_ sender: AnyObject?) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        let context = persistentContainer.viewContext
        
        if !context.commitEditing() {
            TurtleLog.error("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
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
            TurtleLog.error("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
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
