//
//  GitAnnexQueries.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 12/31/17.
//  Copyright © 2017 Andrew Ringler. All rights reserved.
//

import Foundation

class GitAnnexQueries {
    // also see paths at https://stackoverflow.com/questions/41535451/how-to-access-the-terminals-path-variable-from-within-my-mac-app-it-seems-to
    static let GIT_CMD = "/Applications/git-annex.app/Contents/MacOS/git"
    static let GITANNEX_CMD = "/Applications/git-annex.app/Contents/MacOS/git-annex"
    
    // TODO one queue per repository?
    //    static let gitAnnexQueryQueue = DispatchQueue(label: "com.andrewringler.git-annex-mac.shellcommandqueue")
    
    // https://gist.github.com/brennanMKE/a0a2ee6aa5a2e2e66297c580c4df0d66
    private static func directoryExistsAt(absolutePath: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    public static func directoryExistsAt(relativePath: String, in watchedFolder: WatchedFolder) -> Bool {
        var isDirectory = ObjCBool(true)
        let absolutePath = "\(watchedFolder.pathString)/\(relativePath)"
        let exists = FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /* Adapted from https://stackoverflow.com/questions/29514738/get-terminal-output-after-a-command-swift
     * with fixes for leaving dangling open file descriptors from here:
     * http://www.cocoabuilder.com/archive/cocoa/289471-file-descriptors-not-freed-up-without-closefile-call.html
     */
    private class func runCommand(workingDirectory: String, cmd : String, args : String...) -> (output: [String], error: [String], status: Int32) {
        // protect access to git annex, I don't think you can query it
        // too heavily concurrently on the same repo, and plus I was getting
        // too many open files warnings
        // when I let all my processes access this method
        
        // ref on threading https://medium.com/@irinaernst/swift-3-0-concurrent-programming-with-gcd-5ee51e89091f
        var ret: (output: [String], error: [String], status: Int32) = ([""], ["ERROR: task did not run"], -1)
        
        //        gitAnnexQueryQueue.sync {
        var output : [String] = []
        var error : [String] = []
        
        /* check for a valid working directory now, because Process will not let us catch
         * the exception thrown if the directory is invalid */
        if !directoryExistsAt(absolutePath: workingDirectory) {
            NSLog("Invalid working directory '%@'", workingDirectory)
            return ret
        }
        
        let task = Process()
        task.launchPath = cmd
        task.currentDirectoryPath = workingDirectory
        task.arguments = args
        
        // TODO wrap commands in a shell (that is likely to exist) to avoid uncatchable errors
        // IE if workingDirectory does not exist we cannot catch that error
        // uncatchable runtime exceptions
        // see https://stackoverflow.com/questions/34420706/how-to-catch-error-when-setting-launchpath-in-nstask
        //            let task = Process()
        //            task.launchPath = "/bin/bash"
        //            task.currentDirectoryPath = workingDirectory
        //            var bashCmd :[String] = [cmd]
        //            for arg: String in args {
        //                bashCmd.append(arg)
        //            }
        //            let bashCmdString: String = "cd '" + workingDirectory + "';" +
        //            let bashArgs :[String] = ["-c", bashCmd.joined(separator: " ")]
        //            task.arguments = bashArgs
        //            NSLog("How does this look? %@", bashArgs)
        
        let outpipe = Pipe()
        task.standardOutput = outpipe
        let errpipe = Pipe()
        task.standardError = errpipe
        
        task.launch()
        
        let outputFileHandle = outpipe.fileHandleForReading
        let outdata = outputFileHandle.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            output = string.components(separatedBy: "\n")
        }
        // NOTE see http://www.cocoabuilder.com/archive/cocoa/289471-file-descriptors-not-freed-up-without-closefile-call.html
        // i was running out of file descriptors without this
        // even though the documentation clearly says it is not needed
        outputFileHandle.closeFile()
        
        let errFileHandle = errpipe.fileHandleForReading
        let errdata = errFileHandle.readDataToEndOfFile()
        if var string = String(data: errdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            error = string.components(separatedBy: "\n")
        }
        // NOTE see http://www.cocoabuilder.com/archive/cocoa/289471-file-descriptors-not-freed-up-without-closefile-call.html
        // i was running out of file descriptors without this
        // even though the documentation clearly says it is not needed
        errFileHandle.closeFile()
        
        task.waitUntilExit()
        let status = task.terminationStatus
        
        ret = (output, error, status)
        //        }
        
        return ret
    }
    
    class func createRepo(at path: String) -> Bool {
        // is this folder even a directory?
        if !directoryExistsAt(absolutePath: path) {
            NSLog("'\(path)' is not a valid directory")
            return false
        }
        
        let createGitRepoResult = gitCommand(in: path, cmd: CommandString.initCmd)
        if !createGitRepoResult.success {
            NSLog("Could not create git repo in \(path)")
            return false
        }
        
        let initGitAnnexRepo = gitAnnexCommand(in: path, cmd: CommandString.initCmd)
        if !initGitAnnexRepo.success {
            NSLog("Could not init git annex repo in \(path)")
            return false
        }
        
        return true
    }
    
    class func gitAnnexCommand(in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: cmd.rawValue)
        let commandRun = "git-annex " + cmd.rawValue
        
        if status != 0 {
            NSLog(commandRun)
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        return (status == 0, error, output, commandRun)
    }
    class func gitAnnexCommand(for path: String, in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: cmd.rawValue, path)
        let commandRun = "git-annex " + cmd.rawValue + " \"" + path + "\""
        
        if status != 0 {
            NSLog(commandRun)
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        return (status == 0, error, output, commandRun)
    }
    class func gitCommand(for path: String, in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: cmd.rawValue, path)
        let commandRun = "git " + cmd.rawValue + "\"" + path + "\""
        
        if status != 0 {
            NSLog(commandRun)
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        return (status == 0, error, output, commandRun)
    }
    class func gitCommand(in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: cmd.rawValue)
        let commandRun = "git " + cmd.rawValue
        
        if status != 0 {
            NSLog(commandRun)
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        return (status == 0, error, output, commandRun)
    }
    class func gitGitAnnexUUID(in workingDirectory: String) -> UUID? {
        // is this folder even a directory?
        if !directoryExistsAt(absolutePath: workingDirectory) {
            NSLog("Not a valid git-annex folder, nor even a directory '%@'", workingDirectory)
            return nil
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: "config", GitConfigs.AnnexUUID.name)
        
        if status == 0, output.count == 1 {
            for uuidString in output {
                if let uuid = UUID(uuidString: uuidString) {
                    return uuid
                }
                break
            }
        }
        
        if status != 0 {
            NSLog("git config %@",GitConfigs.AnnexUUID.name)
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        return nil
    }
    class func gitAnnexPathInfo(for path: String, in workingDirectory: String, in watchedFolder: WatchedFolder, includeFiles: Bool, includeDirs: Bool) -> (error: Bool, pathStatus: PathStatus?) {
        NSLog("git-annex info \(path)")
        let isDir = directoryExistsAt(relativePath: path, in: watchedFolder)
        if isDir {
            // Directory
            if includeDirs == false {
                return (error: false, pathStatus: nil) // skip
            }
        } else {
            // File
            if includeFiles == false {
                return (error: false, pathStatus: nil) // skip
            }
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "--fast", "info", path)
        
        if status != 0 {
            NSLog("gitAnnexPathInfo for path='\(path)' in='\(workingDirectory)'")
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        let modificationDate = Date().timeIntervalSinceNow as Double
        
        // if command didnt return an error, parse the JSON
        // https://stackoverflow.com/questions/25621120/simple-and-clean-way-to-convert-json-string-to-object-in-swift
        if(status == 0){
            do {
                var data: Data = (output.first as! NSString).data(using: String.Encoding.utf8.rawValue)!
                var json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
                
                if let dictionary = json as? [String: Any] {
                    let success = dictionary[GitAnnexJSON.success.rawValue]
                    let present = dictionary[GitAnnexJSON.present.rawValue]
                    let file = dictionary[GitAnnexJSON.file.rawValue]
                    let key = dictionary[GitAnnexJSON.key.rawValue]
                    let directory = dictionary[GitAnnexJSON.directory.rawValue]
                    let localAnnexKeys = dictionary[GitAnnexJSON.localAnnexKeys.rawValue]
                    let annexedFilesInWorkingTree = dictionary[GitAnnexJSON.annexedFilesInWorkingTree.rawValue]
                    let command = dictionary[GitAnnexJSON.command.rawValue]
                    
                    // Tracked by git-annex (success in the JSON means tracked by git-annex)
                    if let successVal = success as? Bool {
                        if successVal == true {
                            if let presentVal = present as? Bool, let keyVal = key as? String {
                                //
                                // FILE tracked by git-annex
                                //
                                // (we have a file if the present attribute exists in the json)
                                //
                                let numberOfCopies = GitAnnexQueries.gitAnnexNumberOfCopies(for: path, in: workingDirectory)
                                let lackingCopies = GitAnnexQueries.gitAnnexLackingCopies(for: path, in: workingDirectory)
                                let presentStatus = presentVal ? Present.present : Present.absent
                                let enoughCopies = lackingCopies ?? true ? EnoughCopies.lacking : EnoughCopies.enough
                                
                                return (error: false, pathStatus: PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: presentStatus, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: keyVal, needsUpdate: false))
                            } else {
                                //
                                // FOLDER tracked by git-annex
                                //
                                // (we have a folder if the present attribute is missing from the JSON)
                                //
                                let numberOfCopies = GitAnnexQueries.gitAnnexNumberOfCopies(for: path, in: workingDirectory)
                                let lackingCopies = GitAnnexQueries.gitAnnexLackingCopies(for: path, in: workingDirectory)
                                let enoughCopies = lackingCopies ?? true ? EnoughCopies.lacking : EnoughCopies.enough
                                
                                if let annexedFilesInWorkingTreeVal = annexedFilesInWorkingTree as? Int,
                                    let localAnnexKeysVal = localAnnexKeys as? Int {
                                    if localAnnexKeysVal == annexedFilesInWorkingTreeVal {
                                        // all files are present
                                        return (error: false, pathStatus: PathStatus(isDir: true, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: nil /* folders don't have a key */, needsUpdate: false))
                                    } else if localAnnexKeysVal == 0 {
                                        // no files are present
                                        return (error: false, pathStatus: PathStatus(isDir: true, isGitAnnexTracked: true, presentStatus: Present.absent, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: nil /* folders don't have a key */, needsUpdate: false))
                                    } else {
                                        // some files are present
                                        return (error: false, pathStatus: PathStatus(isDir: true, isGitAnnexTracked: true, presentStatus: Present.partialPresent, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: nil /* folders don't have a key */, needsUpdate: false))
                                    }
                                }
                                
                                NSLog("ERROR: could not figure out a status for folder: '\(path)' '\(dictionary)'")
                                
                            }
                        } else {
                            // git-annex returned success: false
                            
                            // We could have a tracked unlocked present file
                            // in a v5 indirect git-annex repo?
                            // if so, we get no info from git annex info
                            // we could do calckey, but this could get out of date
                            // if we don't monitor the folder for changes?
                            // TODO calculate location counts using readpresentkey?
//                            if let calculatedKey = GitAnnexQueries.gitAnnexCalcKey(for: path, in: workingDirectory) {
//
//                            }
                            // TODO
                        }
                    }
                }
            } catch {
                NSLog("unable to parse JSON: '", output, "'")
            }
            
            return (error: false, pathStatus: PathStatus(isDir: isDir, isGitAnnexTracked: false, presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: nil, needsUpdate: false))
        }
        
        return (error: true, pathStatus: nil)
    }
    
    /* For a file: returns its number of copies
     * For a directory: returns the number of copies of the file with the least copies
     * contained within the directory
     */
    class func gitAnnexNumberOfCopies(for path: String, in workingDirectory: String) -> UInt8? {
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "--fast", "whereis", path)
        
        // if command didnt return an error, parse the JSON
        // https://stackoverflow.com/questions/25621120/simple-and-clean-way-to-convert-json-string-to-object-in-swift
        if(status == 0){
            do {
                var leastCopies: Int? = nil
                
                /* git-annex returns 1-line of valid JSON for each file contained within a folder */
                for outputLine in output {
                    if let data: Data = (outputLine as NSString).data(using: String.Encoding.utf8.rawValue) {
                        let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
                        
                        if let dictionary = json as? [String: Any] {
                            let success = dictionary[GitAnnexJSON.success.rawValue]
                            let whereis = dictionary[GitAnnexJSON.whereis.rawValue] as? [[String: Any]]
                            
                            // calculate number of copies, for this file
                            if success != nil && whereis != nil, let whereisval = whereis {
                                let numberOfCopies = whereisval.count
                                if leastCopies == nil || numberOfCopies < leastCopies! {
                                    leastCopies = numberOfCopies
                                }
                            } else {
                                NSLog("issue getting data from JSON: '\(dictionary)'")
                            }
                        }
                    } else {
                        NSLog("could not get output as string \(outputLine)")
                    }
                }
                
                if let leastCopiesVal = leastCopies {
                    return UInt8(leastCopiesVal)
                }
                return nil
            } catch {
                NSLog("unable to parse JSON: '\(output)' for path='\(path)' workingdir='\(workingDirectory)'")
            }
        } else {
            NSLog("gitAnnexNumberOfCopies")
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
            return nil
        }
        
        return nil
    }
    
    /* git annex find --lackingcopies=1 --json
     * returns a line for every file that is lacking 1 or more copies
     * calling this on directories causes git-annex to query each child file recursively
     * this can be slow, guard when you call this on directories
     */
    class func gitAnnexLackingCopies(for path: String, in workingDirectory: String) -> Bool? {
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "--fast", "--lackingcopies=1", "find", path)
        
        // if command didnt return an error, count the lines returned
        if(status == 0){
            if let firstLine = output.first {
                return !firstLine.isEmpty
            }
            return false
        } else {
            NSLog("gitAnnexLackingCopies")
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
            return nil
        }
    }
    
    /* returns list of files tracked by git annex that have been modified
     * since the give commitHash
     * where commitHash is a commit in the git-annex branch */
    class func allKeysWithLocationsChangesGitAnnexSinceBlocking(commitHash: String, in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "changedAnnexFilesAfterCommit", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: commitHash)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 }
            } else {
                NSLog("allKeysWithLocationsChangesSinceBlocking(commitHash: \(commitHash)")
                NSLog("status: \(status)")
                NSLog("output: \(output)")
                NSLog("error: \(error)")
            }
        } else {
            NSLog("allKeysWithLocationsChangesSinceBlocking: error, could not find shell script in bundle")
        }
        
        return []
    }
    
    /* returns list of files in git repo that have been modified
     * since the give commitHash
     * where commitHash is a commit in the master branch */
    class func allFileChangesGitSinceBlocking(commitHash: String, in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "changedGitFilesAfterCommit", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: commitHash)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 }
            } else {
                NSLog("allFileChangesSinceBlocking(commitHash: \(commitHash)")
                NSLog("status: \(status)")
                NSLog("output: \(output)")
                NSLog("error: \(error)")
            }
        } else {
            NSLog("allFileChangesSinceBlocking: error, could not find shell script in bundle")
        }
        
        return []
    }
    
    class func latestGitAnnexCommitHashBlocking(in watchedFolder: WatchedFolder) -> String? {
        let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: "log", "--pretty=format:\"%H\"", "-r", "git-annex", "-n", "1")
        
        if(status == 0){ // success
            if output.count == 1 {
                return output.first
            }
        }
        
        NSLog("latestGitAnnexCommitHashBlocking: error")
        NSLog("status: \(status)")
        NSLog("output: \(output)")
        NSLog("error: \(error)")
        
        return nil
    }
    
    class func latestGitCommitHashBlocking(in watchedFolder: WatchedFolder) -> String? {
        let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: "log", "--pretty=format:\"%H\"", "-n", "1")
        
        if(status == 0){ // success
            if output.count == 1 {
                return output.first
            }
        }
        
        NSLog("latestGitCommitHashBlocking: error")
        NSLog("status: \(status)")
        NSLog("output: \(output)")
        NSLog("error: \(error)")
        
        return nil
    }
    
    class func immediateChildrenNotIgnored(relativePath: String, in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "childrenNotIgnored", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: relativePath, GIT_CMD, GITANNEX_CMD)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 } // remove empty strings
            } else {
                NSLog("immediateChildrenNotIgnored(relativePath: \(relativePath), in: \(watchedFolder)")
                NSLog("status: \(status)")
                NSLog("output: \(output)")
                NSLog("error: \(error)")
            }
        } else {
            NSLog("immediateChildrenNotIgnored: error, could not find shell script in bundle")
        }
        
        return []
    }
}
