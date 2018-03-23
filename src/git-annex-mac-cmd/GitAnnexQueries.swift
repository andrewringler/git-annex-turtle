//
//  GitAnnexQueries.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 12/31/17.
//  Copyright © 2017 Andrew Ringler. All rights reserved.
//

import Foundation

class GitAnnexQueries {
    public static let NO_GIT_COMMITS = "NO GIT COMMIT YET"
    let gitCmd: String
    let gitAnnexCmd: String
    
    init(gitAnnexCmd: String, gitCmd: String) {
        self.gitAnnexCmd = gitAnnexCmd
        self.gitCmd = gitCmd
    }
    
    // TODO one queue per repository?
    //    static let gitAnnexQueryQueue = DispatchQueue(label: "com.andrewringler.git-annex-mac.shellcommandqueue")
    
    // https://gist.github.com/brennanMKE/a0a2ee6aa5a2e2e66297c580c4df0d66
    private static func directoryExistsAt(absolutePath: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    public static func directoryExistsAt(relativePath: String, in watchedFolder: WatchedFolder) -> Bool {
        let absolutePath = PathUtils.absolutePath(for: relativePath, in: watchedFolder)
        return directoryExistsAt(absolutePath: absolutePath)
    }
    
    /* Adapted from https://stackoverflow.com/questions/29514738/get-terminal-output-after-a-command-swift
     * with fixes for leaving dangling open file descriptors from here:
     * http://www.cocoabuilder.com/archive/cocoa/289471-file-descriptors-not-freed-up-without-closefile-call.html
     */
    private static func runCommand(workingDirectory: String, cmd : String, args : String...) -> (output: [String], error: [String], status: Int32) {
        // ref on threading https://medium.com/@irinaernst/swift-3-0-concurrent-programming-with-gcd-5ee51e89091f
        var ret: (output: [String], error: [String], status: Int32) = ([""], ["ERROR: task did not run"], -1)
        
        // Place call to Process in thread, in-case it crashes it won't bring down our main thread
        DispatchQueue.global(qos: .background).sync {
            var output : [String] = []
            var error : [String] = []
            
            /* check for a valid working directory now, because Process will not let us catch
             * the exception thrown if the directory is invalid */
            if !GitAnnexQueries.directoryExistsAt(absolutePath: workingDirectory) {
                TurtleLog.error("Invalid working directory '%@'", workingDirectory)
                return
            }
            
    //        let task = Process()
    //        task.launchPath = cmd
    //        task.currentDirectoryPath = workingDirectory
    //        task.arguments = args
            
            // TODO wrap commands in a shell (that is likely to exist) to avoid uncatchable errors
            // IE if workingDirectory does not exist we cannot catch that error
            // uncatchable runtime exceptions
            // see https://stackoverflow.com/questions/34420706/how-to-catch-error-when-setting-launchpath-in-nstask
            let task = Process()
            task.launchPath = "/bin/bash"
            task.currentDirectoryPath = workingDirectory
            var bashCmd :[String] = [cmd]
            for arg: String in args {
                bashCmd.append(arg)
            }
    //        let bashCmdString: String = "cd '" + workingDirectory + "';" +
            let bashArgs :[String] = ["-c", bashCmd.joined(separator: " ")]
            task.arguments = bashArgs
            
            let outpipe = Pipe()
            task.standardOutput = outpipe
            let errpipe = Pipe()
            task.standardError = errpipe
        
            // TODO kill long running tasks
            let startTime = Date()
            task.launch()
            task.waitUntilExit()
            TurtleLog.debug("Task ran in \(Date().timeIntervalSince(startTime)) seconds, dir=\(workingDirectory) cmd=\(cmd) args=\(args)")
            
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
            
            //        task.waitUntilExit()
            
            let status = task.terminationStatus
            
            ret = (output, error, status)
        }
        
        return ret
    }
    
    func createRepo(at path: String) -> Bool {
        // is this folder even a directory?
        if !GitAnnexQueries.directoryExistsAt(absolutePath: path) {
            TurtleLog.error("'\(path)' is not a valid directory")
            return false
        }
        
        let createGitRepoResult = gitCommand(in: path, cmd: CommandString.initCmd)
        if !createGitRepoResult.success {
            TurtleLog.error("Could not create git repo in \(path)")
            return false
        }
        
        let initGitAnnexRepo = gitAnnexCommand(in: path, cmd: CommandString.initCmd)
        if !initGitAnnexRepo.success {
            TurtleLog.error("Could not init git annex repo in \(path)")
            return false
        }
        
        return true
    }
    
    func gitAnnexCommand(in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, args: cmd.rawValue)
        let commandRun = "git-annex " + cmd.rawValue
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        
        return (status == 0, error, output, commandRun)
    }
    func gitAnnexCommand(for path: String, in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, args: cmd.rawValue, "\"\(path)\"")
        let commandRun = "git-annex " + cmd.rawValue + " \"" + path + "\""
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        
        return (status == 0, error, output, commandRun)
    }
    func gitCommand(for path: String, in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitCmd, args: cmd.rawValue, "\"\(path)\"")
        let commandRun = "git " + cmd.rawValue + "\"" + path + "\""
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        return (status == 0, error, output, commandRun)
    }
    func gitCommand(in workingDirectory: String, cmd: CommandString) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitCmd, args: cmd.rawValue)
        let commandRun = "git " + cmd.rawValue
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        return (status == 0, error, output, commandRun)
    }
    func gitCommit(in workingDirectory: String, commitMessage: String) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitCmd, args: CommandString.commit.rawValue, "-m", "\"" + commitMessage.escapeString() + "\"")
        let commandRun = "git commit \"" + commitMessage + "\""
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        return (status == 0, error, output, commandRun)
    }
    func gitGitAnnexUUID(in workingDirectory: String) -> UUID? {
        // is this folder even a directory?
        if !GitAnnexQueries.directoryExistsAt(absolutePath: workingDirectory) {
            TurtleLog.error("Not a valid git-annex folder, nor even a directory '%@'", workingDirectory)
            return nil
        }
        
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitCmd, args: "config", GitConfigs.AnnexUUID.name)
        
        if status == 0, output.count == 1 {
            for uuidString in output {
                if let uuid = UUID(uuidString: uuidString) {
                    return uuid
                }
                break
            }
        }
        
        if status != 0 {
            TurtleLog.error("git config \(GitConfigs.AnnexUUID.name) status= \(status) output=\(output) error=\(error)")
        }
        return nil
    }
    
    func gitAnnexSetNumCopies(numCopies: Int, in watchedFolder: WatchedFolder) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        return gitAnnexCommand(for: String(numCopies), in: watchedFolder.pathString, cmd: .numCopies)
    }
    
    func gitAnnexAllFilesLackingCopies(in watchedFolder: WatchedFolder) -> Set<String>? {
        if let dir = PathUtils.createTmpDir() {
            let file = "allfileslackingcopies.txt"
            let resultsFileAbsolutePath = "\(dir)/\(file)"
            
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: gitAnnexCmd, args: "find", "--fast", "--lackingcopies=1", ">\"\(resultsFileAbsolutePath)\"")
            
            if status == 0 {
                // TODO use a trie
                var allFilesLackingCopies = Set<String>()
                let s = StreamReader(url: PathUtils.urlFor(absolutePath: resultsFileAbsolutePath))
                while let line = s?.nextLine() {
                    allFilesLackingCopies.insert(line)
                }
                PathUtils.removeDir(dir)
                return allFilesLackingCopies
            } else {
                TurtleLog.error("in \(watchedFolder) status= \(status) output=\(output) error=\(error)")
            }
        }
        TurtleLog.error("could not create temporary directory")
        return nil
    }

    func gitAnnexWhereisAllFiles(in watchedFolder: WatchedFolder) -> String? {
        if let dir = PathUtils.createTmpDir() {
            let file = "whereisallfiles.json"
            let resultsFileAbsolutePath = "\(dir)/\(file)"
            
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: gitAnnexCmd, args: "--json", "--fast", "whereis", ".", ">\"\(resultsFileAbsolutePath)\"")

            if status == 0 {
                return resultsFileAbsolutePath
            } else {
                TurtleLog.error("\(watchedFolder) status= \(status) output=\(output) error=\(error)")
            }
        } else {
            TurtleLog.error("could not create temp dir")
        }
        return nil
    }
    
    func parseWhereis(for line: String, in watchedFolder: WatchedFolder, modificationDate: Double, filesWithCopiesLacking: Set<String>) -> PathStatus? {
        do {
            let data: Data = (line as NSString).data(using: String.Encoding.utf8.rawValue)!
            let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
            
            if let dictionary = json as? [String: Any] {
                if let success = dictionary[GitAnnexJSON.success.rawValue] as? Bool,
                    success == true,
                    let file = dictionary[GitAnnexJSON.file.rawValue] as? String,
                    let key = dictionary[GitAnnexJSON.key.rawValue] as? String,
                    let whereis = dictionary[GitAnnexJSON.whereis.rawValue] as? [[String: Any]] {
                    let numberOfCopies = UInt8(whereis.count)
                    let lackingCopies = filesWithCopiesLacking.contains(file)
                    // at least one whereis entry should have a here:true entry
                    let present: Bool = whereis.reduce(false, { a, b in a || b[GitAnnexJSON.here.rawValue] as? Bool ?? false})
                    let presentStatus = present ? Present.present : Present.absent
                    let enoughCopies = lackingCopies ?? true ? EnoughCopies.lacking : EnoughCopies.enough
                    
                    return PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: presentStatus, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: file, watchedFolder: watchedFolder, modificationDate: modificationDate, key: key, needsUpdate: false)
                }
            }
        } catch {
            TurtleLog.error("could not figure out a status given line = '\(line)' for \(watchedFolder) \(error)")
            return nil
        }
        TurtleLog.error("could not figure out a status given line = '\(line)' for \(watchedFolder)")
        return nil
    }
    
    func gitAnnexPathInfo(for path: String, in workingDirectory: String, in watchedFolder: WatchedFolder, includeFiles: Bool, includeDirs: Bool) -> (error: Bool, pathStatus: PathStatus?) {
        TurtleLog.debug("git-annex info \(path)")
        let isDir = GitAnnexQueries.directoryExistsAt(relativePath: path, in: watchedFolder)
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
        
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, args: "--json", "--fast", "info", "\"\(path)\"")
        
        if status != 0 {
            TurtleLog.error("path='\(path)' in='\(workingDirectory) status= \(status) output=\(output) error=\(error)")
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
                                let numberOfCopies = gitAnnexNumberOfCopies(for: path, in: workingDirectory)
                                let lackingCopies = gitAnnexLackingCopies(for: path, in: workingDirectory)
                                let presentStatus = presentVal ? Present.present : Present.absent
                                let enoughCopies = lackingCopies ?? true ? EnoughCopies.lacking : EnoughCopies.enough
                                
                                return (error: false, pathStatus: PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: presentStatus, enoughCopies: enoughCopies, numberOfCopies: numberOfCopies, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: keyVal, needsUpdate: false))
                            } else {
                                //
                                // FOLDER tracked by git-annex
                                //
                                // (we have a folder if the present attribute is missing from the JSON)
                                //
                                let numberOfCopies = gitAnnexNumberOfCopies(for: path, in: workingDirectory)
                                let lackingCopies = gitAnnexLackingCopies(for: path, in: workingDirectory)
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
                                TurtleLog.error("could not figure out a status for folder: '\(path)' '\(dictionary)'")
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
                            TurtleLog.todo("unsupported file type in query for status \(path) in \(watchedFolder)")
                        }
                    }
                }
            } catch {
                TurtleLog.error("unable to parse JSON: '", output, "'")
            }
            
            return (error: false, pathStatus: PathStatus(isDir: isDir, isGitAnnexTracked: false, presentStatus: nil, enoughCopies: nil, numberOfCopies: nil, path: path, watchedFolder: watchedFolder, modificationDate: modificationDate, key: nil, needsUpdate: false))
        }
        
        return (error: true, pathStatus: nil)
    }
    
    /* For a file: returns its number of copies
     * For a directory: returns the number of copies of the file with the least copies
     * contained within the directory
     */
    func gitAnnexNumberOfCopies(for path: String, in workingDirectory: String) -> UInt8? {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, args: "--json", "--fast", "whereis", "\"\(path)\"")
        
        // if command didnt return an error, parse the JSON
        // https://stackoverflow.com/questions/25621120/simple-and-clean-way-to-convert-json-string-to-object-in-swift
        if status == 0 {
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
                                TurtleLog.error("issue getting data from JSON: '\(dictionary)'")
                            }
                        }
                    } else {
                        TurtleLog.error("could not get output as string \(outputLine)")
                    }
                }
                
                if let leastCopiesVal = leastCopies {
                    return UInt8(leastCopiesVal)
                }
                return nil
            } catch {
                TurtleLog.error("unable to parse JSON: '\(output)' for path='\(path)' workingdir='\(workingDirectory)'")
            }
        } else {
            TurtleLog.error("status= \(status) output=\(output) error=\(error)")
            return nil
        }
        
        return nil
    }
    
    /* git annex find --lackingcopies=1 --json
     * returns a line for every file that is lacking 1 or more copies
     * calling this on directories causes git-annex to query each child file recursively
     * this can be slow, guard when you call this on directories
     */
    func gitAnnexLackingCopies(for path: String, in workingDirectory: String) -> Bool? {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, args: "--json", "--fast", "--lackingcopies=1", "find", "\"\(path)\"")
        
        // if command didnt return an error, count the lines returned
        if(status == 0){
            if let firstLine = output.first {
                return !firstLine.isEmpty
            }
            return false
        } else {
            TurtleLog.error("status= \(status) output=\(output) error=\(error)")
            return nil
        }
    }
    
    /* returns list of files tracked by git annex that have been modified
     * since the give commitHash
     * where commitHash is a commit in the git-annex branch */
    func allKeysWithLocationsChangesGitAnnexSinceBlocking(commitHash: String, in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "changedAnnexFilesAfterCommit", ofType: "sh") {
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: commitHash, gitCmd)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 }
            } else {
                TurtleLog.error("commitHash: \(commitHash) status= \(status) output=\(output) error=\(error)")
            }
        } else {
            TurtleLog.error("could not find shell script in bundle")
        }
        
        return []
    }
    
    /* returns list of files in git repo that have been modified
     * since the given commitHash
     * where commitHash is a commit in the master branch */
    func allFileChangesGitSinceBlocking(commitHash: String, in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "changedGitFilesAfterCommit", ofType: "sh") {
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: commitHash, gitCmd)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 }
            } else {
                TurtleLog.error("commitHash: \(commitHash) status= \(status) output=\(output) error=\(error)")
            }
        } else {
            TurtleLog.error("could not find shell script in bundle")
        }
        
        return []
    }
    
    /* returns list of files in git repo that have been modified
     * mentioned in any git commit ever */
    func allFileChangesInGitLog(in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "allChangedGitFiles", ofType: "sh") {
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: gitCmd)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 }
            } else {
                TurtleLog.error("status= \(status) output=\(output) error=\(error)")
            }
        } else {
            TurtleLog.error("could not find shell script in bundle")
        }
        
        return []
    }
    
    func latestGitAnnexCommitHashBlocking(in watchedFolder: WatchedFolder) -> String? {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: gitCmd, args: "log", "--pretty=format:\"%H\"", "-r", "git-annex", "-n", "1")
        
        if(status == 0){ // success
            if output.count == 1 {
                return output.first
            }
        }
        
        TurtleLog.error("status= \(status) output=\(output) error=\(error)")
        return nil
    }
    
    func latestGitCommitHashBlocking(in watchedFolder: WatchedFolder) -> String? {
        let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: gitCmd, args: "log", "--pretty=format:\"%H\"", "-n", "1")
        
        if(status == 0){ // success
            if output.count == 1 {
                return output.first
            }
        }
        
        TurtleLog.debug("missing git commit hash, this is OK, since only mixed-mode repos need to commit to the git branch, status= \(status) output=\(output) error=\(error)")
        return nil
    }
    
    func immediateChildrenNotIgnored(relativePath: String, in watchedFolder: WatchedFolder) -> [String] {
        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "childrenNotIgnored", ofType: "sh") {
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, args: relativePath, gitCmd, gitAnnexCmd)
            
            if(status == 0){ // success
                return output.filter { $0.count > 0 } // remove empty strings
            } else {
                TurtleLog.error("relativePath: \(relativePath), in: \(watchedFolder) status= \(status) output=\(output) error=\(error)")
            }
        } else {
            TurtleLog.fatal("could not find shell script in bundle")
            fatalError("immediateChildrenNotIgnored: error, could not find shell script in bundle")
        }
        
        return []
    }
    
    static func gitAnnexBinAbsolutePath() -> String? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID),  let workingDirectory = PathUtils.path(for: containerURL) {
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: "/bin/bash", args: "-c", ". ~/.bash_profile > /dev/null 2>&1; which git-annex")
            
            if status == 0, output.count == 1 { // success
                return output.first!
            } else {
                // Could not find git-annex in profile
                // perhaps it is in a standard location?
                let applicationsPath = "/Applications/git-annex.app/Contents/MacOS/git-annex"
                let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: applicationsPath, args: "version")
                if status == 0, output.count > 0, let first = output.first, first.starts(with: "git-annex version") { // success
                    return applicationsPath
                }
            }
        }
        
        TurtleLog.error("could not find git-annex binary, perhaps it is not installed?")
        return nil
    }
    
    static func gitBinAbsolutePath() -> String? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID),  let workingDirectory = PathUtils.path(for: containerURL) {
            let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: "/bin/bash", args: "-c", ". ~/.bash_profile > /dev/null 2>&1; which git")
            
            if status == 0, output.count == 1 { // success
                return output.first!
            } else {
                // Could not find git in profile
                // perhaps it is in a standard location?
                let applicationsPath = "/Applications/git-annex.app/Contents/MacOS/git"
                let (output, error, status) = GitAnnexQueries.runCommand(workingDirectory: workingDirectory, cmd: applicationsPath, args: "version")
                if status == 0, output.count > 0, let first = output.first, first.starts(with: "git version") { // success
                    return applicationsPath
                }
            }
        }
        
        TurtleLog.error("could not find git binary, perhaps it is not installed?")
        return nil
    }
}

extension String {
    func escapeString() -> String {
        let newString = self.replacingOccurrences(of: "\"", with: "\"\"", options: .literal, range: nil)
        if newString.contains(",") || newString.contains("\n") {
            return String(format: "\"%@\"", newString)
        }
        return newString
    }
}
