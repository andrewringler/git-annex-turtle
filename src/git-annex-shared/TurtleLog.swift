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
    // https://kitefaster.com/2016/01/23/how-to-specify-debug-and-release-flags-in-xcode-with-swift/
    #if RELEASE
        private static var LOG_LEVEL = TurtleLogLogLevel.info
    #else
        private static var LOG_LEVEL = TurtleLogLogLevel.debug
    #endif
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
}
