//
//  AppTurtleMessagePort.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 4/8/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

class AppTurtleMessagePort {
    let stoppable: StoppableService
    let id: String
    
    init(id: String, stoppable: StoppableService) {
        self.id = id
        self.stoppable = stoppable
        
        // Ping keep-alive
        DispatchQueue.global(qos: .background).async {
            while stoppable.running.isRunning() {
                if let serverPort = CFMessagePortCreateRemote(nil, messagePortNamePing as CFString) {
                    do {
                        let sendPingData = SendPingData(id: id, timeStamp: Date().timeIntervalSince1970)
                        let data: CFData = try JSONEncoder().encode(sendPingData) as CFData
                        let status = CFMessagePortSendRequest(serverPort, 1, data, 1.0, 1.0, nil, nil);
                        if status == Int32(kCFMessagePortSuccess) {
                            TurtleLog.trace("success sending \(sendPingData) to App Turtle Service")
                        } else {
                            TurtleLog.error("could not communicate with App Turtle service error=\(status)")
                            self.doQuit()
                        }
                    } catch {
                        TurtleLog.error("unable to serialize payload for SendPingData")
                        self.doQuit()
                    }
                } else {
                    TurtleLog.error("unable to open port connecting with App Turtle Service")
                    self.doQuit()
                }
                
                sleep(2)
            }
        }
    }
    
    private func doQuit() {
        TurtleLog.info("unable to connect with Turtle App service, quiting…")
        stoppable.stop()
        exit(0)
    }
}
