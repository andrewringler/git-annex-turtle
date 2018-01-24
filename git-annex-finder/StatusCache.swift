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
    private let pathStringToPathStatusCache = NSCache<NSString, PathStatus>()
    let data: DataEntrypoint
    
    init(data: DataEntrypoint) {
        self.data = data
        pathStringToPathStatusCache.countLimit = 1000
    }
    
    func get(for path: String) -> PathStatus? {
        // In cache? Return it
        if let status = pathStringToPathStatusCache.object(forKey: path as NSString) as PathStatus? {
            return status
        }
        return nil // no where to be found
    }
    
    func getAndCheckDb(for path: String) -> PathStatus? {
        // In cache? Return it
        if let status = pathStringToPathStatusCache.object(forKey: path as NSString) as PathStatus? {
            return status
        }
        // Cache miss, In db? Add to cache and return it
        let queries = Queries(data: data)
        if let status = queries.statusForPathV2Blocking(path: path) {
            put(status: status, for: path)
            return status
        }
        
        return nil // no where to be found
    }
    
    func put(status: PathStatus, for path: String) {
        pathStringToPathStatusCache.setObject(status, forKey: path as NSString)
    }
}
