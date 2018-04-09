//
//  messagePortServices.swift
//  git-annex-turtleTests
//
//  Created by Andrew Ringler on 4/8/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation
import XCTest

class messagePortServices: XCTestCase {
    var runMessagePortServices: RunMessagePortServices?
    var appTurtleMessagePortClient: AppTurtleMessagePort?
    var appTurtleMessagePortClient2: AppTurtleMessagePort?
    var gitAnnexTurtle: GitAnnexTurtleStub?
    
    override func setUp() {
        super.setUp()
        gitAnnexTurtle = GitAnnexTurtleStub()
        runMessagePortServices = RunMessagePortServices(gitAnnexTurtle: gitAnnexTurtle!)
        appTurtleMessagePortClient = AppTurtleMessagePort(id: "FinderSyncID 1")
        appTurtleMessagePortClient2 = AppTurtleMessagePort(id: "FinderSyncID 2")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testNotifiesGitAnnexTurtle() {
        wait(for: 2) // wait for ports to startup
        
        appTurtleMessagePortClient!.notifyBadgeRequestsPendingDebounce()
        wait(for: 2)
        XCTAssertEqual(gitAnnexTurtle?.badgeRequestsArePendingCalled, 1)
        
        appTurtleMessagePortClient!.notifyCommandRequestsPendingDebounce()
        wait(for: 2)
        XCTAssertEqual(gitAnnexTurtle?.commandRequestsArePendingCalled, 1)
        
        appTurtleMessagePortClient!.notifyVisibleFolderUpdatesPendingDebounce()
        wait(for: 2)
        XCTAssertEqual(gitAnnexTurtle?.visibleFolderUpdatesArePendingCalled, 1)
    }
}
class StoppableStub: StoppableService {}
