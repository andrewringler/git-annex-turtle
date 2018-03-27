//
//  HandleGitQueries.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/26/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

enum PathSource {
    case gitlog
    case badgerequest
}
enum Priority {
    case low
    case high
}

protocol HandleStatusRequests {
    func updateStatusFor(for path: String, source: PathSource, isDir: Bool?, priority: Priority)
    
    func handlingRequests() -> Bool
}

class HandleStatusRequestsStub: HandleStatusRequests {
    func updateStatusFor(for path: String, source: PathSource, isDir: Bool?, priority: Priority) {
        // nothing
    }
    
    func handlingRequests() -> Bool {
        return false
    }
}
