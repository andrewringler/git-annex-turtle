//
//  CanRecheckGitCommitsAndFullScans.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 4/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

protocol CanRecheckGitCommitsAndFullScans {
    func recheckForGitCommitsAndFullScans()
}

class CanRecheckGitCommitsAndFullScansStub: CanRecheckGitCommitsAndFullScans {
    var recheckForGitCommitsAndFullScansCalled: Int = 0
    
    func recheckForGitCommitsAndFullScans() {
        recheckForGitCommitsAndFullScansCalled += 1
    }
}
