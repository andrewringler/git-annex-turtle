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
let UpdatesEntityName = "UpdatesEntity"
enum UpdatesEntityAttributes: String {
    case lastModified = "lastModified"
}
let CommandRequestsName = "CommandRequests"
enum CommandRequestsAttributes: String {
    case watchedFolderUUIDString = "watchedFolderUUIDString"
    case commandString = "commandString"
    case commandType = "commandType"
    case pathString = "pathString"
}
struct GitOrGitAnnexCommand {
    let commandType: CommandType
    let commandString: CommandString
    
    public static func git(_ commandString: CommandString) -> GitOrGitAnnexCommand {
        return GitOrGitAnnexCommand(commandType: CommandType.git, commandString: commandString)
    }
    public static func gitAnnex(_ commandString: CommandString) -> GitOrGitAnnexCommand{
        return GitOrGitAnnexCommand(commandType: CommandType.gitAnnex, commandString: commandString)
    }
}

struct CommandRequest {
    let commandString: CommandString
    let commandType: CommandType
    let pathString: String
    let watchedFolderUUIDString: String
    
    init(for path: String, in watchedFolderUUIDString: String, commandType: CommandType, commandString: CommandString) {
        self.pathString = path
        self.watchedFolderUUIDString = watchedFolderUUIDString
        self.commandType = commandType
        self.commandString = commandString
    }
}

let VisibleFoldersEntityName = "VisibleFoldersEntity"
enum VisibleFoldersEntityAttributes: String {
    case pathString = "pathString"
    case watchedFolderParentUUIDString = "watchedFolderParentUUIDString"
}


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
                } else {
                    NSLog("Error, more than one record for path='\(path)'")
                }
                
                try changeLastModifedUpdatesStub(lastModified:Date().timeIntervalSince1970 as Double, in: privateMOC)
                
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
                try changeLastModifedUpdatesStub(lastModified:Date().timeIntervalSince1970 as Double, in: privateMOC)
                
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
    
    func timeOfMoreRecentUpdatesBlocking(lastHandled: Double) -> Double? {
        var ret: Double? = nil
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: UpdatesEntityName)
            do {
                let result = try privateMOC.fetch(fetchRequest)
                if result.count == 1, let lastModified = result.first?.value(forKeyPath: "\(UpdatesEntityAttributes.lastModified.rawValue)") as? Double {
                    if (lastModified-lastHandled) > 0.001 {
                        ret = lastModified
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch allPathsOlderThan. \(error), \(error.userInfo)")
            }
        }
        
        return ret
    }
    
    private func changeLastModifedUpdatesStub(lastModified: Double, in privateMOC: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: UpdatesEntityName)
        let results = try privateMOC.fetch(fetchRequest)
        if results.count > 0, let result = results.first  {
            result.setValue(lastModified, forKeyPath: UpdatesEntityAttributes.lastModified.rawValue)
        }else if results.count == 0 {
            // Add new record
            if let entity = NSEntityDescription.entity(forEntityName: UpdatesEntityName, in: privateMOC) {
                let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                
                newPathRow.setValue(lastModified, forKeyPath: UpdatesEntityAttributes.lastModified.rawValue)
            } else {
                NSLog("Could not create entity for \(PathStatusEntityName)")
            }
        } else {
            NSLog("Error, invalid results from fetch '\(results)'")
        }
    }
    
    func changeLastModifedUpdatesSync(lastModified: Double) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                try changeLastModifedUpdatesStub(lastModified: lastModified, in: privateMOC)
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
    
    func submitCommandRequest(for path: String, in watchedFolder: WatchedFolder, commandType: CommandType, commandString: CommandString) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                if let entity = NSEntityDescription.entity(forEntityName: CommandRequestsName, in: privateMOC) {
                    let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                    
                    newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: CommandRequestsAttributes.watchedFolderUUIDString.rawValue)
                    newPathRow.setValue(commandString.rawValue, forKeyPath: CommandRequestsAttributes.commandString.rawValue)
                    newPathRow.setValue(commandType.rawValue, forKeyPath: CommandRequestsAttributes.commandType.rawValue)
                    newPathRow.setValue(path, forKeyPath: CommandRequestsAttributes.pathString.rawValue)

                } else {
                    NSLog("Could not create entity for \(PathStatusEntityName)")
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
    
    func fetchAndDeleteCommandRequestsBlocking() -> [(CommandRequest)] {
        var ret: [(CommandRequest)] = []
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: CommandRequestsName)
            do {
                let results = try privateMOC.fetch(fetchRequest)
                for result in results {
                    if let watchedFolderUUIDString = result.value(forKeyPath: "\(CommandRequestsAttributes.watchedFolderUUIDString.rawValue)") as? String,
                        let commandStringRaw = result.value(forKeyPath: "\(CommandRequestsAttributes.commandString.rawValue)") as? String,
                        let commandString = CommandString(rawValue: commandStringRaw),
                        let commandTypeString = result.value(forKeyPath: "\(CommandRequestsAttributes.commandType.rawValue)") as? String,
                        let commandType = CommandType(rawValue: commandTypeString),
                        let pathString = result.value(forKeyPath: "\(CommandRequestsAttributes.pathString.rawValue)") as? String
                    {
                        ret.append(CommandRequest(for: pathString, in: watchedFolderUUIDString, commandType: commandType, commandString: commandString))
                    } else {
                        NSLog("Unable to parse results from fetch for command request '\(result)'")
                    }
                }
                
                // OK, presumably we will now handle these requests, delete all of these records
                // TODO should put a timestamp on a request so it happens soon or not at all?
                for result in results {
                    privateMOC.delete(result)
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        fatalError("Failure to save main context: \(error)")
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch allWatchedFolders. \(error), \(error.userInfo)")
            }
        }
        
        return ret
    }

    func removeVisibleFolderAsync(for path: String) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.perform {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: VisibleFoldersEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(VisibleFoldersEntityAttributes.pathString.rawValue) == '\(path)'")
                let results = try privateMOC.fetch(fetchRequest)
                for result in results {
                    privateMOC.delete(result)
                }
                
                try privateMOC.save()
                moc.perform {
                    do {
                        try moc.save()
                    } catch {
                        fatalError("removeVisibleFolderAsync: failure to save main context: \(error)")
                    }
                }
            } catch {
                fatalError("removeVisibleFolderAsync: failure to save private context: \(error)")
            }
        }
    }
    
    func getVisibleFoldersBlocking() -> [(path: String, watchedFolderParentUUID: String)] {
        var ret: [(path: String, watchedFolderParentUUID: String)] = []
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: VisibleFoldersEntityName)
                let results = try privateMOC.fetch(fetchRequest)
                for result in results {
                    if let watchedFolderParentUUID = result.value(forKeyPath: VisibleFoldersEntityAttributes.watchedFolderParentUUIDString.rawValue) as? String,
                        let path = result.value(forKeyPath: VisibleFoldersEntityAttributes.pathString.rawValue) as? String
                    {
                        ret.append((path: path, watchedFolderParentUUID: watchedFolderParentUUID))
                    }
                }
            } catch {
                fatalError("getVisibleFoldersBlocking: failure in fetch: \(error)")
            }
        }
        
        return ret
    }
    
    func addVisibleFolderAsync(for path: String, in watchedFolder: WatchedFolder) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        moc.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // http://dorianroy.com/blog/2015/09/how-to-implement-unique-constraints-in-core-data-with-ios-9/
        privateMOC.parent = moc
        privateMOC.perform {
            do {
                if let entity = NSEntityDescription.entity(forEntityName: VisibleFoldersEntityName, in: privateMOC) {
                    let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                    
                    newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: VisibleFoldersEntityAttributes.watchedFolderParentUUIDString.rawValue)
                    newPathRow.setValue(path, forKeyPath: VisibleFoldersEntityAttributes.pathString.rawValue)
                    
                } else {
                    NSLog("addVisibleFolderAsync: could not create entity for \(VisibleFoldersEntityName)")
                }
                
                try privateMOC.save()
                moc.perform {
                    do {
                        try moc.save()
                    } catch {
                        fatalError("addVisibleFolderAsync: failure to save main context: \(error)")
                    }
                }
            } catch {
                fatalError("addVisibleFolderAsync: failure to save private context: \(error)")
            }
        }
    }
}
