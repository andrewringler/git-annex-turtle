//
//  GitAnnexQueries.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 12/31/17.
//  Copyright © 2017 Andrew Ringler. All rights reserved.
//

import Foundation

class GitAnnexQueries {
    // https://stackoverflow.com/questions/29514738/get-terminal-output-after-a-command-swift
    private class func runCommand(workingDirectory: String, cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {
        
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
        
        let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            output = string.components(separatedBy: "\n")
        }
        
        let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: errdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            error = string.components(separatedBy: "\n")
        }
        
        task.waitUntilExit()
        let status = task.terminationStatus
        
        return (output, error, status)
    }
    
    class func gitAnnexPathInfo(for url: URL, in workingDirectory: String) -> String {
//        url.standardizedFileURL
        let path :String = (url as NSURL).path!
        let (output, error, status) = runCommand(workingDirectory: workingDirectory, cmd: "/Applications/git-annex.app/Contents/MacOS/git-annex", args: "--json", "info", path)
        
//        NSLog("git annex info for " + path)
//        NSLog("status: %@", status)
//        NSLog("output: %@", output)
//        NSLog("error: %@", error)
        
        // if command didnt return an error, parse the JSON
        // https://stackoverflow.com/questions/25621120/simple-and-clean-way-to-convert-json-string-to-object-in-swift
        if(status == 0){
//            var json: Any
            do {
//                 (output as NSString).data
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


//                    var msg :String = "command [" + (command as! String) + "]" + " present=" + (present as! String) + " success=" + (success as! String)
//
//                    NSLog(msg)
                    
//                    if let success = dictionary["success"] {
//                        if success as! Bool == true, let present = dictionary["present"] {
//
//                            if(present as! Bool == true){
//                                return "present"
//                            } else {
//                                return "absent"
//                            }
//                        }
//                        // access individual value in dictionary
////                        NSLog("found success int " + String(success))
//                    }
                }
                
            } catch {
                NSLog("unable to parse JSON: '", output, "'")
            }

//            guard let item = json.first as [String: Any],
//                let present = item["present"] as? Bool,
//                let success = item["success"] as? Bool else {
//                    return
//            }
            
//            json?.
//            guard let success = json.first["success"] as? Bool,
//                let person = json["present"] as? Bool else {
//                    return
//            }
            
//            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            
        }
        
        return "unknown"
    }
}

