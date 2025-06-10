//
//  AppTurtleMessagePort.swift
//  git-annex-finder
//
//  Created by Andrew Ringler on 4/8/18.
//  Copyright © 2018 Andrew Ringler. All rights reserved.
//

import Foundation

// // see parsing return data example http://ddeville.me/2015/02/interprocess-communication-on-ios-with-mach-messages
class AppTurtleMessagePortPingKeepAlive {
    let id: String
    var stoppable: StoppableService? = nil
    var running: Bool = true
    
    init(id: String, doInit: @escaping () -> Void) {
        self.id = id
        
        // Ping keep-alive
        DispatchQueue.global(qos: .background).async {
            while self.running {
                if let serverPort = CFMessagePortCreateRemote(nil, messagePortNamePing as CFString) {
                    do {
                        let sendPingData = SendPingData(id: id, timeStamp: Date().timeIntervalSince1970)
                        let data: CFData = try JSONEncoder().encode(sendPingData) as CFData
                        let status = CFMessagePortSendRequest(serverPort, 1, data, 1.0, 1.0, nil, nil);
                        if status == Int32(kCFMessagePortSuccess) {
                            TurtleLog.trace("success sending \(sendPingData) to App Turtle Service")
                            doInit()
                        } else {
                            TurtleLog.error("could not communicate with App Turtle service error=\(status)")
                            self.doQuit()
                        }
                    } catch {
                        TurtleLog.error("unable to serialize payload for SendPingData")
                        self.doQuit()
                    }
                } else {
                    TurtleLog.error("unable to open ping port \(messagePortNamePing) connecting with App Turtle Service")
                    self.doQuit()
                }
                
                sleep(2)
            }
        }
    }
    
    private func doQuit() {
        TurtleLog.info("unable to connect with Turtle App service, quiting…")
        self.running = false
        stoppable?.stop()
        exit(0)
    }
}

class AppTurtleMessagePort {
    private let id: String
    public lazy var notifyCommandRequestsPendingDebounce: () -> Void = {
        return debounce(delay: .milliseconds(50), queue: DispatchQueue.global(qos: .background), action: self.notifyCommandRequestsPending)
    }()
    public lazy var notifyBadgeRequestsPendingDebounce: () -> Void = {
        return debounce(delay: .milliseconds(50), queue: DispatchQueue.global(qos: .background), action: self.notifyBadgeRequestsPending)
    }()
    public lazy var notifyVisibleFolderUpdatesPendingDebounce: () -> Void = {
        return debounce(delay: .milliseconds(50), queue: DispatchQueue.global(qos: .background), action: self.notifyVisibleFolderUpdatesPending)
    }()

    init(id: String) {
        self.id = id
    }
    
    private func notifyCommandRequestsPending() {
        if let serverPort = CFMessagePortCreateRemote(nil, messagePortNameCommandRequests as CFString) {
            do {
                let sendPingData = SendPingData(id: id, timeStamp: Date().timeIntervalSince1970)
                let data: CFData = try JSONEncoder().encode(sendPingData) as CFData
                let status = CFMessagePortSendRequest(serverPort, 1, data, 1.0, 1.0, nil, nil);
                if status == Int32(kCFMessagePortSuccess) {
                    TurtleLog.trace("success sending \(sendPingData) to App Turtle Service command request port")
                } else {
                    TurtleLog.error("could not communicate with App Turtle service on command request port error=\(status)")
                }
            } catch {
                TurtleLog.error("unable to serialize payload for SendPingData on command request port")
            }
        } else {
            TurtleLog.error("unable to open command request port \(messagePortNameCommandRequests) connecting with App Turtle Service")
        }
    }
    
    private func notifyBadgeRequestsPending() {
        if let serverPort = CFMessagePortCreateRemote(nil, messagePortNameBadgeRequests as CFString) {
            do {
                let sendPingData = SendPingData(id: id, timeStamp: Date().timeIntervalSince1970)
                let data: CFData = try JSONEncoder().encode(sendPingData) as CFData
                let status = CFMessagePortSendRequest(serverPort, 1, data, 1.0, 1.0, nil, nil);
                if status == Int32(kCFMessagePortSuccess) {
                    TurtleLog.trace("success sending \(sendPingData) to App Turtle Service badge request port")
                } else {
                    TurtleLog.error("could not communicate with App Turtle service on badge request port error=\(status)")
                }
            } catch {
                TurtleLog.error("unable to serialize payload for SendPingData on badge request port")
            }
        } else {
            TurtleLog.error("unable to open badge request port \(messagePortNameBadgeRequests) connecting with App Turtle Service")
        }
    }
    
    private func notifyVisibleFolderUpdatesPending() {
        if let serverPort = CFMessagePortCreateRemote(nil, messagePortNameVisibleFolderUpdates as CFString) {
            do {
                let sendPingData = SendPingData(id: id, timeStamp: Date().timeIntervalSince1970)
                let data: CFData = try JSONEncoder().encode(sendPingData) as CFData
                let status = CFMessagePortSendRequest(serverPort, 1, data, 1.0, 1.0, nil, nil);
                if status == Int32(kCFMessagePortSuccess) {
                    TurtleLog.trace("success sending \(sendPingData) to App Turtle Service visible folder updates port")
                } else {
                    TurtleLog.error("could not communicate with App Turtle service on visible folder updates port error=\(status)")
                }
            } catch {
                TurtleLog.error("unable to serialize payload for SendPingData on visible folder updates port")
            }
        } else {
            TurtleLog.error("unable to open visible folder updates port \(messagePortNameVisibleFolderUpdates) connecting with App Turtle Service")
        }
    }
}
