//
//  ViewControllerProtocol.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 4/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

protocol ViewControllerProtocol {
    func updateGitAnnexBin(gitAnnexBin: String)
    func updateGitBin(gitBin: String)
    func reloadFileList()
}

class ViewControllerStub: ViewControllerProtocol {
    var updateGitAnnexBinCalled: String? = nil
    var updateGitBinCalled: String? = nil
    var reloadFileListCalled: Int = 0
    
    func updateGitAnnexBin(gitAnnexBin: String) {
        updateGitAnnexBinCalled = gitAnnexBin
    }
    
    func updateGitBin(gitBin: String) {
        updateGitBinCalled = gitBin
    }
    
    func reloadFileList() {
        reloadFileListCalled += 1
    }
}
