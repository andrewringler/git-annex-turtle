//
//  TurtleConfigV1.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 2/21/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

// Defaults
let finderIntegrationMissingDefault = false
let contextMenusMissingDefault = false
let trackFolderStatusMissingDefault = false
let trackFileStatusMissingDefault = false

let finderIntegrationNewEntryDefault = true
let contextMenusNewEntryDefault = true
let trackFolderStatusNewEntryDefault = true
let trackFileStatusNewEntryDefault = true

/* We have versioned the config classes but as long as we just add
 * additionally fields and gracefully handle them when they are missing
 * there is no reason to rev the version number */
fileprivate class TurtleConfigMonitoredRepoMutableV1: CustomStringConvertible {
    var name: String? = nil
    var path: String? = nil
    var finderIntegration: Bool? = nil
    var contextMenus: Bool? = nil
    var trackFolderStatus: Bool? = nil
    var trackFileStatus: Bool? = nil
    var shareRemote: String? = nil
    var shareLocalPath: String? = nil

    init() {}
    
    class func from(_ c: TurtleConfigMonitoredRepoV1) -> TurtleConfigMonitoredRepoMutableV1 {
        let newC = TurtleConfigMonitoredRepoMutableV1()
        newC.name = c.name
        newC.path = c.path
        newC.finderIntegration = c.finderIntegration
        newC.contextMenus = c.contextMenus
        newC.trackFolderStatus = c.trackFolderStatus
        newC.trackFileStatus = c.trackFileStatus
        newC.shareRemote = c.shareRemote
        newC.shareLocalPath = c.shareLocalPath
        return newC
    }
    
    func build() -> TurtleConfigMonitoredRepoV1? {
        if path != nil {
            return TurtleConfigMonitoredRepoV1(name: name, path: path!, finderIntegration: finderIntegration ?? finderIntegrationMissingDefault, contextMenus: contextMenus ?? contextMenusMissingDefault, trackFolderStatus: trackFolderStatus ?? trackFolderStatusMissingDefault, trackFileStatus: trackFileStatus ?? trackFileStatusMissingDefault, shareRemote: shareRemote, shareLocalPath: shareLocalPath)
        }
        
        return nil
    }
    
    public var description: String { return "TurtleConfigMonitoredRepoMutableV1: '\(name)' '\(path)' finderIntegration='\(finderIntegration)' contextMenus='\(contextMenus)' trackFolderStatus='\(trackFolderStatus)' trackFileStatus='\(trackFileStatus)' shareRemote='\(shareRemote)' shareLocalPath='\(shareLocalPath)'" }
}
fileprivate class TurtleConfigMutableV1: CustomStringConvertible {
    // General Turtle Config
    var gitAnnexBin: String? = nil
    var gitBin: String? = nil
    
    // Monitored Repos Config
    var monitoredRepo: [TurtleConfigMonitoredRepoMutableV1] = []
    
    init() {}
    
    func build() -> TurtleConfigV1? {
        var repos = Set<TurtleConfigMonitoredRepoV1>()
        for repoBuilder in monitoredRepo {
            if let repo = repoBuilder.build() {
                repos.insert(repo)
            } else {
                TurtleLog.error("Invalid repo \(repoBuilder) for config \(self)")
                return nil
            }
        }
        return TurtleConfigV1(gitAnnexBin: gitAnnexBin, gitBin: gitBin, monitoredRepo: repos)
    }
    
    public var description: String { return "TurtleConfigMutableV1: '\(gitAnnexBin)' '\(gitBin)' \(monitoredRepo)" }
}

struct TurtleConfigMonitoredRepoV1 {
    let name: String?
    
    let path: String
    let finderIntegration: Bool
    let contextMenus: Bool
    let trackFolderStatus: Bool
    let trackFileStatus: Bool
    let shareRemote: String?
    let shareLocalPath: String?
    
    public func toFileString() -> String {
        var s: String = ""
        if name != nil {
            s += "[\(sectionType.turtleMonitor.rawValue) \"\(name!)\"]\n"
        } else {
            s += "[\(sectionType.turtleMonitor.rawValue)]\n"
        }
        s += "\(turtleSectionMonitorKeyValueName.path.rawValue) = \(path)\n"
        
        s += "\(turtleSectionMonitorKeyValueName.finderIntegration.rawValue) = \(String(finderIntegration))\n"
        s += "\(turtleSectionMonitorKeyValueName.contextMenus.rawValue) = \(String(contextMenus))\n"
        s += "\(turtleSectionMonitorKeyValueName.trackFolderStatus.rawValue) = \(String(trackFolderStatus))\n"
        s += "\(turtleSectionMonitorKeyValueName.trackFileStatus.rawValue) = \(String(trackFileStatus))\n"
        if shareRemote != nil && shareLocalPath != nil {
            s += "\(turtleSectionMonitorKeyValueName.shareRemote.rawValue) = \(String(describing: shareRemote))\n"
            s += "\(turtleSectionMonitorKeyValueName.shareLocalPath.rawValue) = \(String(describing: shareLocalPath))\n"
        }

        return s
    }
    
    static func fromPathWithDefaults(_ path: String) -> TurtleConfigMonitoredRepoV1 {
        return TurtleConfigMonitoredRepoV1(name: nil, path: path, finderIntegration: finderIntegrationNewEntryDefault, contextMenus: contextMenusNewEntryDefault, trackFolderStatus: trackFolderStatusNewEntryDefault, trackFileStatus: trackFileStatusNewEntryDefault, shareRemote: nil, shareLocalPath: nil)
    }
}
extension TurtleConfigMonitoredRepoV1: Equatable, Hashable {
    static func == (lhs: TurtleConfigMonitoredRepoV1, rhs: TurtleConfigMonitoredRepoV1) -> Bool {
        return lhs.path == rhs.path
    }
    
    var hashValue: Int {
        return path.hashValue
    }
}

enum sectionType: String {
    case turtle = "turtle"
    case turtleMonitor = "turtle-monitor"
}
enum turtleSectionKeyValueName: String {
    case gitAnnexBin = "git-annex-bin"
    case gitBin = "git-bin"
}
enum turtleSectionMonitorKeyValueName: String {
    case path = "path"
    case finderIntegration = "finder-integration"
    case contextMenus = "context-menus"
    case trackFolderStatus = "track-folder-status"
    case trackFileStatus = "track-file-status"
    case shareRemote = "share-remote"
    case shareLocalPath = "share-local-path"
}

struct TurtleConfigV1 {
    // General Turtle Config
    let gitAnnexBin: String?
    let gitBin: String?
    
    // Monitored Repos Config
    let monitoredRepo: Set<TurtleConfigMonitoredRepoV1>
    
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
     * share-remote = public-s3
     * share-local-path = public-share
     */
    // see https://developer.apple.com/documentation/foundation/nsregularexpression for syntax
    static let whitespace = "^[\\s]*$"
    static let turtleSectionRegex = "^[\\s]*\\[turtle\\][\\s]*$"
    static let turtleMonitorSectionRegex = "^[\\s]*\\[turtle-monitor(?:[\\s]+\"(.*)\")?\\][\\s]*$"
//    static let keyValuePairRegex = "[\\s]*(.+)[\\s]*\\=\"?(.+)\"?[\\s]*"
    static let keyValuePairRegex = "^[\\s]*([a-z\\-]+)[\\s]*\\=[\\s]*\"?(.+?)\"?[\\s]*$"

    public func repoPaths() -> [WatchedRepoConfig] {
        return monitoredRepo.map { WatchedRepoConfig($0.path, $0.shareRemote, $0.shareLocalPath) }
    }
    
    public func removeRepo(_ repo: String) -> TurtleConfigV1 {
        return TurtleConfigV1(gitAnnexBin: gitAnnexBin, gitBin: gitBin, monitoredRepo: monitoredRepo.filter { $0.path != repo })
    }
    public func addRepo(_ repo: String) -> TurtleConfigV1 {
        var newMonitoredRepo = monitoredRepo
        newMonitoredRepo.insert(TurtleConfigMonitoredRepoV1.fromPathWithDefaults(repo))
        return TurtleConfigV1(gitAnnexBin: gitAnnexBin, gitBin: gitBin, monitoredRepo: newMonitoredRepo)
    }
    public func setGitBin(_ newGitBin: String) -> TurtleConfigV1 {
        return TurtleConfigV1(gitAnnexBin: gitAnnexBin, gitBin: newGitBin, monitoredRepo: monitoredRepo)
    }
    public func setGitAnnexBin(_ newGitAnnexBin: String) -> TurtleConfigV1 {
        return TurtleConfigV1(gitAnnexBin: newGitAnnexBin, gitBin: gitBin, monitoredRepo: monitoredRepo)
    }
    public func setShareRemote(_ repo: String, _ newShareRemote: String, _ newShareLocalPath: String) -> TurtleConfigV1 {
        var newRepo: TurtleConfigMonitoredRepoMutableV1?
        monitoredRepo.forEach {
            if $0.path == repo {
                newRepo = TurtleConfigMonitoredRepoMutableV1.from($0)
                newRepo!.shareRemote = newShareRemote
                newRepo!.shareLocalPath = newShareLocalPath
            }
        }
        _ = removeRepo(repo)
        var newMonitoredRepo = monitoredRepo
        if newRepo != nil {
            newMonitoredRepo.insert(newRepo!.build()!)
        }
        return TurtleConfigV1(gitAnnexBin: gitAnnexBin, gitBin: gitBin, monitoredRepo: newMonitoredRepo)
    }

    public func toFileString() -> String {
        var s: String = ""
        if gitBin != nil || gitAnnexBin != nil {
            s += "[\(sectionType.turtle.rawValue)]\n"
            if gitAnnexBin != nil {
                s += "\(turtleSectionKeyValueName.gitAnnexBin.rawValue) = \(gitAnnexBin!)\n"
            }
            if gitBin != nil {
                s += "\(turtleSectionKeyValueName.gitBin.rawValue) = \(gitBin!)\n"
            }
        }
        
        for repo in monitoredRepo {
            s += "\n"
            s += repo.toFileString()
        }
        
        return s
    }
    
    public static func parse(from config: [String]) -> TurtleConfigV1? {
        var turtleConfig = TurtleConfigMutableV1()
        var repo: TurtleConfigMonitoredRepoMutableV1?
        var section: sectionType?
        
        let configLines = config.filter({ $0.count > 0 }) // remove empty lines
        
        for line in configLines {
            // https://git-scm.com/docs/git-config#_syntax
            // ignore comments and blank lines
            if line.starts(with: "#") || line.starts(with: ";") || line.firstMatchThenGroups(for: whitespace).count == 1 {
                continue
            }
            
            if isTurtleSection(line) {
                // switching sections?, save turtle monitor
                if section == .turtleMonitor {
                    turtleConfig.monitoredRepo.append(repo!)
                }
                
                section = .turtle
                continue
            }
            
            let turtleMonitor = turtleMonitorSection(line)
            if turtleMonitor.turtleMonitorSection {
                // starting a new turtle monitor section?, save the old one
                if section == .turtleMonitor {
                    turtleConfig.monitoredRepo.append(repo!)
                }
                
                section = .turtleMonitor
                repo = TurtleConfigMonitoredRepoMutableV1()
                repo?.name = turtleMonitor.name
                continue
            }
            
            // first non-comment line, should be a section
            if section == nil {
                TurtleLog.error("Invalid config, expecting section at line: \(line) for config: \(config)")
                return nil
            }

            // looking for a key = value pair
            let keyValuePair = line.firstMatchThenGroups(for: keyValuePairRegex)
            if keyValuePair.count == 3 {
                let key = keyValuePair[1]
                let value = keyValuePair[2]
                switch section! {
                case .turtle:
                    if let name = turtleSectionKeyValueName(rawValue: key) {
                        switch name {
                        case .gitAnnexBin:
                            turtleConfig.gitAnnexBin = value
                        case .gitBin:
                            turtleConfig.gitBin = value
                        }
                        continue
                    }
                    TurtleLog.error("Invalid key = value pair for [turtle] section at line: \(line) for config: \(config)")
                    return nil
                case .turtleMonitor:
                    if let name = turtleSectionMonitorKeyValueName(rawValue: key) {
                        do {
                            switch name {
                            case .path:
                                repo?.path = value
                            case .finderIntegration:
                                repo?.finderIntegration = try Bool(value)
                            case .contextMenus:
                                repo?.contextMenus = try Bool(value)
                            case .trackFolderStatus:
                                repo?.trackFolderStatus = try Bool(value)
                            case .trackFileStatus:
                                repo?.trackFileStatus = try Bool(value)
                            case .shareRemote:
                                repo?.shareRemote = value
                            case .shareLocalPath:
                                repo?.shareLocalPath = value
                            }
                        } catch {
                            TurtleLog.error("Invalid key = value pair at line: \(line) for config: \(config)")
                            return nil
                        }
                        continue
                    }
                    TurtleLog.error("Invalid key = value pair for [turtle-monitor] section at line: \(line) for config: \(config)")
                    return nil
                }
                
                TurtleLog.error("Unknown attribute name at line: \(line) for config: \(config)")
                return nil
            }
                
            TurtleLog.error("Invalid config, expecting key = value pair or new section for line: \(line) with config: \(config)")
            return nil
        }

        if section == .turtleMonitor {
            turtleConfig.monitoredRepo.append(repo!)
        }
        
        return turtleConfig.build()
    }
    
    public static func isTurtleSection(_ line: String) -> Bool {
        return line.firstMatchThenGroups(for: turtleSectionRegex).count == 1
    }
    public static func turtleMonitorSection(_ line: String) -> (turtleMonitorSection: Bool, name: String?) {
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
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }
        
        for i in 0..<match.numberOfRanges {
            let capturedGroupRange = match.range(at: i)
            
            // why are we getting invalid ranges when a capturing group doesn't match!?
            if capturedGroupRange.location >= 0, capturedGroupRange.location < self.count {
                let matchedString = (self as NSString).substring(with: capturedGroupRange)
                
                // why are we getting capturing groups for the entire string again?
                if (matchedString as String) != results[0] {
                    results.append(matchedString)
                }
            }
        }
        
        return results
    }
}
