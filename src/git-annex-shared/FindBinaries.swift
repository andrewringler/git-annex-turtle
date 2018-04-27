//
//  FindBinaries.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 4/27/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class FindBinaries {
    // look for git-annex binary in reasonable locations
    public static func gitAnnexBinAbsolutePath(workingDirectory: String) -> String? {
        // git-annex in /Applications?
        if let path = gitAnnexInApplications(workingDirectory: workingDirectory) {
            return path
        }

        // git-annex in ~/Applications?
        if let path = gitAnnexInUserApplications(workingDirectory: workingDirectory) {
            return path
        }

        // git-annex from brew?
        if let path = gitAnnexFromBrew(workingDirectory: workingDirectory) {
            return path
        }
        
        // git-annex on path?
        if let path = gitAnnexOnPath(workingDirectory: workingDirectory) {
            return path
        }
        
        TurtleLog.error("could not find git-annex binary, perhaps it is not installed?")
        return nil
    }
    
    // Look for git binary in reasonable locations
    public static func gitBinAbsolutePath(workingDirectory: String, gitAnnexPath: String?) -> String? {
        // git bundled with git-annex in the same parent directory?
        if let gitAnnexPathExists = gitAnnexPath, let path = gitBundledAtGitAnnexPath(workingDirectory: workingDirectory, gitAnnexPath: gitAnnexPathExists) {
            return path
        }
        
        // git in /Applications?
        if let path = gitInApplicationsBundledWithGitAnnex(workingDirectory: workingDirectory) {
            return path
        }
        
        // git in ~/Applications?
        if let path = gitInUserApplicationsBundledWithGitAnnex(workingDirectory: workingDirectory) {
            return path
        }
        
        // git installed by brew?
        if let path = gitFromBrew(workingDirectory: workingDirectory) {
            return path
        }
        
        // git on path?
        if let path = gitOnPath(workingDirectory: workingDirectory) {
            return path
        }

        TurtleLog.error("could not find git binary, perhaps it is not installed?")
        return nil
    }
    
    private static func validGit(workingDirectory: String, gitAbsolutePath: String) -> Bool {
        let (output, _, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAbsolutePath, args: "version")
        if status == 0, output.count > 0, let first = output.first, first.starts(with: "git version") { // success
            return true
        }
        return false
    }
    
    private static func validGitAnnex(workingDirectory: String, gitAnnexAbsolutePath: String) -> Bool {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAnnexAbsolutePath, args: "version")
        if status == 0, output.count > 0, let first = output.first, first.starts(with: "git-annex version") { // success
            return true
        }
        return false
    }
    
    private static func gitBundledAtGitAnnexPath(workingDirectory: String, gitAnnexPath: String) -> String? {
        if let parent = PathUtils.parent(absolutePath: gitAnnexPath) {
            let gitPath = "\(parent)/git"
            if validGit(workingDirectory: workingDirectory, gitAbsolutePath: gitPath) {
                return gitPath
            }
        }
        return nil
    }
    
    private static func gitOnPath(workingDirectory: String) -> String? {
        let (output, _, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: "/bin/bash", args: "-c", "\"/usr/bin/which git\"")
        if status == 0, output.count == 1 { // success
            let gitPath = output.first!
            if validGit(workingDirectory: workingDirectory, gitAbsolutePath: gitPath) {
                return gitPath
            }
        }
        return nil
    }
    
    private static func gitAnnexOnPath(workingDirectory: String) -> String? {
        let (output, _, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: "/bin/bash", args: "-c", "\"/usr/bin/which git-annex\"")
        if status == 0, output.count == 1 { // success
            let gitAnnexPath = output.first!
            if validGitAnnex(workingDirectory: workingDirectory, gitAnnexAbsolutePath: gitAnnexPath) {
                return gitAnnexPath
            }
        }
        return nil
    }
    
    private static func gitFromBrew(workingDirectory: String) -> String? {
        let (output, _, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: "/bin/bash", args: "-c", "\"/usr/local/bin/brew ls git | grep 'bin/git$'\"")
        if status == 0, output.count >= 1 { // success
            let gitPath = output.first!
            if validGit(workingDirectory: workingDirectory, gitAbsolutePath: gitPath) {
                return gitPath
            }
        }
        return nil
    }
    
    private static func gitAnnexFromBrew(workingDirectory: String) -> String? {
        let (output, _, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: "/bin/bash", args: "-c", "\"/usr/local/bin/brew ls git-annex | grep 'bin/git-annex$'\"")
        if status == 0, output.count >= 1 { // success
            let gitAnnexPath = output.first!
            if validGitAnnex(workingDirectory: workingDirectory, gitAnnexAbsolutePath: gitAnnexPath) {
                return gitAnnexPath
            }
        }
        return nil
    }
    
    private static func gitAnnexInApplications(workingDirectory: String) -> String? {
        let applicationsPath = "/Applications/git-annex.app/Contents/MacOS/git-annex"
        if validGitAnnex(workingDirectory: workingDirectory, gitAnnexAbsolutePath: applicationsPath) {
            return applicationsPath
        }
        return nil
    }
    
    private static func gitAnnexInUserApplications(workingDirectory: String) -> String? {
        let applicationsPath = "~/Applications/git-annex.app/Contents/MacOS/git-annex"
        if validGitAnnex(workingDirectory: workingDirectory, gitAnnexAbsolutePath: applicationsPath) {
            return applicationsPath
        }
        return nil
    }
    
    private static func gitInApplicationsBundledWithGitAnnex(workingDirectory: String) -> String? {
        let applicationsPath = "/Applications/git-annex.app/Contents/MacOS/git"
        if validGit(workingDirectory: workingDirectory, gitAbsolutePath: applicationsPath) {
            return applicationsPath
        }
        return nil
    }
    
    private static func gitInUserApplicationsBundledWithGitAnnex(workingDirectory: String) -> String? {
        let applicationsPath = "~/Applications/git-annex.app/Contents/MacOS/git"
        if validGit(workingDirectory: workingDirectory, gitAbsolutePath: applicationsPath) {
            return applicationsPath
        }
        return nil
    }
}
