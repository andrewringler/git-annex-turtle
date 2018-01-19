//
//  StatusCache.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 1/18/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class StatusCache {
    // NSCache is thread safe
    private let pathStringToStatusStringCache = NSCache<NSString, NSString>()
    let data: DataEntrypoint
    
    init(data: DataEntrypoint) {
        self.data = data
        pathStringToStatusStringCache.countLimit = 1000
    }
    
    func get(for path: String) -> Status? {
        // In cache? Return it
        if let status = pathStringToStatusStringCache.object(forKey: path as NSString) as String? {
            return Status.status(from: status)
        }
        return nil // no where to be found
    }
    
    func getAndCheckDb(for path: String) -> Status? {
        // In cache? Return it
        if let status = pathStringToStatusStringCache.object(forKey: path as NSString) as String? {
            return Status.status(from: status)
        }
        // Cache miss, In db? Add to cache and return it
        let queries = Queries(data: data)
        if let status = queries.statusForPathBlocking(path: path) {
            put(status: status, for: path)
            return status
        }
        
        return nil // no where to be found
    }
    
    func put(status: Status, for path: String) {
        pathStringToStatusStringCache.setObject(status.rawValue as NSString, forKey: path as NSString)
    }
    
    func put(statusString: String, for path: String) {
        pathStringToStatusStringCache.setObject(statusString as NSString, forKey: path as NSString)
    }
}
