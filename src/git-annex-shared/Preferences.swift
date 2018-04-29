//
//  Preferences.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 4/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Cocoa
import Foundation

fileprivate enum Paths: NSString {
    case gitBin = "gitBin"
    case gitAnnexBin = "gitAnnexBin"
}

class Preferences {
    // NSCache is thread safe
    private let paths = NSCache<NSString, NSString>()
    var preferencesViewController: ViewControllerProtocol? = nil
    var canRecheckGitCommitsAndFullScans: CanRecheckGitCommitsAndFullScans? = nil
    
    public init(gitBin: String?, gitAnnexBin: String?) {
        if gitBin != nil, !gitBin!.isEmpty {
            paths.setObject(gitBin! as NSString, forKey: Paths.gitBin.rawValue)
        }
        if gitAnnexBin != nil, !gitAnnexBin!.isEmpty {
            paths.setObject(gitAnnexBin! as NSString, forKey: Paths.gitAnnexBin.rawValue)
        }
    }
    
    public func setGitBin(gitBin: String) {
        if !gitBin.isEmpty {
            paths.setObject(gitBin as NSString, forKey: Paths.gitBin.rawValue)
            preferencesViewController?.updateGitBin(gitBin: gitBin)
            canRecheckGitCommitsAndFullScans?.recheckForGitCommitsAndFullScans()
        }
    }

    public func setGitAnnexBin(gitAnnexBin: String) {
        if !gitAnnexBin.isEmpty {
            paths.setObject(gitAnnexBin as NSString, forKey: Paths.gitAnnexBin.rawValue)
            preferencesViewController?.updateGitAnnexBin(gitAnnexBin: gitAnnexBin)
            canRecheckGitCommitsAndFullScans?.recheckForGitCommitsAndFullScans()
        }
    }

    public func gitBin() -> String? {
        if let gitBin: NSString = paths.object(forKey: Paths.gitBin.rawValue) {
            return gitBin as String
        }
        return nil
    }
    public func gitAnnexBin() -> String? {
        if let gitAnnexBin: NSString = paths.object(forKey: Paths.gitAnnexBin.rawValue) {
            return gitAnnexBin as String
        }
        return nil
    }
}
