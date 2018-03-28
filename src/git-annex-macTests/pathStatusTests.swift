//
//  pathStatusTests.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 3/28/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import XCTest

class pathStatusTests: XCTestCase {
    func testPathStatus_equals() {
        let repo = WatchedFolder(uuid: UUID(), pathString: "/tmp/notarealabsolutepath")
        
        // same instance
        let key = UUID().uuidString
        let mod = Date().timeIntervalSince1970
        let a = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertEqual(a, a)
        
        // == same content
        let b = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertEqual(a, b)
        XCTAssertEqual(b, a)

        // optional
        let c: PathStatus? = b
        XCTAssertEqual(a, c)
        XCTAssertEqual(c, a)
        
        // modification date is ignored
        let differentDate: Double = 4
        let e = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: differentDate, key: key, needsUpdate: false)
        XCTAssertEqual(a, e)
        XCTAssertEqual(e, a)
        
        // needs update is ignored
        let f = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: true)
        XCTAssertEqual(a, f)
        XCTAssertEqual(f, a)
        
        // 1 item is different in each
        var d = PathStatus(isDir: true, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        d = PathStatus(isDir: false, isGitAnnexTracked: false, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        d = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.absent, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        d = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.lacking, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        d = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 4, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        d = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath2.txt", watchedFolder: repo, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        let repo2 = WatchedFolder(uuid: UUID(), pathString: "/tmp/notarealabsolutepath2")
        d = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo2, modificationDate: mod, key: key, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
        let key2 = UUID().uuidString
        d = PathStatus(isDir: false, isGitAnnexTracked: true, presentStatus: Present.present, enoughCopies: EnoughCopies.enough, numberOfCopies: 3, path: "aPath.txt", watchedFolder: repo, modificationDate: mod, key: key2, needsUpdate: false)
        XCTAssertNotEqual(a, d)
        XCTAssertNotEqual(d, a)
    }
}

