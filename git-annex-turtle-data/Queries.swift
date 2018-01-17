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

//let appDelegate: DataEntrypoint? = nil

class Queries {
    let data: DataEntrypoint
    
    init(data: DataEntrypoint) {
        self.data = data
    }
    
    func addRequest(for path: String, in watchedFolder: WatchedFolder) {
        // async, doesn't really matter when this gets done
        DispatchQueue.main.async {
            NSLog("addRequest: path='\(path)' in='\(watchedFolder.pathString)' in Finder Sync")
            let managedContext = self.data.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            
            do {
                // already there?
                fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == '\(path)'")
                let status = try managedContext.fetch(fetchRequest)
                if status.count > 0 {
                    // path already here, nothing to do
                    return
                }
            } catch let error as NSError {
                NSLog("Could not fetch. \(error), \(error.userInfo)")
            }
            
            do {
                // insert request into Db
                if let entity = NSEntityDescription.entity(forEntityName: PathStatusEntityName, in: managedContext) {
                    let newPathRow = NSManagedObject(entity: entity, insertInto: managedContext)
                    
                    newPathRow.setValue(path, forKeyPath: PathStatusAttributes.pathString.rawValue)
                    newPathRow.setValue(watchedFolder.uuid.uuidString, forKeyPath: PathStatusAttributes.watchedFolderUUIDString.rawValue)
                    //                newPathRow.setValue(Date(), forKeyPath: PathStatusAttributes.modificationDate.rawValue)
                    newPathRow.setValue("request t", forKeyPath: PathStatusAttributes.statusString.rawValue)
                    
                    try managedContext.save()
                } else {
                    NSLog("Could not create entity for \(PathStatusEntityName)")
                }
            } catch let error as NSError {
                NSLog("Could not save. \(error), \(error.userInfo)")
            }
        }
    }
    
    func statusForPath(path: String) -> Status? {
        var ret: Status?
        
        DispatchQueue.main.sync {
            let managedContext = data.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.pathString) == '\(path)'")
            do {
                let statuses = try managedContext.fetch(fetchRequest)
                if let firstStatus = statuses.first {
                    if let statusString = firstStatus.value(forKeyPath: "\(PathStatusAttributes.statusString.rawValue)") as? String {
                        ret = Status.status(from: statusString)
                    }
                }
            } catch let error as NSError {
                NSLog("Could not fetch. \(error), \(error.userInfo)")
            }
        }
        
        return ret
    }
    
    func allStatusesNotHandled(in watchedFolder: WatchedFolder) -> [String] {
        var ret: [String] = []
        // TODO
        // https://stackoverflow.com/questions/33562842/swift-coredata-error-serious-application-error-exception-was-caught-during-co/33566199
        // there are other options if we don't want to be on the main thread
        DispatchQueue.main.sync {
            let managedContext = data.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            fetchRequest.predicate = NSPredicate(format: "\(PathStatusAttributes.watchedFolderUUIDString) == '\(watchedFolder.uuid.uuidString)'")
            do {
                let statuses = try managedContext.fetch(fetchRequest)
                
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
    
    func allStatuses() -> [String] {
        var ret: [String] = []
        
        DispatchQueue.main.sync {
            let managedContext = self.data.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: PathStatusEntityName)
            do {
                let statuses = try managedContext.fetch(fetchRequest)
                
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
}
