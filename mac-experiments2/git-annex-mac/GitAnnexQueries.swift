//
//  GitAnnexQueries.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 12/31/17.
//  Copyright © 2017 Andrew Ringler. All rights reserved.
//

import Foundation

class GitAnnexQueries {
    // TODO one queue per repository
    static let gitAnnexQueryQueue = DispatchQueue(label: "com.andrewringler.git-annex-mac.shellcommandqueue")
    
    // https://gist.github.com/brennanMKE/a0a2ee6aa5a2e2e66297c580c4df0d66
    fileprivate class func directoryExistsAtPath(_ path: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
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
        
        gitAnnexQueryQueue.sync {
            var output : [String] = []
            var error : [String] = []
            
            /* check for a valid working directory now, because Process will not let us catch
             * the exception thrown if the directory is invalid */
            if !directoryExistsAtPath(workingDirectory) {
                NSLog("Invalid working directory '%@'", workingDirectory)
                return
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
        }
        
        return ret
    }

    class func gitAnnexCommand(for url: URL, in workingDirectory: String, cmd: GitAnnexCommand) -> Bool {
        let path :String = (url as NSURL).path!
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", cmd.cmdString, path)
        
        NSLog("git annex %@ %@",cmd.cmdString,path)
        if status != 0 {
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        return status == 0
    }
    class func gitCommand(for url: URL, in workingDirectory: String, cmd: GitCommand) -> Bool {
        let path :String = (url as NSURL).path!
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: cmd.cmdString, path)
        
        NSLog("git %@ %@",cmd.cmdString,path)
        if status != 0 {
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        return status == 0
    }
    class func gitGitAnnexUUID(in workingDirectory: String) -> UUID? {
        // is this folder even a directory?
        if !directoryExistsAtPath(workingDirectory) {
            NSLog("Not a valid git-annex folder, nor even a directory '%@'", workingDirectory)
            return nil
        }
        
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git", args: "config", GitConfigs.AnnexUUID.name)
        
        NSLog("git config %@",GitConfigs.AnnexUUID.name)
        if status == 0, output.count == 1 {
            for uuidString in output {
                if let uuid = UUID(uuidString: uuidString) {
                    return uuid
                }
                break
            }
        }
        
        NSLog("status: %@", String(status))
        NSLog("output: %@", output)
        NSLog("error: %@", error)
        return nil
    }
    class func gitAnnexPathInfo(for url: URL, in workingDirectory: String) -> String {
        let path :String = (url as NSURL).path!
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "--fast", "info", path)
        
        if status != 0 {
            NSLog("gitAnnexPathInfo")
            NSLog("status: %@", String(status))
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        // if command didnt return an error, parse the JSON
        // https://stackoverflow.com/questions/25621120/simple-and-clean-way-to-convert-json-string-to-object-in-swift
        if(status == 0){
            do {
                var data: Data = (output.first as! NSString).data(using: String.Encoding.utf8.rawValue)!
                var json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))
                
                if let dictionary = json as? [String: Any] {
                    let success = dictionary["success"]
                    let present = dictionary["present"]
                    let file = dictionary["file"]
                    let directory = dictionary["directory"]
                    let localAnnexKeys = dictionary["local annex keys"]
                    let annexedFilesInWorkingTree = dictionary["annexed files in working tree"]
                    let command = dictionary["command"]
                    
                    // a file in the annex that is present
                    if success != nil && (success as! Bool) == true
                        && present != nil && (present as! Bool) == true {
                        return "present"
                    }
                    
                    // a file in the annex that is not present
                    if success != nil && (success as! Bool) == true
                        && present != nil && (present as! Bool) == false {
                        return "absent"
                    }
                    
                    // a directory in the annex who has all the content
                    // of all his containing files recursively
                    if success != nil && (success as! Bool) == true
                        && localAnnexKeys != nil && annexedFilesInWorkingTree != nil
                        && (annexedFilesInWorkingTree as! Int) == (localAnnexKeys as! Int) {
                        return "present"
                    }
                    
                    // a directory in the annex who is missing all
                    // content from some all of his containing files recursively
                    if success != nil && (success as! Bool) == true
                        && localAnnexKeys != nil && annexedFilesInWorkingTree != nil
                        && (localAnnexKeys as! Int) < (annexedFilesInWorkingTree as! Int)
                        && (localAnnexKeys as! Int) == 0
                    {
                        return "absent"
                    }
                    
                    // a directory in the annex who is missing some
                    // content from some of his containing files recursively
                    if success != nil && (success as! Bool) == true
                        && localAnnexKeys != nil && annexedFilesInWorkingTree != nil
                        && (localAnnexKeys as! Int) < (annexedFilesInWorkingTree as! Int)
                        && (localAnnexKeys as! Int) > 0
                    {
                        return "partially-present-directory"
                    }
                }
            } catch {
                NSLog("unable to parse JSON: '", output, "'")
            }
        }
        return "unknown"
    }
}
