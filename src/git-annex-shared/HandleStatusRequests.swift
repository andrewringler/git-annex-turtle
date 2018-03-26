//
//  HandleGitQueries.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/26/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

enum Priority {
    case high
    case low
}

protocol HandleStatusRequests {
    func updateStatusFor(for path: String, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority)
    
    func handlingRequests() -> Bool
}

class HandleStatusRequestsStub: HandleStatusRequests {
    func updateStatusFor(for path: String, secondsOld: Double, includeFiles: Bool, includeDirs: Bool, priority: Priority) {
        // nothing
    }
    
    func handlingRequests() -> Bool {
        return false
    }
}
