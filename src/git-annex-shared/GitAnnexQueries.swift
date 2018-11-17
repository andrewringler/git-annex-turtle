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
    private let preferences: Preferences
    
    init(preferences: Preferences) {
        self.preferences = preferences
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
    public static func runCommand(workingDirectory: String, cmd : String, args : String...) -> (output: [String], error: [String], status: Int32) {
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
            
            // wrap commands in a shell (that is likely to exist, /bin/bash) to avoid uncatchable errors
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
            let endTime = Date()
            
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
            
            let status = task.terminationStatus
            ret = (output, error, status)
            
            TurtleLog.debug("Task ran in \(endTime.timeIntervalSince(startTime)) seconds, dir=\(workingDirectory) cmd=\(cmd) args=\(args) result=\(ret)")
        }
        
        return ret
    }
    
    func runCommand(workingDirectory: String, cmd : String, limitToMasterBranch: Bool, args : String...) -> (output: [String], error: [String], status: Int32) {
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
            
            // prevent queries on anything other than the master git branch
            // TODO this guard is not entirely safe, since the branch could change after
            // we have called this guard, see https://git-annex.branchable.com/todo/add_a_--branch_to_applicable_git-annex_commands/ for a brief discussion on ensuring
            // git-annex commands apply to a certain branch
            var branchGuard: String = ""
            if limitToMasterBranch {
                guard let gitCmd = preferences.gitBin() else {
                    TurtleLog.debug("Requested limitToMasterBranch, but git command is missing")
                    return
                }
                
                // https://stackoverflow.com/a/1593487/8671834
                branchGuard = "if [[ $(git symbolic-ref --short -q HEAD 2>/dev/null | sed -e \"s/^annex\\/direct\\///\") != \"master\" ]]; then exit 1; fi && "
            }
            
            // wrap commands in a shell (that is likely to exist, /bin/bash) to avoid uncatchable errors
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
            // Contruct bash command
            // 1. load users's bash_profile so we have any PATHs to git-annex special remote binaries
            // 2. limit command to certain git branch (if requested)
            // 3. run command
            let bashArgs :[String] = ["-c", ". ~/.bash_profile > /dev/null 2>&1; " + branchGuard + bashCmd.joined(separator: " ")]
            task.arguments = bashArgs
            
            let outpipe = Pipe()
            task.standardOutput = outpipe
            let errpipe = Pipe()
            task.standardError = errpipe
        
            // TODO kill long running tasks
            let startTime = Date()
            task.launch()
            task.waitUntilExit()
            let endTime = Date()
            
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
            
            let status = task.terminationStatus
            
            ret = (output, error, status)
            
            TurtleLog.debug("Task ran in \(endTime.timeIntervalSince(startTime)) seconds, dir=\(workingDirectory) cmd=\(cmd) args=\(args) result=\(ret)")
        }
        
        return ret
    }
    
    func createRepo(at path: String) -> Bool {
        // is this folder even a directory?
        if !GitAnnexQueries.directoryExistsAt(absolutePath: path) {
            TurtleLog.error("'\(path)' is not a valid directory")
            return false
        }
        
        let createGitRepoResult = gitCommand(in: path, cmd: CommandString.initCmd, limitToMasterBranch: false)
        if !createGitRepoResult.success {
            TurtleLog.error("Could not create git repo in \(path)")
            return false
        }
        
        let initGitAnnexRepo = gitAnnexCommand(in: path, cmd: CommandString.initCmd, limitToMasterBranch: false)
        if !initGitAnnexRepo.success {
            TurtleLog.error("Could not init git annex repo in \(path)")
            return false
        }
        
        return true
    }
    
    func gitAnnexCommand(in workingDirectory: String, cmd: CommandString, limitToMasterBranch: Bool) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let commandRun = "git-annex " + cmd.rawValue
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            return (false, [], [], commandRun)
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, limitToMasterBranch: limitToMasterBranch, args: cmd.rawValue)
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        
        return (status == 0, error, output, commandRun)
    }
    func gitAnnexCommand(for path: String, in workingDirectory: String, cmd: CommandString, limitToMasterBranch: Bool) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let commandRun = "git-annex " + cmd.rawValue + " \"" + path + "\""
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return (false, [], [], commandRun)
        }

        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, limitToMasterBranch: limitToMasterBranch, args: cmd.rawValue, "\"\(path)\"")
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        
        return (status == 0, error, output, commandRun)
    }
    func gitCommand(for path: String, in workingDirectory: String, cmd: CommandString, limitToMasterBranch: Bool) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let commandRun = "git " + cmd.rawValue + "\"" + path + "\""
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return (false, [], [], commandRun)
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitCmd, limitToMasterBranch: limitToMasterBranch, args: cmd.rawValue, "\"\(path)\"")
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        return (status == 0, error, output, commandRun)
    }
    func gitCommand(in workingDirectory: String, cmd: CommandString, limitToMasterBranch: Bool) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let commandRun = "git " + cmd.rawValue
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return (false, [], [], commandRun)
        }

        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitCmd, limitToMasterBranch: limitToMasterBranch, args: cmd.rawValue)
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        return (status == 0, error, output, commandRun)
    }
    func gitCommit(in workingDirectory: String, commitMessage: String, limitToMasterBranch: Bool) -> (success: Bool, error: [String], output: [String], commandRun: String) {
        let commandRun = "git commit \"" + commitMessage + "\""
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return (false, [], [], commandRun)
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitCmd, limitToMasterBranch: limitToMasterBranch, args: CommandString.commit.rawValue, "-m", "\"" + commitMessage.escapeString() + "\"")
        
        if status != 0 {
            TurtleLog.error("\(commandRun) status= \(status) output=\(output) error=\(error)")
        }
        return (status == 0, error, output, commandRun)
    }
    
    func gitGitAnnexUUID(in workingDirectory: String) -> UUID? {
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return nil
        }

        // is this folder even a directory?
        if !GitAnnexQueries.directoryExistsAt(absolutePath: workingDirectory) {
            TurtleLog.error("Not a valid git-annex folder, nor even a directory '%@'", workingDirectory)
            return nil
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitCmd, limitToMasterBranch: false, args: "config", GitConfigs.AnnexUUID.name)
        
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
        return gitAnnexCommand(for: String(numCopies), in: watchedFolder.pathString, cmd: .numCopies, limitToMasterBranch: false)
    }
    
    func gitAnnexAllFilesLackingCopies(in watchedFolder: WatchedFolder) -> Set<String>? {
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return nil
        }

        if let dir = PathUtils.createTmpDir() {
            let file = "allfileslackingcopies.txt"
            let resultsFileAbsolutePath = "\(dir)/\(file)"
            
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: gitAnnexCmd, limitToMasterBranch: true, args: "find", "--fast", "--lackingcopies=1", ">\"\(resultsFileAbsolutePath)\"")
            
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
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return nil
        }

        if let dir = PathUtils.createTmpDir() {
            let file = "whereisallfiles.json"
            let resultsFileAbsolutePath = "\(dir)/\(file)"
            
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: gitAnnexCmd, limitToMasterBranch: true, args: "--json", "--fast", "whereis", ".", ">\"\(resultsFileAbsolutePath)\"")

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
        TurtleLog.debug("git-annex info \(path) in \(watchedFolder)")
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return (error: true, pathStatus: nil)
        }

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
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, limitToMasterBranch: true, args: "--json", "--fast", "info", "\"\(path)\"")
        
        if status != 0 {
            TurtleLog.error("path='\(path)' in='\(workingDirectory) status= \(status) output=\(output) error=\(error)")
        }
        
        let modificationDate = Date().timeIntervalSince1970 as Double
        
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
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return nil
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, limitToMasterBranch: true, args: "--json", "--fast", "whereis", "\"\(path)\"")
        
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
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return nil
        }

        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: gitAnnexCmd, limitToMasterBranch: true, args: "--json", "--fast", "--lackingcopies=1", "find", "\"\(path)\"")
        
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
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return []
        }

        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "changedAnnexFilesAfterCommit", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, limitToMasterBranch: false, args: commitHash, gitCmd)
            
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
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return []
        }

        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "changedGitFilesAfterCommit", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, limitToMasterBranch: false, args: commitHash, gitCmd)
            
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
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return []
        }

        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "allChangedGitFiles", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, limitToMasterBranch: false, args: gitCmd)
            
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
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return nil
        }

        let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: gitCmd, limitToMasterBranch: false, args: "log", "--pretty=format:\"%H\"", "-r", "git-annex", "-n", "1")
        
        if(status == 0){ // success
            if output.count == 1 {
                return output.first
            }
        }
        
        TurtleLog.error("status= \(status) output=\(output) error=\(error)")
        return nil
    }
    
    func latestGitCommitHashBlocking(in watchedFolder: WatchedFolder) -> String? {
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return nil
        }

        let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: gitCmd, limitToMasterBranch: false, args: "log", "--pretty=format:\"%H\"", "-n", "1", "master")
        
        if(status == 0){ // success
            if output.count == 1 {
                return output.first
            }
        }
        
        TurtleLog.debug("missing git commit hash, this is OK, since only mixed-mode repos need to commit to the git branch, status= \(status) output=\(output) error=\(error)")
        return nil
    }
    
    func immediateChildrenNotIgnored(relativePath: String, in watchedFolder: WatchedFolder) -> [String] {
        guard let gitAnnexCmd = preferences.gitAnnexBin() else {
            TurtleLog.debug("could not find a valid git-annex application")
            return []
        }
        guard let gitCmd = preferences.gitBin() else {
            TurtleLog.debug("could not find a valid git application")
            return []
        }

        let bundle = Bundle(for: ShellScripts.self)
        if let scriptPath: String = bundle.path(forResource: "childrenNotIgnored", ofType: "sh") {
            let (output, error, status) = runCommand(workingDirectory: watchedFolder.pathString, cmd: scriptPath, limitToMasterBranch: false, args: relativePath, gitCmd, gitAnnexCmd)
            
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
