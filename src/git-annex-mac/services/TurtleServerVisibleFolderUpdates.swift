//
//  TurtleVisibleFolderUpdates.swift
//  git-annex-turtle
//
//  Created by Andrew Ringler on 4/9/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

public class TurtleServerVisibleFolderUpdates: NSObject {
    let gitAnnexTurtle: GitAnnexTurtle
    var port: CFMessagePort?
    
    init(toRunLoop runLoop: CFRunLoop, gitAnnexTurtle: GitAnnexTurtle) {
        self.gitAnnexTurtle = gitAnnexTurtle
        super.init()
        let cfname = messagePortNameVisibleFolderUpdates as CFString
        var context = CFMessagePortContext(version: 0, info: bridgedPtrVU(self), retain: nil, release: nil, copyDescription: nil)
        var shouldFreeInfo: DarwinBoolean = false
        port = CFMessagePortCreateLocal(nil, cfname, visibleFolderUpdatesHandler(), &context, &shouldFreeInfo)
        let source = CFMessagePortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(runLoop, source, CFRunLoopMode.commonModes)
    }
    
    @objc func handleVisibleFolderUpdates(_ msgid: Int32, data: Data) -> Data? {
        do {
            // parse received message
            let receivedMsg = try JSONDecoder().decode(SendPingData.self, from: data)
            TurtleLog.trace("handle visible folder updates received msgid=\(msgid) msg=\(receivedMsg)")
            
            // prepare a response
            let responseData = try JSONEncoder().encode(PingResponseData(id: receivedMsg.id, timeStamp: Date().timeIntervalSince1970))
            gitAnnexTurtle.visibleFolderUpdatesArePending()
            return responseData
        } catch {
            TurtleLog.error("unable to parse handle visible folder updates message or create response \(error)")
        }
        
        return nil
    }
    
    public func invalidate() {
        if let portCreated = port {
            CFMessagePortInvalidate(portCreated)
        }
    }
}
