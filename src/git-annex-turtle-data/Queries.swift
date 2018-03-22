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

let HandledCommitEntityName = "HandledCommitEntity"
enum HandledCommitAttributes: String {
    case watchedFolderUUIDString = "watchedFolderUUIDString"
    case gitAnnexCommitHash = "gitAnnexCommitHash"
    case gitCommitHash = "gitCommitHash"
}
let NO_COMMIT_HASH = "-"

let PathStatusEntityName = "PathStatusEntity"
enum PathStatusAttributes: String {
    case watchedFolderUUIDString = "watchedFolderUUIDString"
    case pathString = "pathString"
    case modificationDate = "modificationDate"
    case enoughCopiesStatus = "enoughCopiesStatus"
    case isGitAnnexTracked = "isGitAnnexTracked"
    case numberOfCopies = "numberOfCopies"
    case presentStatus = "presentStatus"
    case gitAnnexKey = "gitAnnexKey"
    case isDir = "isDir"
    case needsUpdate = "needsUpdate"
    case parentPath = "parentPath"
}

let PathRequestEntityName = "PathRequestEntity"
enum PathRequestEntityAttributes: String {
    case watchedFolderUUIDString = "watchedFolderUUIDString"
    case pathString = "pathString"
}


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
let CommandRequestsName = "CommandRequestsEntity"
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
    case processID = "processID"
}

// HACK
// TIME_OFFSET, makes queries claim they were updated after they already were
// this sort-of ensures that Finder will always get newly updated file status
// but, this will also cause them to sometimes grab the same status multiple times
// TODO: re-design threading assumptions in Queries and remove this
let TIME_OFFSET: Double = 0.2
class Queries {
    let data: DataEntrypoint
    let lastModifiedQueue = DispatchQueue(label: "git-annex-turtle.Queries-Last-Modified", attributes: .concurrent)
    public lazy var updateLastModifiedAsync = {
        return debounce(delay: .milliseconds(50), queue: lastModifiedQueue, action: self.changeLastModifedUpdatesSync)
    }()
    
    init(data: DataEntrypoint) {
        self.data = data
    }
    
    private func changeLastModifedUpdatesSync() {
        let modificationDate = Date().timeIntervalSince1970 as Double
        changeLastModifedUpdatesSync(lastModified: modificationDate)
    }
    
    // NOTE all CoreData operations must happen on the main thread
    // or in a private context, then merged back into the main context (from any thread)
    // https://stackoverflow.com/questions/33562842/swift-coredata-error-serious-application-error-exception-was-caught-during-co/33566199
    // https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CoreData/Concurrency.html
    func updateStatusForPathV2Blocking(presentStatus: Present?, enoughCopies: EnoughCopies?, numberOfCopies: UInt8?, isGitAnnexTracked: Bool, for path: String, key: String?, in watchedFolder:
        WatchedFolder, isDir: Bool, needsUpdate: Bool) {
        let modificationDate = Date().timeIntervalSince1970 as Double + TIME_OFFSET
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        moc.mergePolicy = NSOverwriteMergePolicy
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                // insert or update
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString.rawValue) == %@ && \(PathStatusAttributes.watchedFolderUUIDString.rawValue) == %@", path, watchedFolder.uuid.uuidString)
                let pathStatuses = try privateMOC.fetch(fetchRequest)
                var entry: NSManagedObject? = nil
                if pathStatuses.count > 0 {
                    entry = pathStatuses.first!
                } else {
                    // No path status entry yet, this is our first update for this path
                    if let entity = NSEntityDescription.entity(forEntityName: PathStatusEntityName, in: privateMOC) {
                        entry = NSManagedObject(entity: entity, insertInto: privateMOC)
                    } else {
                        TurtleLog.error("Could not create entity for \(PathStatusEntityName)")
                        return
                    }
                }
                
                if let pathStatus = entry {
                    pathStatus.setValue(modificationDate, forKeyPath: PathStatusAttributes.modificationDate.rawValue)
                    
                    pathStatus.setValue(path, forKeyPath: PathStatusAttributes.pathString.rawValue)
                    pathStatus.setValue(watchedFolder.uuid.uuidString, forKeyPath: PathStatusAttributes.watchedFolderUUIDString.rawValue)
                    pathStatus.setValue(enoughCopies?.rawValue, forKeyPath: PathStatusAttributes.enoughCopiesStatus.rawValue)
                    pathStatus.setValue(numberOfCopiesAsDouble(from: numberOfCopies), forKeyPath: PathStatusAttributes.numberOfCopies.rawValue)
                    pathStatus.setValue(presentStatus?.rawValue, forKeyPath: PathStatusAttributes.presentStatus.rawValue)
                    pathStatus.setValue(NSNumber(value: isGitAnnexTracked), forKeyPath: PathStatusAttributes.isGitAnnexTracked.rawValue)
                    pathStatus.setValue(key, forKeyPath: PathStatusAttributes.gitAnnexKey.rawValue)
                    pathStatus.setValue(NSNumber(value: isDir), forKeyPath: PathStatusAttributes.isDir.rawValue)
                    pathStatus.setValue(NSNumber(value: needsUpdate), forKeyPath: PathStatusAttributes.needsUpdate.rawValue)
                    let parent = PathUtils.parent(for: path, in: watchedFolder)
                    pathStatus.setValue(parent, forKeyPath: PathStatusAttributes.parentPath.rawValue)
                    
                } else {
                    TurtleLog.error("could not create/update entity for \(PathStatusEntityName)")
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                        self.updateLastModifiedAsync()
                    } catch {
                        TurtleLog.fatal("could not save main context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for path: \(path), key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
                        fatalError("could not save main context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for path: \(path), key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for path: \(path), key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
                fatalError("could not save private context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for path: \(path), key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
            }
        }
    }
    
    // Skip checks to see if path is already in DB since this
    // is triggered from a fullscan, assume we have no entries
    func updateStatusForDirectoryPathsV2BatchBlocking(presentStatus: Present?, enoughCopies: EnoughCopies?, numberOfCopies: UInt8?, isGitAnnexTracked: Bool, for paths: [String], key: String?, in watchedFolder:
        WatchedFolder, isDir: Bool, needsUpdate: Bool) -> Bool {
        let modificationDate = Date().timeIntervalSince1970 as Double
        var success = true
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        moc.mergePolicy = NSOverwriteMergePolicy
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                for path in paths {
                    if let entity = NSEntityDescription.entity(forEntityName: PathStatusEntityName, in: privateMOC) {
                        let pathStatus = NSManagedObject(entity: entity, insertInto: privateMOC)
                        pathStatus.setValue(modificationDate, forKeyPath: PathStatusAttributes.modificationDate.rawValue)
                        
                        pathStatus.setValue(path, forKeyPath: PathStatusAttributes.pathString.rawValue)
                        pathStatus.setValue(watchedFolder.uuid.uuidString, forKeyPath: PathStatusAttributes.watchedFolderUUIDString.rawValue)
                        pathStatus.setValue(enoughCopies?.rawValue, forKeyPath: PathStatusAttributes.enoughCopiesStatus.rawValue)
                        pathStatus.setValue(numberOfCopiesAsDouble(from: numberOfCopies), forKeyPath: PathStatusAttributes.numberOfCopies.rawValue)
                        pathStatus.setValue(presentStatus?.rawValue, forKeyPath: PathStatusAttributes.presentStatus.rawValue)
                        pathStatus.setValue(NSNumber(value: isGitAnnexTracked), forKeyPath: PathStatusAttributes.isGitAnnexTracked.rawValue)
                        pathStatus.setValue(key, forKeyPath: PathStatusAttributes.gitAnnexKey.rawValue)
                        pathStatus.setValue(NSNumber(value: isDir), forKeyPath: PathStatusAttributes.isDir.rawValue)
                        pathStatus.setValue(NSNumber(value: needsUpdate), forKeyPath: PathStatusAttributes.needsUpdate.rawValue)
                        let parent = PathUtils.parent(for: path, in: watchedFolder)
                        pathStatus.setValue(parent, forKeyPath: PathStatusAttributes.parentPath.rawValue)
                    } else {
                        TurtleLog.error("could not create entity for \(PathStatusEntityName)")
                        success = false
                        return
                    }
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                        self.updateLastModifiedAsync()
                    } catch {
                        TurtleLog.fatal("could not save main context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for paths: \(paths.first)…, key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
                        fatalError("could not save main context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for paths: \(paths.first)…, key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for paths: \(paths.first)…, key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")
                fatalError("could not save private context presentStatus: \(presentStatus), enoughCopies: \(enoughCopies), numberOfCopies: \(numberOfCopies), isGitAnnexTracked: \(isGitAnnexTracked), for paths: \(paths.first)…, key: \(key), in watchedFolder: \(watchedFolder) isDir: \(isDir), needsUpdate: \(needsUpdate) \(error)")            }
        }
        return success
    }
    
    func addRequestV2Async(for path: String, in watchedFolder: WatchedFolder) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        moc.mergePolicy = NSOverwriteMergePolicy
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.perform {
            if let entity = NSEntityDescription.entity(forEntityName: PathRequestEntityName, in: privateMOC) {
                let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                
                newPathRow.setValue(path, forKeyPath: PathRequestEntityAttributes.pathString.rawValue)
                newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: PathRequestEntityAttributes.watchedFolderUUIDString.rawValue)
            } else {
                TurtleLog.error("could not create entity for \(PathRequestEntityName)")
            }
            do {
                try privateMOC.save()
                moc.perform {
                    do {
                        try moc.save()
                    } catch {
                        TurtleLog.fatal("could not save main context path=\(path) \(watchedFolder) \(error)")
                        fatalError("could not save main context path=\(path) \(watchedFolder) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context path=\(path) \(watchedFolder) \(error)")
                fatalError("could not save private context path=\(path) \(watchedFolder) \(error)")
            }
        }
    }
    
    func statusForPathV2Blocking(path: String, in watchedFolder: WatchedFolder) -> PathStatus? {
        var ret: PathStatus?
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == %@ && \(PathRequestEntityAttributes.watchedFolderUUIDString) == %@", path, watchedFolder.uuid.uuidString)
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                if let status = statuses.first {
                    // required properties
                    if let watchedFolderUUIDString = status.value(forKeyPath: PathStatusAttributes.watchedFolderUUIDString.rawValue) as? String,
                        let isGitAnnexTracked = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.isGitAnnexTracked.rawValue) as? NSNumber),
                        let modificationDate = status.value(forKeyPath: PathStatusAttributes.modificationDate.rawValue) as? Double,
                        let isDir = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.isDir.rawValue) as? NSNumber),
                        let needsUpdate = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.needsUpdate.rawValue) as? NSNumber)
                    {
                        
                        // optional properties
                        let key = status.value(forKeyPath: PathStatusAttributes.gitAnnexKey.rawValue) as? String
                        let enoughCopies = EnoughCopies(rawValue: status.value(forKeyPath: PathStatusAttributes.enoughCopiesStatus.rawValue) as? String ?? "NO MATCH")
                        let numberOfCopies = numberOfCopiesAsUInt8(status.value(forKeyPath: PathStatusAttributes.numberOfCopies.rawValue) as? Double)
                        let presentStatus = Present(rawValue: status.value(forKeyPath: PathStatusAttributes.presentStatus.rawValue) as? String ?? "NO MATCH")
                        
                        ret = PathStatus(isDir: isDir, isGitAnnexTracked: isGitAnnexTracked, presentStatus: presentStatus, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: key, needsUpdate: needsUpdate)
                    } else {
                        TurtleLog.error("unable to fetch entry for status=\(status) path=\(path) \(watchedFolder)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not fetch statuses path=\(path) \(watchedFolder) \(error)")
                fatalError("could not fetch statuses path=\(path) \(watchedFolder) \(error)")
            }
        }
        
        return ret
    }
    
    func allPathRequestsV2Blocking(in watchedFolder: WatchedFolder) -> [String] {
        var paths: [String] = []
        
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathRequestEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathRequestEntityAttributes.watchedFolderUUIDString) == %@", watchedFolder.uuid.uuidString)
            do {
                let results = try privateMOC.fetch(fetchRequest)
                
                for result in results {
                    if let pathString = result.value(forKeyPath: "\(PathRequestEntityAttributes.pathString.rawValue)") as? String {
                        paths.append(pathString)
                    }
                }
                
                // OK, presumably we will now handle these requests, delete all of them
                // TODO, wait to delete them until they are actually handled properly?
                for result in results {
                    privateMOC.delete(result)
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        TurtleLog.fatal("could not save main context for \(watchedFolder) \(error)")
                        fatalError("could not save main context for \(watchedFolder) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context for \(watchedFolder) \(error)")
                fatalError("could not save private context for \(watchedFolder) \(error)")
            }
        }
        
        return paths
    }
    
    func allVisibleStatusesV2Blocking(in watchedFolder: WatchedFolder, processID: String) -> [PathStatus] {
        var paths: [PathStatus] = []
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                // Fetch visible folders for folder and Finder Sync Extension process ID
                let fetchVisibleFolders = NSFetchRequest<NSManagedObject>(entityName: VisibleFoldersEntityName)
                fetchVisibleFolders.predicate = NSPredicate(format: "\(VisibleFoldersEntityAttributes.watchedFolderParentUUIDString.rawValue) == %@ && \(VisibleFoldersEntityAttributes.processID.rawValue) == %@", watchedFolder.uuid.uuidString, processID)

                let visibleFolders = try privateMOC.fetch(fetchVisibleFolders)
                
                // Fetch Status for all visible folders
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
                var predicates: [NSPredicate] = []
//                predicates.append(NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == %@", watchedFolder.uuid.uuidString))

                for visibleFolder in visibleFolders {
                    if let path = visibleFolder.value(forKeyPath: VisibleFoldersEntityAttributes.pathString.rawValue) as? String {
                        // Grab all children of this folder
                        predicates.append(NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString.rawValue) == %@ && \(PathStatusAttributes.parentPath.rawValue) == %@", watchedFolder.uuid.uuidString, path))
                        // Grab the folder itself
                        predicates.append(NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString.rawValue) == %@ && \(PathStatusAttributes.pathString.rawValue) == %@", watchedFolder.uuid.uuidString, path))
                    }
                }
                // Always fetch the root folder itself, since Finder Sync extensions don't tell us if the root
                // folder icon is in view (since it is contained in a folder we aren't watching
                predicates.append(NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString.rawValue) == %@ && \(PathStatusAttributes.pathString.rawValue) == %@", watchedFolder.uuid.uuidString, PathUtils.CURRENT_DIR))
                
                fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

                let statuses = try privateMOC.fetch(fetchRequest)
                for status in statuses {
                    // required properties
                    if let path = status.value(forKeyPath: PathStatusAttributes.pathString.rawValue) as? String,
                        let isGitAnnexTracked = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.isGitAnnexTracked.rawValue) as? NSNumber),
                        let modificationDate = status.value(forKeyPath: PathStatusAttributes.modificationDate.rawValue) as? Double,
                        let isDir = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.isDir.rawValue) as? NSNumber),
                        let needsUpdate = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.needsUpdate.rawValue) as? NSNumber)
                    {
                        
                        // optional properties
                        let key = status.value(forKeyPath: PathStatusAttributes.gitAnnexKey.rawValue) as? String
                        let enoughCopies = EnoughCopies(rawValue: status.value(forKeyPath: PathStatusAttributes.enoughCopiesStatus.rawValue) as? String ?? "NO MATCH")
                        let numberOfCopies = numberOfCopiesAsUInt8(status.value(forKeyPath: PathStatusAttributes.numberOfCopies.rawValue) as? Double)
                        let presentStatus = Present(rawValue: status.value(forKeyPath: PathStatusAttributes.presentStatus.rawValue) as? String ?? "NO MATCH")
                        
                        paths.append(PathStatus(isDir: isDir, isGitAnnexTracked: isGitAnnexTracked, presentStatus: presentStatus, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: key, needsUpdate: needsUpdate))
                    } else {
                        TurtleLog.error("unable to fetch entry for status=\(status) for \(watchedFolder) pid=\(processID)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not fetch for \(watchedFolder) pid=\(processID) \(error)")
                fatalError("could not fetch for \(watchedFolder) pid=\(processID) \(error)")
            }
        }
        
        return paths
    }
    
    func foldersIncompleteOrInvalidBlocking(in watchedFolder: WatchedFolder) -> [String] {
        var paths: [String] = []
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString.rawValue) == %@ && \(PathStatusAttributes.isDir.rawValue) == \(NSNumber(value: true)) && \(PathStatusAttributes.needsUpdate.rawValue) == \(NSNumber(value: true))", watchedFolder.uuid.uuidString)
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                for status in statuses {
                    // required properties
                    if let path = status.value(forKeyPath: PathStatusAttributes.pathString.rawValue) as? String
                    {
                        paths.append(path)
                    } else {
                        TurtleLog.error("unable to fetch entry for status=\(status)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not fetch for \(watchedFolder) \(error)")
                fatalError("could not fetch for \(watchedFolder) \(error)")
            }
        }
        
        return paths
    }
    
    func childStatusesOfBlocking(parentRelativePath: String, in watchedFolder: WatchedFolder) -> [PathStatus] {
        var paths: [PathStatus] = []
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == %@ && \(PathStatusAttributes.parentPath.rawValue) == %@", watchedFolder.uuid.uuidString, parentRelativePath)
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                for status in statuses {
                    // required properties
                    if let path = status.value(forKeyPath: PathStatusAttributes.pathString.rawValue) as? String,
                        let isGitAnnexTracked = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.isGitAnnexTracked.rawValue) as? NSNumber),
                        let modificationDate = status.value(forKeyPath: PathStatusAttributes.modificationDate.rawValue) as? Double,
                        let isDir = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.isDir.rawValue) as? NSNumber),
                        let needsUpdate = nsNumberAsBoolOrNil(status.value(forKeyPath: PathStatusAttributes.needsUpdate.rawValue) as? NSNumber)
                    {
                        
                        // optional properties
                        let key = status.value(forKeyPath: PathStatusAttributes.gitAnnexKey.rawValue) as? String
                        let enoughCopies = EnoughCopies(rawValue: status.value(forKeyPath: PathStatusAttributes.enoughCopiesStatus.rawValue) as? String ?? "NO MATCH")
                        let numberOfCopies = numberOfCopiesAsUInt8(status.value(forKeyPath: PathStatusAttributes.numberOfCopies.rawValue) as? Double)
                        let presentStatus = Present(rawValue: status.value(forKeyPath: PathStatusAttributes.presentStatus.rawValue) as? String ?? "NO MATCH")
                        
                        paths.append(PathStatus(isDir: isDir, isGitAnnexTracked: isGitAnnexTracked, presentStatus: presentStatus, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: key, needsUpdate: needsUpdate))
                    } else {
                        TurtleLog.error("unable to fetch entry for status=\(status)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not fetch statuses \(error)")
                fatalError("childStatusesOf: Failure fetch statuses: \(error)")
            }
        }
        
        return paths
    }
    
    func allNonTrackedPathsBlocking(in watchedFolder: WatchedFolder) -> [String] {
        var paths: [String] = []
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString.rawValue) == %@ && \(PathStatusAttributes.isGitAnnexTracked.rawValue) == \(NSNumber(value: false))", watchedFolder.uuid.uuidString)
            do {
                let results = try privateMOC.fetch(fetchRequest)
                for result in results {
                    // required properties
                    if let path = result.value(forKeyPath: PathStatusAttributes.pathString.rawValue) as? String {
                        
                        paths.append(path)
                    } else {
                        TurtleLog.error("unable to parse result in \(watchedFolder)")
                    }
                }
            } catch {
                TurtleLog.fatal("failure to fetch statuses in \(watchedFolder) \(error)")
                fatalError("failure to fetch statuses in \(watchedFolder) \(error)")
            }
        }
        
        return paths
    }
    
    func pathsWithStatusesGivenAnnexKeysBlocking(keys: [String], in watchedFolder: WatchedFolder) -> [String] {
        var paths: [String] = []
        
        if keys.count < 1 {
            return []
        }
        
        let moc = data.persistentContainer.viewContext
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            
            // https://stackoverflow.com/questions/25159240/core-data-predicate-check-if-any-element-in-array-matches-any-element-in-anoth
            // https://stackoverflow.com/questions/36602226/nspredicate-to-return-items-with-properties-contained-in-arrays
            
            var predicates: [NSPredicate] = []
            for key in keys {
                predicates.append(NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == %@ && \(PathStatusAttributes.gitAnnexKey.rawValue) == %@", watchedFolder.uuid.uuidString, key))
            }
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            
            do {
                let statuses = try privateMOC.fetch(fetchRequest)
                for status in statuses {
                    // required properties
                    if let path = status.value(forKeyPath: PathStatusAttributes.pathString.rawValue) as? String {
                        paths.append(path)
                    } else {
                        TurtleLog.error("unable to parse result for keys \(keys) in \(watchedFolder)")
                    }
                }
            } catch {
                TurtleLog.fatal("failure to fetch paths \(error) for keys \(keys) in \(watchedFolder)")
                fatalError("failure to fetch paths \(error) for keys \(keys) in \(watchedFolder)")
            }
        }
        
        return paths
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
                            TurtleLog.error("Could not create entity for adding new folder for \(WatchedFolderEntityName)")
                        }
                    }
                }
            } catch let error as NSError {
                TurtleLog.error("Could not update watched folders in Db \(newListOfWatchedFolders) \(error), \(error.userInfo)")
            }
            
            do {
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                        self.updateLastModifiedAsync()
                    } catch {
                        TurtleLog.fatal("could not save main context for \(newListOfWatchedFolders) \(error)")
                        fatalError("could not save main context for \(newListOfWatchedFolders) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context for \(newListOfWatchedFolders) \(error)")
                fatalError("could not save private context for \(newListOfWatchedFolders) \(error)")
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
                        TurtleLog.error("Unable to create watched folder item from database entity '\(watchedFolder)'")
                    }
                }
            } catch {
                TurtleLog.error("Could not fetch allWatchedFolders \(error)")
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
            } catch {
                TurtleLog.error("Could not fetch allPathsOlderThan. \(error)")
            }
        }
        
        return ret
    }
    
    func changeLastModifedUpdatesSync(lastModified: Double) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
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
                        TurtleLog.error("Could not create entity for \(PathStatusEntityName)")
                    }
                } else {
                    TurtleLog.error("Error, invalid results from fetch '\(results)'")
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        TurtleLog.fatal("could not save main context lastModified=\(lastModified) \(error)")
                        fatalError("could not save main context lastModified=\(lastModified) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context lastModified=\(lastModified) \(error)")
                fatalError("could not save private context lastModified=\(lastModified) \(error)")
            }
        }
    }
    
    func updateLatestHandledCommit(gitCommitHash: String?, gitAnnexCommitHash: String?, in watchedFolder: WatchedFolder) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let gitCommitHashDb = gitCommitHash != nil ? gitCommitHash! : NO_COMMIT_HASH
        let gitAnnexCommitHashDb = gitAnnexCommitHash != nil ? gitAnnexCommitHash! : NO_COMMIT_HASH
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: HandledCommitEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(HandledCommitAttributes.watchedFolderUUIDString.rawValue) == %@", watchedFolder.uuid.uuidString)
                
                let results = try privateMOC.fetch(fetchRequest)
                if results.count > 0, let result = results.first  {
                    result.setValue(gitCommitHashDb, forKeyPath: HandledCommitAttributes.gitCommitHash.rawValue)
                    result.setValue(gitAnnexCommitHashDb, forKeyPath: HandledCommitAttributes.gitAnnexCommitHash.rawValue)
                } else if results.count == 0 {
                    // Add new record
                    if let entity = NSEntityDescription.entity(forEntityName: HandledCommitEntityName, in: privateMOC) {
                        let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                        
                        newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: HandledCommitAttributes.watchedFolderUUIDString.rawValue)
                        newPathRow.setValue(gitCommitHashDb, forKeyPath: HandledCommitAttributes.gitCommitHash.rawValue)
                        newPathRow.setValue(gitAnnexCommitHashDb, forKeyPath: HandledCommitAttributes.gitAnnexCommitHash.rawValue)
                    } else {
                        TurtleLog.error("Could not create entity for \(HandledCommitEntityName) in \(watchedFolder) gitAnnexCommitHash='\(gitAnnexCommitHash)' gitCommitHash='\(gitCommitHash)' in \(watchedFolder)")
                    }
                } else {
                    TurtleLog.error("Error, invalid results from fetch results='\(results)' \(HandledCommitEntityName) in \(watchedFolder) gitAnnexCommitHash='\(gitAnnexCommitHash)' gitCommitHash='\(gitCommitHash)'")
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        TurtleLog.fatal("could not save main context gitCommitHash=\(gitCommitHash)  gitAnnexCommitHash=\(gitAnnexCommitHash) in \(watchedFolder) \(error)")
                        fatalError("could not save main context gitCommitHash=\(gitCommitHash)  gitAnnexCommitHash=\(gitAnnexCommitHash) in \(watchedFolder) \(error)")

                        fatalError("Failure to save main context: \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context gitCommitHash=\(gitCommitHash)  gitAnnexCommitHash=\(gitAnnexCommitHash) in \(watchedFolder) \(error)")
                fatalError("could not save private context gitCommitHash=\(gitCommitHash)  gitAnnexCommitHash=\(gitAnnexCommitHash) in \(watchedFolder) \(error)")
            }
        }
    }
    
    func getLatestCommits(for watchedFolder: WatchedFolder) -> (gitCommitHash: String?, gitAnnexCommitHash: String?) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        var ret: (gitCommitHash: String?, gitAnnexCommitHash: String?) = (gitCommitHash: nil, gitAnnexCommitHash: nil)
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: HandledCommitEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(HandledCommitAttributes.watchedFolderUUIDString.rawValue) == %@", watchedFolder.uuid.uuidString)
                
                let results = try privateMOC.fetch(fetchRequest)
                if results.count > 0, let result = results.first,
                    let gitCommitHash = result.value(forKeyPath: HandledCommitAttributes.gitCommitHash.rawValue) as? String,
                    let gitAnnexCommitHash = result.value(forKeyPath: HandledCommitAttributes.gitAnnexCommitHash.rawValue) as? String
                {
                    let gitCommitHashOptional: String? = gitCommitHash != NO_COMMIT_HASH ? gitCommitHash : nil
                    let gitAnnexCommitHashOptional: String? = gitAnnexCommitHash != NO_COMMIT_HASH ? gitAnnexCommitHash : nil
                    ret = (gitCommitHash: gitCommitHashOptional, gitAnnexCommitHash: gitAnnexCommitHashOptional)
                }
            } catch {
                TurtleLog.fatal("Failure to get results in private context for \(watchedFolder): \(error)")
                fatalError("Failure to get results in private context for \(watchedFolder): \(error)")
            }
        }
        
        return ret
    }
    
    func invalidateDirectory(path: String, in watchedFolder: WatchedFolder) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.performAndWait {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == %@ && \(PathRequestEntityAttributes.watchedFolderUUIDString) == %@", path, watchedFolder.uuid.uuidString)
                let results = try privateMOC.fetch(fetchRequest)
                if results.count > 0, let result = results.first  {
                    result.setValue(NSNumber(value: true), forKeyPath: PathStatusAttributes.needsUpdate.rawValue)
                } else {
                    TurtleLog.error("unable to update entry for path=\(path) in \(watchedFolder) ")
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        TurtleLog.fatal("could not save main context path=\(path) in \(watchedFolder) \(error)")
                        fatalError("could not save main context path=\(path) in \(watchedFolder) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context path=\(path) in \(watchedFolder) \(error)")
                fatalError("could not save private context path=\(path) in \(watchedFolder) \(error)")
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
                    TurtleLog.error("Could not create entity for \(PathStatusEntityName)")
                }
                
                try privateMOC.save()
                moc.performAndWait {
                    do {
                        try moc.save()
                    } catch {
                        TurtleLog.fatal("could not save main context path=\(path) in \(watchedFolder) commandType=\(commandType) commandString=\(commandString) \(error)")
                        fatalError("could not save main context path=\(path) in \(watchedFolder) commandType=\(commandType) commandString=\(commandString) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context path=\(path) in \(watchedFolder) commandType=\(commandType) commandString=\(commandString) \(error)")
                fatalError("could not save private context path=\(path) in \(watchedFolder) commandType=\(commandType) commandString=\(commandString) \(error)")
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
                        TurtleLog.error("Unable to parse results from fetch for command request '\(result)'")
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
                        TurtleLog.fatal("could not save main context \(error)")
                        fatalError("could not save main context \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context \(error)")
                fatalError("could not save private context \(error)")
            }
        }
        
        return ret
    }
    
    func removeVisibleFolderAsync(for path: String, in watchedFolder: WatchedFolder, processID: String) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateMOC.parent = moc
        privateMOC.perform {
            do {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: VisibleFoldersEntityName)
                fetchRequest.predicate = NSPredicate(format: "\(VisibleFoldersEntityAttributes.pathString.rawValue) == %@ && \(VisibleFoldersEntityAttributes.watchedFolderParentUUIDString.rawValue) == %@ && \(VisibleFoldersEntityAttributes.processID.rawValue) == %@", path, watchedFolder.uuid.uuidString, processID)
                let results = try privateMOC.fetch(fetchRequest)
                for result in results {
                    privateMOC.delete(result)
                }
                
                try privateMOC.save()
                moc.perform {
                    do {
                        try moc.save()
                        // we do not need to update last modified flag
                        // since Finder Sync extensions do not need to do anything
                        // if a folder is no longer visible
                    } catch {
                        TurtleLog.fatal("could not save main context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
                        fatalError("could not save main context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
                fatalError("could not save private context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
            }
        }
    }
    
    func getVisibleFoldersBlocking(with watchedFolders: Set<WatchedFolder>) -> Set<VisibleFolder> {
        var ret = Set<VisibleFolder>()
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
                        for watchedFolder in watchedFolders {
                            if watchedFolder.uuid.uuidString == watchedFolderParentUUID {
                                ret.insert(VisibleFolder(relativePath: path, parent: watchedFolder))
                            }
                        }
                    }
                }
            } catch {
                TurtleLog.fatal("could not get results \(watchedFolders) \(error)")
                fatalError("could not get results \(watchedFolders) \(error)")
            }
        }

        return ret
    }
    
    func addVisibleFolderAsync(for path: String, in watchedFolder: WatchedFolder, processID: String) {
        let moc = data.persistentContainer.viewContext
        moc.stalenessInterval = 0
        moc.mergePolicy = NSOverwriteMergePolicy
        
        let privateMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // http://dorianroy.com/blog/2015/09/how-to-implement-unique-constraints-in-core-data-with-ios-9/
        privateMOC.parent = moc
        privateMOC.perform {
            do {
                if let entity = NSEntityDescription.entity(forEntityName: VisibleFoldersEntityName, in: privateMOC) {
                    let newPathRow = NSManagedObject(entity: entity, insertInto: privateMOC)
                    
                    newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: VisibleFoldersEntityAttributes.watchedFolderParentUUIDString.rawValue)
                    newPathRow.setValue(path, forKeyPath: VisibleFoldersEntityAttributes.pathString.rawValue)
                    newPathRow.setValue(processID, forKeyPath: VisibleFoldersEntityAttributes.processID.rawValue)
                } else {
                    TurtleLog.error("could not create entity for \(VisibleFoldersEntityName)")
                }
                
                try privateMOC.save()
                moc.perform {
                    do {
                        try moc.save()
                        self.updateLastModifiedAsync()
                    } catch {
                        TurtleLog.fatal("could not save main context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
                        fatalError("could not save main context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
                    }
                }
            } catch {
                TurtleLog.fatal("could not save private context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
                fatalError("could not save private context path=\(path) \(watchedFolder) pid=\(processID) \(error)")
            }
        }
    }
    
    func addAllMissingParentFolders(for path: String, in watchedFolder: WatchedFolder) -> [String]? {
        var foldersToAdd: [String] = []
        var parent = PathUtils.parent(for: path, in: watchedFolder)
        while parent != nil, PathUtils.isCurrent(parent!) == false {
            if statusForPathV2Blocking(path: parent!, in: watchedFolder) == nil {
                // folder has no entry, enqueue for addition
                foldersToAdd.append(parent!)
            }
            parent = PathUtils.parent(for: parent!, in: watchedFolder)
        }
        
        if foldersToAdd.count > 0 {
            if updateStatusForDirectoryPathsV2BatchBlocking(presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, isGitAnnexTracked: true, for: foldersToAdd, key: nil, in: watchedFolder, isDir: true, needsUpdate: true) {
                return foldersToAdd
            } else {
                return nil
            }
        } else {
            return []
        }
    }
    
    private func numberOfCopiesAsUInt8(_ num: Double?) -> UInt8? {
        if let numVal: Double = num {
            if numVal < 0 {
                return nil
            }
            return UInt8(truncating: NSNumber(value: numVal))
        }
        return nil
    }
    
    private func numberOfCopiesAsDouble(from valueOptional: UInt8?) -> Double {
        if let value = valueOptional {
            return Double(value)
        }
        return UNKNOWN_COPIES
    }
    
    private func nsNumberAsBoolOrNil(_ val: NSNumber?) -> Bool? {
        if let actualVal = val {
            return Bool(truncating: actualVal)
        }
        return nil
    }
}
