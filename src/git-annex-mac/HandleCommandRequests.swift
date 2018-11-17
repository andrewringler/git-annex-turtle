//
//  HandleCommandRequests.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 4/9/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class HandleCommandRequests: StoppableService {
    private let hasWatchedFolders: HasWatchedFolders
    private let queries: Queries
    private let gitAnnexQueries: GitAnnexQueries
    private let dialogs: Dialogs
    private var handler: RunNowOrAgain?

    init(hasWatchedFolders: HasWatchedFolders, queries: Queries, gitAnnexQueries: GitAnnexQueries, dialogs: Dialogs) {
        self.hasWatchedFolders = hasWatchedFolders
        self.queries = queries
        self.gitAnnexQueries = gitAnnexQueries
        self.dialogs = dialogs
        super.init()
        handler = RunNowOrAgain({
            self.handleCommandRequests()
        })
    }

    public func handleNewRequests() {
        handler?.runTaskAgain()
    }
    
    //
    // Command Requests
    //
    // handle command requests "git annex get/add/drop/etc…" comming from our Finder Sync extensions
    //
    private func handleCommandRequests() -> Bool {
        let commandRequests = queries.fetchAndDeleteCommandRequestsBlocking()
        
        for commandRequest in commandRequests {
            if let watchedFolder = hasWatchedFolders.getWatchedFolders().first(where: { $0.uuid.uuidString == commandRequest.watchedFolderUUIDString }) {
                switch commandRequest.commandType {
                case .gitAnnex:
                    let status = gitAnnexQueries.gitAnnexCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString, limitToMasterBranch: true)
                    if !status.success {
                        // git-annex has very nice error message, use them as-is
                        dialogs.dialogGitAnnexWarn(title: status.error.first ?? "git-annex: error", message: status.output.joined(separator: "\n"))
                    } else {
                        // nothing to do on success, our .git/config watch should find this
                    }
                    
                case .git:
                    let status = gitAnnexQueries.gitCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString, limitToMasterBranch: true)
                    if !status.success {
                        dialogs.dialogGitAnnexWarn(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                    } else {
                        // nothing to do on success, our .git/config watch should find this
                    }
                    
                case .turtle:
                    if commandRequest.commandString == CommandString.share {
                        if(watchedFolder.shareRemote != nil) {
                            let status = gitAnnexQueries.gitAnnexExport(for: commandRequest.pathString, in: watchedFolder.pathString, to: watchedFolder.shareRemote!)
                            if !status.success {
                                dialogs.dialogGitAnnexWarn(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                            } else {
                                // TODO place public URL in user's clipboard
                                // or show dialog with the public URL
                            }
                        } else {
                            TurtleLog.todo("don't show Share menu if no share remote configured \(commandRequest.commandString) for \(commandRequest.pathString) in \(watchedFolder.pathString)")
                        }
                    } else {
                        TurtleLog.todo("handle Turtle command \(commandRequest.commandString) for \(commandRequest.pathString) in \(watchedFolder.pathString)")
                    }
                }
                
            } else {
                TurtleLog.error("Could not find watched folder for \(commandRequest)")
            }
        }
        
        return commandRequests.count > 0
    }
    
    public override func stop() {
        handler?.stop()
        super.stop()
    }
}
