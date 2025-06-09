//
//  Bookmarks.swift
//  git-annex-turtle-data
//
//  Created by Andrew Ringler on 6/9/2025.
//  Copyright © 2025 Andrew Ringler. All rights reserved.
//
//  Adapated from: https://gist.github.com/chrispaynter/12b4cb7bb32c73033f07c0612810ce8e Chris Paynter
//

//import Foundation
import Cocoa
import CoreData
import SwiftUI

class Bookmarks {
    private static func urlForBookmarkData(bookmarkData: Data) -> URL? {
        do {
            var isStale = false;
            let bookmarkURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale);
            if(!isStale && bookmarkURL != nil) {
                return bookmarkURL!
            }
        } catch {
            TurtleLog.error("could not create security scoped URL from bookmark \(error)")
        }
        
        return nil
    }

    public static func getSecurityScopedURLFor(url: URL) -> URL? {
        let isRunningTests = NSClassFromString("XCTestCase") != nil
        if isRunningTests {
            return url // our testing framework will already have permissions for all URLs that it uses
        }

        let bookmarkKey = url.absoluteString
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            return urlForBookmarkData(bookmarkData: bookmarkData)
        }
        
        return nil
    }
    
//    public static func getSecurityScopedURLFor_BLOCKING(url: URL) -> URL? {
//        let bookmarkKey = url.absoluteString
//        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
//            return urlForBookmarkData(bookmarkData: bookmarkData)
//        }
//        
//        return self.askUserForDirectoryPermissions_BLOCKING(url: url)
//    }

    public static func cacheSecurityScopedBookmark(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            let bookmarkKey = url.absoluteString
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            TurtleLog.error("unable to create and cache security scoped bookmark for: \(url.absoluteString) \(error)")
        }
    }
    
//    public static func askUserForDirectoryPermissions_BLOCKING(url: URL) -> URL? {
//        let bookmarkKey = url.absoluteString
//        let semaphore = DispatchSemaphore(value: 0)
//        var url: URL? = nil
//        
//        TurtleLog.debug("requesting security scoped URL for: \(bookmarkKey)")
//        
//        DispatchQueue.main.async {
//            let panel = NSOpenPanel();
//            panel.canChooseDirectories = true
//            panel.canChooseFiles = false
//            panel.canCreateDirectories = false
//            panel.allowsMultipleSelection = false
//            panel.begin(completionHandler: { result in
//                defer {
//                    semaphore.signal()
//                }
//                if(result == .OK) {
//                    do {
//                        let bookmarkData = try panel.url!.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
//                        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
//                        url = self.urlForBookmarkData(bookmarkData: bookmarkData)
//                    } catch {
//                        TurtleLog.error("could not save bookmark to UserDefaults \(error)")
//                    }
//                } else {
//                    TurtleLog.info("user did not select directory for bookmarking")
//                }
//            })
//        }
//        
//        semaphore.wait()
//        return url
//    }
}
