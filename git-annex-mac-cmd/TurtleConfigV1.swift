//
//  TurtleConfigV1.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 2/21/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

struct TurtleConfigMonitoredRepoV1 {
    let name: String?
    
    let path: String
    let finderIntegration: Bool
    let contextMenus: Bool
    let trackFolderStatus: Bool
    let trackFileStatus: Bool
}
extension TurtleConfigMonitoredRepoV1: Equatable {
    static func == (lhs: TurtleConfigMonitoredRepoV1, rhs: TurtleConfigMonitoredRepoV1) -> Bool {
        return lhs.name == rhs.name &&
        lhs.path == rhs.path &&
        lhs.finderIntegration == rhs.finderIntegration &&
        lhs.contextMenus == rhs.contextMenus &&
        lhs.trackFolderStatus == rhs.trackFolderStatus &&
        lhs.trackFileStatus == rhs.trackFileStatus
    }
}

struct TurtleConfigV1 {
    // General Turtle Config
    let gitAnnexBin: String?
    let gitBin: String?
    
    // Monitored Repos Config
    let monitoredRepo: [TurtleConfigMonitoredRepoV1]
    
    /* Parse a config like:
     *
     * [turtle]
     * git-annex-bin = /Applications/git-annex.app/Contents/MacOS/git-annex
     * git-bin = /Applications/git-annex.app/Contents/MacOS/git
     *
     * [turtle-monitor "another remote yeah.hmm"]
     * path = /Users/Shared/anotherremote
     * finder-integration = true
     * context-menus = true
     * track-folder-status = true
     * track-file-status = true
     */
    static let turtleSectionRegex = "\\[turtle\\]"
//    static let turtleMonitorSectionRegex = "\\[turtle-monitor[[\\s]+[\"([a-z])\"]]?\\]"
    static let turtleMonitorSectionRegex = "\\[turtle-monitor(?:[\\s]+\"(.*)\")?\\]"
//    static let turtleMonitorSectionRegex = "\\[turtle-monitor\\]"
    public static func parse(from config: [String]) -> TurtleConfigV1? {
        if config.count < 2 {
            return nil
        }
        
        let configLines = config.filter({ $0.count > 0 }) // remove empty lines
        var lineCount = 0
        for line in configLines {
            // first line must be a section
            if lineCount == 0 {
                // turtle section?
//                let matches = turtleSectionRegex.matches(in: line, options: [], range: NSRange(location: 0, length: line.characters.count))
//                for match in matches {
//                    for n in 0..<match.numberOfRanges {
//                        let range = match.rangeAt(n)
//                        let r = line.startIndex.advanced(by: range.location) ..<
//                            line.startIndex.advanced(by: range.location+range.length)
//                        if let theMatch = line.substring(with: r) {
//
//                        }
//                    }
//                }
            }
            
            // otherwise we have a section or key value pair
            
            
            lineCount = lineCount + 1
        }

        return nil
    }
    
    public static func isTurtleSection(line: String) -> Bool {
        return line.firstMatchThenGroups(for: turtleSectionRegex).count == 1
    }
    public static func turtleMonitorSection(line: String) -> (turtleMonitorSection: Bool, name: String?) {
        let matched = line.firstMatchThenGroups(for: turtleMonitorSectionRegex)
        if matched.count == 1 {
            return (turtleMonitorSection: true, name: nil)
        }
        if matched.count == 2 {
            return (turtleMonitorSection: true, name: matched[1])
        }
        return (turtleMonitorSection: false, name: nil)
    }
}
extension TurtleConfigV1: Equatable {
    static func == (lhs: TurtleConfigV1, rhs: TurtleConfigV1) -> Bool {
        return lhs.gitAnnexBin == rhs.gitAnnexBin &&
            lhs.gitBin == rhs.gitBin &&
            lhs.monitoredRepo == rhs.monitoredRepo
    }
}

// https://stackoverflow.com/questions/27880650/swift-extract-regex-matches
// https://stackoverflow.com/a/40040472/8671834
//func matches(for regex: String, in text: String) -> [[String]] {
//    do {
//        let regex = try NSRegularExpression(pattern: regex)
//        let results = regex.matches(in: text,
//                                    range: NSRange(text.startIndex..., in: text))
////        return results.map {
////            String(text[Range($0.range, in: text)!])
////        }
//        return results.map { result in
//            (0..<result.numberOfRanges).map { result.rangeAt($0).location != NSNotFound
//                ? String(text[Range($0.range, in: text)!])
//                : ""
//            }
//        }
//    } catch let error {
//        print("invalid regex: \(error.localizedDescription)")
//        return []
//    }
//}

// https://stackoverflow.com/a/38807911/8671834
//func matches(for regex: String, in text: String) -> [String] {
//    do {
//        let regex = try NSRegularExpression(pattern: regex, options: [])
//        let nsString = text as NSString
//        let results = regex.matches(in: text, options: [], range: NSMakeRange(0, nsString.length))
//        var match = [String]()
//        for result in results {
//            for i in 0..<result.numberOfRanges {
//                match.append(nsString.substring(with: result.rangeAt(i as Int)))
//            }
//        }
//        return match
//    } catch let error as NSError {
//        print("invalid regex: \(error.localizedDescription)")
//        return []
//    }
//}

// http://samwize.com/2016/07/21/how-to-capture-multiple-groups-in-a-regex-with-swift/
// https://stackoverflow.com/questions/27880650/swift-extract-regex-matches
extension String {
    func firstMatchThenGroups(for pattern: String) -> [String] {
        var results = [String]()
        
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.characters.count))
        
        guard let match = matches.first else { return results }

        // pre-prend first full match (IE not a capture group)
        results.append(String(self[Range(match.range, in: self)!]))
//        for i in 0..<match.numberOfRanges {
////            results.append((self as NSString).substring(with: match.rangeAt(i as Int)))
//
//        }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }
        
        for i in 0..<match.numberOfRanges {
            let capturedGroupRange = match.range(at: i)
            // why are we getting invalid ranges when a capturing group doesn't match!?
            if capturedGroupRange.location > 0, capturedGroupRange.location < self.count {
                let matchedString = (self as NSString).substring(with: capturedGroupRange)
                results.append(matchedString)
            }
        }
        
//        for i in 1...lastRangeIndex {
//            let capturedGroupIndex = match.rangeAt(i as Int)
//            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
//            results.append(matchedString)
//        }
        
        return results
    }
}
