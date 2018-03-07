//
//  TurtleLog.swift
//  git-annex-shared
//
//  Created by Andrew Ringler on 3/6/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class TurtleLog {
    private static var LOG_LEVEL = TurtleLogLogLevel.info
    private static let pound = "\u{0023}"
    
    enum TurtleLogLogLevel: Int {
        case debug = 5
        case info = 4
        case todo = 3
        case error = 2
        case fatal = 1
        case none = 0
        
        public func allow() -> Bool {
            return self.rawValue <= TurtleLog.LOG_LEVEL.rawValue
        }
    }
    
    public static func setLoggingLevel(_ loggingLevel: TurtleLogLogLevel) {
        LOG_LEVEL = loggingLevel
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