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
            for watchedFolder in hasWatchedFolders.getWatchedFolders() {
                if watchedFolder.uuid.uuidString == commandRequest.watchedFolderUUIDString {
                    // Is this a Git Annex Command?
                    if commandRequest.commandType.isGitAnnex {
                        let status = gitAnnexQueries.gitAnnexCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString, limitToMasterBranch: true)
                        if !status.success {
                            // git-annex has very nice error message, use them as-is
                            dialogs.dialogGitAnnexWarn(title: status.error.first ?? "git-annex: error", message: status.output.joined(separator: "\n"))
                        } else {
                            // success, update this file status right away
                            //                            self.updateStatusNowAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    // Is this a Git Command?
                    if commandRequest.commandType.isGit {
                        let status = gitAnnexQueries.gitCommand(for: commandRequest.pathString, in: watchedFolder.pathString, cmd: commandRequest.commandString, limitToMasterBranch: true)
                        if !status.success {
                            dialogs.dialogGitAnnexWarn(title: status.error.first ?? "git: error", message: status.output.joined(separator: "\n"))
                        } else {
                            // success, update this file status right away
                            //                            self.updateStatusNowAsync(for: commandRequest.pathString, in: watchedFolder)
                        }
                    }
                    
                    break
                }
            }
        }
        
        return commandRequests.count > 0
    }
    
    public override func stop() {
        handler?.stop()
        super.stop()
    }
}
