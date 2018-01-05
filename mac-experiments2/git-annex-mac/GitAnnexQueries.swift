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
    
    /* Adapted from https://stackoverflow.com/questions/29514738/get-terminal-output-after-a-command-swift
     * with fixes for leaving dangling open file descriptors from here:
     * http://www.cocoabuilder.com/archive/cocoa/289471-file-descriptors-not-freed-up-without-closefile-call.html
    */
    private class func runCommand(workingDirectory: String, cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {
        // protect access to git annex, I don't think you can query it
        // too heavily concurrently on the same repo, and plus I was getting
        // too many open files warnings
        // when I let all my processes access this method
        
        // ref on threading https://medium.com/@irinaernst/swift-3-0-concurrent-programming-with-gcd-5ee51e89091f
        var ret: (output: [String], error: [String], exitCode: Int32) = ([""], ["ERROR: task did not run"], -1)
        
        gitAnnexQueryQueue.sync {
            var output : [String] = []
            var error : [String] = []
            
            let task = Process()
            task.launchPath = cmd
            task.currentDirectoryPath = workingDirectory
            task.arguments = args
            
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

    class func gitAnnexGet(for url: URL, in workingDirectory: String) -> Bool {
        let path :String = (url as NSURL).path!
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "get", path)

        if status != 0 {
            NSLog("gitAnnexGet")
            NSLog("status: %@", status)
            NSLog("output: %@", output)
            NSLog("error: %@", error)
        }
        
        return status == 0
    }

    class func gitAnnexPathInfo(for url: URL, in workingDirectory: String) -> String {
        let path :String = (url as NSURL).path!
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "--fast", "info", path)
        
        if status != 0 {
            NSLog("gitAnnexPathInfo")
            NSLog("status: %@", status)
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
