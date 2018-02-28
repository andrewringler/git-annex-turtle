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
    public static func handleFolderUpdates(watchedFolder: WatchedFolder, queries: Queries, gitAnnexQueries: GitAnnexQueries, fullScan: FullScan?) -> Bool {
        let foldersNeedingUpdates = queries.foldersIncompleteOrInvalidBlocking(in: watchedFolder)
        
        /* For each folder that needs updating, lets
         * see if we now have enough information to mark it as complete
         *
         * handle longest paths first, to ensure all children are handled
         * before their parent
         */
        let sortedByLongestPath = foldersNeedingUpdates.sorted {
            $0 != PathUtils.CURRENT_DIR ||
            count("/", in: $0) > count("/", in: $1) }
        for folderNeedingUpdate in sortedByLongestPath {
            if fullScan?.shouldStop(watchedFolder) ?? false {
                return false
            }
            
            NSLog("Checking if folder is now up to date \(folderNeedingUpdate) in \(watchedFolder)")
            var enoughCopiesAllChildren: EnoughCopies?
            var leastCopies: UInt8?
            var presentAll: Present?
            let statuses = queries.childStatusesOfBlocking(parentRelativePath: folderNeedingUpdate, in: watchedFolder)
            
            var children: Set<String>?
            if (Thread.isMainThread) {
                children = Set(gitAnnexQueries.immediateChildrenNotIgnored(relativePath: folderNeedingUpdate, in: watchedFolder))
            } else {
                DispatchQueue.main.sync {
                    children = Set(gitAnnexQueries.immediateChildrenNotIgnored(relativePath: folderNeedingUpdate, in: watchedFolder))
                }
            }
            
            let pathsForStatuses = Set(statuses.map { $0.path })
            
            // We are missing database entries for this folder
            // lets update, then check this folder again later
            let childrenWithoutEntries = children!.subtracting(pathsForStatuses)
            if childrenWithoutEntries.count > 0 {
                NSLog("Children of folder has changed \(folderNeedingUpdate) in \(watchedFolder) missing \(childrenWithoutEntries)")
                for child in childrenWithoutEntries {
                    if fullScan?.shouldStop(watchedFolder) ?? false {
                        return false
                    }

                    NSLog("Adding missing entry for \(child) in \(folderNeedingUpdate) in \(watchedFolder)")
                    queries.addRequestV2Async(for: child, in: watchedFolder)
                }
                break // check this folder again later
            }
            
            var complete = true
            for status in statuses {
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
            
            if complete, let enoughCopies = enoughCopiesAllChildren, let leastCopiesValue = leastCopies, let present = presentAll {
                NSLog("Folder now has full information \(folderNeedingUpdate) in \(watchedFolder) \(enoughCopies) \(leastCopiesValue) \(present)")
                
                queries.updateStatusForPathV2Blocking(presentStatus: present, enoughCopies: enoughCopies, numberOfCopies: leastCopiesValue, isGitAnnexTracked: true, for: folderNeedingUpdate, key: nil, in: watchedFolder, isDir: true, needsUpdate: false)
                
                // Invalidate our parent, if we have one
                if let parent = PathUtils.parent(for: folderNeedingUpdate, in: watchedFolder) {
                    queries.invalidateDirectory(path: parent, in: watchedFolder)
                }
            }
        }
        
        return true // finished successfully
    }
    
    // https://gist.github.com/jweinst1/319e0cd35213e8eff0ab
    //counts a specific letter in a string
    static func count(_ char:Character, in str:String) -> Int {
        let letters = Array(str); var count = 0
        for letter in letters {
            if letter == char {
                count += 1
            }
        }
        return count
    }
}
