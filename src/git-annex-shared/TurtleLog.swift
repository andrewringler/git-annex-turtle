//
//  TurtleLog.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class TurtleLog {
    /* Set the LOG_LEVEL to see all logs equal to and less-then this level */
    private static var LOG_LEVEL: TurtleLogLogLevel = {
        if amIBeingDebugged() {
            return TurtleLogLogLevel.debug
        }
        return TurtleLogLogLevel.info
    }()
    private static let pound = "\u{0023}"
    
    enum TurtleLogLogLevel: Int {
        case trace = 6  // very-verbose debugging, including internal loops
        case debug = 5  // verbose debugging, should only be generated from user initiated actions
        case info = 4   // **** Production default ****
        case todo = 3   // internal TODOs / known bugs
        case error = 2  // things that shouldn't happen
        case fatal = 1  // things that should be detected immediately by a developer after a configuration change
        case none = 0
        
        public func allow() -> Bool {
            return self.rawValue <= TurtleLog.LOG_LEVEL.rawValue
        }
    }
    
    public static func setLoggingLevel(_ loggingLevel: TurtleLogLogLevel) {
        LOG_LEVEL = loggingLevel
    }
    
    public static func trace(_ format: String, _ args: CVarArg..., function: String = #function, filePath: String = #file, line: Int = #line) {
        if TurtleLogLogLevel.trace.allow() {
            let file =  (filePath as NSString).lastPathComponent
            NSLog("[trace] \(format) @\(file)->\(function) line \(pound)\(line)", args)
        }
    }
    public static func debug(_ format: String, _ args: CVarArg..., function: String = #function, filePath: String = #file, line: Int = #line) {
        if TurtleLogLogLevel.debug.allow() {
            let file =  (filePath as NSString).lastPathComponent
            NSLog("[debug] \(format) @\(file)->\(function) line \(pound)\(line)", args)
        }
    }
    public static func info(_ format: String, _ args: CVarArg..., function: String = #function, filePath: String = #file, line: Int = #line) {
        if TurtleLogLogLevel.info.allow() {
            let file =  (filePath as NSString).lastPathComponent
            NSLog("[info] \(format) @\(file)->\(function) line \(pound)\(line)", args)
        }
    }
    public static func todo(_ format: String, _ args: CVarArg..., function: String = #function, filePath: String = #file, line: Int = #line) {
        if TurtleLogLogLevel.todo.allow() {
            let file =  (filePath as NSString).lastPathComponent
            NSLog("[todo] \(format) @\(file)->\(function) line \(pound)\(line)", args)
        }
    }
    public static func error(_ format: String, _ args: CVarArg..., function: String = #function, filePath: String = #file, line: Int = #line) {
        if TurtleLogLogLevel.error.allow() {
            let file =  (filePath as NSString).lastPathComponent
            NSLog("[error] \(format) @\(file)->\(function) line \(pound)\(line)", args)
        }
    }
    public static func fatal(_ format: String, _ args: CVarArg..., function: String = #function, filePath: String = #file, line: Int = #line) {
        if TurtleLogLogLevel.fatal.allow() {
            let file =  (filePath as NSString).lastPathComponent
            NSLog("[fatal] \(format) @\(file)->\(function) line \(pound)\(line)", args)
        }
    }
    
    // https://stackoverflow.com/a/33177600/8671834
    private static func amIBeingDebugged() -> Bool {
        var info = kinfo_proc()
        var mib : [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout.stride(ofValue: info)
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        assert(junk == 0, "sysctl failed")
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
