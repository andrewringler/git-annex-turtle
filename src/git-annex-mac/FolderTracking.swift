//
//  FolderTracking.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 2/23/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class FolderTracking {
    //
    // Folder Updates
    //
    // a folder is ready to display badge icons
    // once all of its children have their data computed
    //
    public static func handleFolderUpdates(watchedFolder: WatchedFolder, queries: Queries, gitAnnexQueries: GitAnnexQueries) -> Bool {
        let foldersNeedingUpdates = queries.foldersIncompleteOrInvalidBlocking(in: watchedFolder)
        
        /* For each folder that needs updating, lets
         * see if we now have enough information to mark it as complete
         *
         * handle longest paths first, to ensure all children are handled
         * before their parent
         */
        let sortedByLongestPath = PathUtils.sortedDeepestDirFirst(foldersNeedingUpdates)
        for folderNeedingUpdate in sortedByLongestPath {
            TurtleLog.debug("Checking if folder is now up to date from incremental scan \(folderNeedingUpdate) in \(watchedFolder)")
            var enoughCopiesAllChildren: EnoughCopies?
            var leastCopies: UInt8?
            var presentAll: Present?
            let statuses = queries.childStatusesOfBlocking(parentRelativePath: folderNeedingUpdate, in: watchedFolder)
            
            let children: Set<String> = Set(gitAnnexQueries.immediateChildrenNotIgnored(relativePath: folderNeedingUpdate, in: watchedFolder))
            
            let pathsForStatuses = Set(statuses.map { $0.path })
            
            // We are missing database entries for this folder
            // lets update, then check this folder again later
            let childrenWithoutEntries = children.subtracting(pathsForStatuses)
            if childrenWithoutEntries.count > 0 {
                TurtleLog.debug("Children of folder has changed \(folderNeedingUpdate) in \(watchedFolder) missing \(childrenWithoutEntries)")
                for child in childrenWithoutEntries {
                    TurtleLog.debug("Adding missing entry for \(child) in \(folderNeedingUpdate) in \(watchedFolder)")
                    // TODO add these to HandleStatusRequests directly?
                    queries.addRequestV2Async(for: child, in: watchedFolder)
                }
                break // check this folder again later
            }
            
            var complete = true
            var allEmptyFolders = true
            
            // if files or folders have been deleted we will have statuses for them in the database
            // ignore them
            let statusesActualWorkingTree = statuses.filter { children.contains($0.path) }
            
            // TODO delete statuses that are no longer in working tree?
            
            for status in statusesActualWorkingTree {
                if status.isEmptyFolder() {
                    // ignore empty folders, they do not contribute to any counts
                    continue
                }
                allEmptyFolders = false
                
                if status.isGitAnnexTracked {
                    if let numberOfCopies = status.numberOfCopies, let enoughCopies = status.enoughCopies, let present = status.presentStatus {
                        if leastCopies == nil {
                            leastCopies = numberOfCopies
                        } else if let leastCopiesValue = leastCopies, numberOfCopies < leastCopiesValue {
                            leastCopies = numberOfCopies
                        }
                        if enoughCopiesAllChildren == nil {
                            enoughCopiesAllChildren = enoughCopies
                        } else if let enoughCopiesAllChildrenValue = enoughCopiesAllChildren {
                            enoughCopiesAllChildren = enoughCopiesAllChildrenValue && enoughCopies
                        }
                        if presentAll == nil {
                            presentAll = present
                        } else if let presentAllValue = presentAll {
                            presentAll = presentAllValue && present
                        }
                    } else {
                        complete = false
                        break
                    }
                }
            }
            
            if allEmptyFolders || statuses.count == 0 {
                // We have an empty directory, or an empty directory
                // filled with empty directories
                // the following combination signifies this
                enoughCopiesAllChildren = .enough
                leastCopies = nil
                presentAll = .present
            }
            
            if complete, let enoughCopies = enoughCopiesAllChildren, let present = presentAll {
                TurtleLog.debug("Folder now has full information \(folderNeedingUpdate) in \(watchedFolder) \(enoughCopies) \(String(describing: leastCopies)) \(present)")
                
                queries.updateStatusForPathV2Blocking(presentStatus: present, enoughCopies: enoughCopies, numberOfCopies: leastCopies, isGitAnnexTracked: true, for: folderNeedingUpdate, key: nil, in: watchedFolder, isDir: true, needsUpdate: false)
                
                // Invalidate our parent, if we have one
                if let parent = PathUtils.parent(for: folderNeedingUpdate, in: watchedFolder) {
                    queries.invalidateDirectory(path: parent, in: watchedFolder)
                }
            }
        }
        
        return true // finished successfully
    }
    
    //
    // Folder Updates
    //
    // a folder is ready to display badge icons
    // once all of its children have their data computed
    //
    public static func handleFolderUpdatesFromFullScan(watchedFolder: WatchedFolder, queries: Queries, gitAnnexQueries: GitAnnexQueries, stopProcessingWatchedFolder: StopProcessingWatchedFolder) -> Bool {
        let foldersNeedingUpdates = queries.foldersIncompleteOrInvalidBlocking(in: watchedFolder)
        
        /* handle longest paths first, to ensure all children are handled
         * before their parent
         */
        let sortedByLongestPath = PathUtils.sortedDeepestDirFirst(foldersNeedingUpdates)
        TurtleLog.trace("Handling folder updates in order: \(sortedByLongestPath)")
        for folderNeedingUpdate in sortedByLongestPath {
            if stopProcessingWatchedFolder.shouldStop(watchedFolder) {
                return false
            }
            
            TurtleLog.trace("Checking if folder is now up to date from fullscan \(folderNeedingUpdate) in \(watchedFolder)")
            var enoughCopiesAllChildren: EnoughCopies?
            var leastCopies: UInt8?
            var presentAll: Present?
            let statuses = queries.childStatusesOfBlocking(parentRelativePath: folderNeedingUpdate, in: watchedFolder)
            
            var complete = true
            var allEmptyFolders = true
            for status in statuses {
                if status.isEmptyFolder() {
                    // ignore empty folders, they do not contribute to any counts
                    continue
                }
                allEmptyFolders = false
                
                if status.isGitAnnexTracked {
                    if let numberOfCopies = status.numberOfCopies, let enoughCopies = status.enoughCopies, let present = status.presentStatus {
                        if leastCopies == nil {
                            leastCopies = numberOfCopies
                        } else if let leastCopiesValue = leastCopies, numberOfCopies < leastCopiesValue {
                            leastCopies = numberOfCopies
                        }
                        if enoughCopiesAllChildren == nil {
                            enoughCopiesAllChildren = enoughCopies
                        } else if let enoughCopiesAllChildrenValue = enoughCopiesAllChildren {
                            enoughCopiesAllChildren = enoughCopiesAllChildrenValue && enoughCopies
                        }
                        if presentAll == nil {
                            presentAll = present
                        } else if let presentAllValue = presentAll {
                            presentAll = presentAllValue && present
                        }
                    } else {
                        TurtleLog.error("Missing information for \(status)")
                        complete = false
                        break
                    }
                }
            }
                    
            if allEmptyFolders || statuses.count == 0 {
                // We have an empty directory, or an empty directory
                // filled with empty directories
                // the following combination signifies this
                enoughCopiesAllChildren = .enough
                leastCopies = nil
                presentAll = .present
            }
            
            if complete, let enoughCopies = enoughCopiesAllChildren, let present = presentAll {
                TurtleLog.debug("Folder now has full information \(folderNeedingUpdate) in \(watchedFolder) \(enoughCopies) \(String(describing: leastCopies)) \(present)")
                
                queries.updateStatusForPathV2Blocking(presentStatus: present, enoughCopies: enoughCopies, numberOfCopies: leastCopies, isGitAnnexTracked: true, for: folderNeedingUpdate, key: nil, in: watchedFolder, isDir: true, needsUpdate: false)
                
                // Invalidate our parent, if we have one
                if let parent = PathUtils.parent(for: folderNeedingUpdate, in: watchedFolder) {
                    queries.invalidateDirectory(path: parent, in: watchedFolder)
                }
            } else {
                TurtleLog.trace("Unable to complete folder information for \(folderNeedingUpdate) in \(watchedFolder)")
            }
        }
        
        return true // finished successfully
    }
}
