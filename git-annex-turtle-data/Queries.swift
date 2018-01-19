//
//  Queries.swift
//  git-annex-turtle-data
//
//  Created by Andrew Ringler on 1/16/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

//import Foundation
import Cocoa
import CoreData

let PathStatusEntityName = "PathStatus"
enum PathStatusAttributes: String {
    case watchedFolderUUIDString = "watchedFolderUUIDString"
    case statusString = "statusString"
    case pathString = "pathString"
    case modificationDate = "modificationDate"
}
let PathStatusAttributesAll = [PathStatusAttributes.watchedFolderUUIDString,PathStatusAttributes.statusString,PathStatusAttributes.pathString,PathStatusAttributes.modificationDate]

let WatchedFolderEntityName = "WatchedFolderEntity"
enum WatchedFolderEntityAttributes: String {
    case uuidString = "uuidString"
    case pathString = "pathString"
}
let WatchedFolderEntityAttributesAll = [WatchedFolderEntityAttributes.uuidString, WatchedFolderEntityAttributes.pathString]


class Queries {
    let data: DataEntrypoint
    
    init(data: DataEntrypoint) {
        self.data = data
    }
    
    // NOTE all CoreData operations must happen on the main thread
    // or in a private context
    // https://stackoverflow.com/questions/33562842/swift-coredata-error-serious-application-error-exception-was-caught-during-co/33566199
    // https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreData/Concurrency.html
    
    func updateStatusForPathBlocking(to status: Status, for path: String, in watchedFolder: 
        WatchedFolder) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            NSLog("updateStatus: to='\(status)' path='\(path)' in='\(watchedFolder.pathString)' ")
            
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == '\(path)'")
                let pathStatuses = try privateMOC.fetch(fetchRequest)
                if pathStatuses.count == 1, let pathStatus = pathStatuses.first  {
                    pathStatus.setValue(status.rawValue, forKeyPath: PathStatusAttributes.statusString.rawValue)
                    pathStatus.setValue(Date().timeIntervalSince1970 as Double, forKeyPath: PathStatusAttributes.modificationDate.rawValue)
                    try privateMOC.save()
                } else {
                    NSLog("Error, more than one record for path='\(path)'")
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        fatalError("Failure to save main context: \(error)")
                    }
                }
            } catch {
                fatalError("Failure to save private context: \(error)")
            }
        }
    }
    
    func addRequestAsync(for path: String, in watchedFolder: WatchedFolder) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.perform {
            NSLog("addRequest: path='\(path)' in='\(watchedFolder.pathString)' in Finder Sync")
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            
            do {
                // already there?
                fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == '\(path)'")
                let status = try privateMOC.fetch(fetchRequest)
                if status.count > 0 {
                    // path already here, nothing to do
                    return
                }
            } catch let error as NSError {
                NSLog("Could not fetch. \(error), \(error.userInfo)")
            }
            
            // insert request into Db
            if let entity = NSEntityDescription.entity(forEntityName: PathStatusEntityName, in: privateMOC) {
                let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                
                newPathRow.setValue(path, forKeyPath: PathStatusAttributes.pathString.rawValue)
                newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: PathStatusAttributes.watchedFolderUUIDString.rawValue)
                newPathRow.setValue(Date().timeIntervalSince1970 as Double, forKeyPath: PathStatusAttributes.modificationDate.rawValue)
                newPathRow.setValue(Status.request.rawValue, forKeyPath: PathStatusAttributes.statusString.rawValue)
            } else {
                NSLog("Could not create entity for \(PathStatusEntityName)")
            }
            do {
                try privateMOC.save()
                moc.perform {
                    do {
                        try moc.save()
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                }
            } catch {
                fatalError("Failure to save context: \(error)")
            }
        }
    }
    
    func statusForPathBlocking(path: String) -> Status? {
        var ret: Status?
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == '\(path)'")
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                if let firstStatus = statuses.first {
                    if let statusString = firstStatus.value(forKeyPath: "\(PathStatusAttributes.statusString.rawValue)") as? String {
                        ret = Status.status(from: statusString)
                    }
                }
            } catch {
                fatalError("Failure fetch statuses: \(error)")
            }
        }
        
        return ret
    }
    
    func allPathsNotHandledBlocking(in watchedFolder: WatchedFolder) -> [String] {
        var paths: [String] = []
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == '\(watchedFolder.uuid.uuidString)' && \(PathStatusAttributes.statusString) == '\(Status.request.rawValue)'")
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                
                for status in statuses {
                    if let pathString = status.value(forKeyPath: "\(PathStatusAttributes.pathString.rawValue)") as? String {
                        paths.append(pathString)
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch. \(error), \(error.userInfo)")
            }
        }
        
        return paths
    }
    
    func allPathsOlderThanBlocking(in watchedFolder: WatchedFolder, secondsOld: Double) -> [String] {
        var paths: [String] = []
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            let olderThan: Double = (Date().timeIntervalSince1970 as Double) - secondsOld
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == '\(watchedFolder.uuid.uuidString)' && \(PathStatusAttributes.modificationDate) <= \(olderThan)")
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                
                for status in statuses {
                    if let pathString = status.value(forKeyPath: "\(PathStatusAttributes.pathString.rawValue)") as? String {
                        paths.append(pathString)
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch allPathsOlderThan. \(error), \(error.userInfo)")
            }
        }
        
        return paths
    }
    
    func allNonRequestStatusesBlocking(in watchedFolder: WatchedFolder) -> [(path: String, status: String)] {
        var paths: [(path: String, status: String)] = []
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == '\(watchedFolder.uuid.uuidString)' && \(PathStatusAttributes.statusString) != '\(Status.request.rawValue)'")
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                
                for status in statuses {
                    if let pathString = status.value(forKeyPath: "\(PathStatusAttributes.pathString.rawValue)") as? String,
                        let statusString = status.value(forKeyPath: "\(PathStatusAttributes.statusString.rawValue)") as? String
                    {
                        paths.append((path: pathString, status: statusString))
                    } else {
                        NSLog("Could not retrieve path and status for entity '\(status)'")
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch allNonRequestStatuses. \(error), \(error.userInfo)")
            }
        }
        
        return paths
    }
    
    func allStatusesBlocking() -> [String] {
        var ret: [String] = []

        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            do {
                let statuses = try privateMOC.fetch(fetchRequest)

                for status in statuses {
                    if let pathString = status.value(forKeyPath: "\(PathStatusAttributes.pathString.rawValue)") as? String {
                        ret.append(pathString)
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch. \(error), \(error.userInfo)")
            }
        }

        return ret
    }
    
    func updateWatchedFoldersBlocking(to newListOfWatchedFolders: [WatchedFolder]) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: WatchedFolderEntityName)
            do {
                let currentWatchedFolders = try privateMOC.fetch(fetchRequest)
                
                // 1. Check for folders to remove from Db
                for watchedFolder in currentWatchedFolders {
                    var keep = false
                    if let uuidString = watchedFolder.value(forKeyPath: "\(WatchedFolderEntityAttributes.uuidString.rawValue)") as? String,
                        let pathString = watchedFolder.value(forKeyPath: "\(WatchedFolderEntityAttributes.pathString.rawValue)") as? String {
                        for folder in newListOfWatchedFolders {
                            if folder.uuid.uuidString == uuidString,
                                folder.pathString == pathString {
                                keep = true
                                break
                            }
                        }
                    }
                    if !keep {
                        // Remove the folder, it doesn't match the new item
                        privateMOC.delete(watchedFolder)
                    }
                }
                
                // 2. Check for folders to add to Db
                for folderToAdd in newListOfWatchedFolders {
                    var exists = false
                    for watchedFolder in currentWatchedFolders {
                        if let uuidString = watchedFolder.value(forKeyPath: "\(WatchedFolderEntityAttributes.uuidString.rawValue)") as? String,
                            let pathString = watchedFolder.value(forKeyPath: "\(WatchedFolderEntityAttributes.pathString.rawValue)") as? String
                        {
                            if folderToAdd.uuid.uuidString == uuidString,
                                folderToAdd.pathString == pathString {
                                exists = true
                                break
                            }
                        }
                    }
                    if !exists {
                        // Folder is not in database, add it
                        if let entity = NSEntityDescription.entity(forEntityName: WatchedFolderEntityName, in: privateMOC) {
                            let newWatchedFolderRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                            
                            newWatchedFolderRow.setValue(folderToAdd.pathString, forKeyPath: WatchedFolderEntityAttributes.pathString.rawValue)
                            newWatchedFolderRow.setValue(folderToAdd.uuid.uuidString, forKeyPath: WatchedFolderEntityAttributes.uuidString.rawValue)
                        } else {
                            NSLog("Could not create entity for adding new folder for \(WatchedFolderEntityName)")
                        }
                    }
                }
            } catch let error as NSError {
                NSLog("Could not update watched folders in Db \(newListOfWatchedFolders) \(error), \(error.userInfo)")
            }
            
            do {
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                }
            } catch {
                fatalError("Failure to save context: \(error)")
            }
        }
    }
    
    func allWatchedFoldersBlocking() -> Set<WatchedFolder> {
        var ret: Set<WatchedFolder> = Set()
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: WatchedFolderEntityName)
            do {
                let watchedFolders = try privateMOC.fetch(fetchRequest)
                
                for watchedFolder in watchedFolders {
                    if let pathString = watchedFolder.value(forKeyPath: "\(WatchedFolderEntityAttributes.pathString.rawValue)") as? String,
                        let uuidString = watchedFolder.value(forKeyPath: "\(WatchedFolderEntityAttributes.uuidString.rawValue)") as? String,
                        let uuid = UUID(uuidString: uuidString)
                    {
                        ret.insert(WatchedFolder(uuid: uuid, pathString: pathString))
                    } else {
                        NSLog("Unable to create watched folder item from database entity '\(watchedFolder)'")
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch allWatchedFolders. \(error), \(error.userInfo)")
            }
        }
        
        return ret
    }
}
