import Foundation

// https://stackoverflow.com/a/41165920/8671834
// http://nshipster.com/inter-process-communication/
public class TurtleServerPing: NSObject {
    init(toRunLoop runLoop: CFRunLoop) {
        super.init()
        let cfname = messagePortNamePing as CFString
        var context = CFMessagePortContext(version: 0, info: bridgedPtr(self), retain: nil, release: nil, copyDescription: nil)
        var shouldFreeInfo: DarwinBoolean = false
        let port: CFMessagePort = CFMessagePortCreateLocal(nil, cfname, pingHandler(), &context, &shouldFreeInfo)
        let source = CFMessagePortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(runLoop, source, CFRunLoopMode.commonModes)
    }

    @objc func handlePing(_ msgid: Int32, data: Data) -> Data? {
        do {
            // parse received message
            let receivedMsg = try JSONDecoder().decode(SendPingData.self, from: data)
            TurtleLog.trace("ping received msgid=\(msgid) msg=\(receivedMsg)")
            
            // prepare a response
            let responseData = try JSONEncoder().encode(PingResponseData(id: receivedMsg.id, timeStamp: Date().timeIntervalSince1970))
            return responseData
        } catch {
            TurtleLog.error("unable to parse ping message or create response \(error)")
        }
        
        return nil
    }
}

public class TurtleServerCommandRequests: NSObject {
    let gitAnnexTurtle: GitAnnexTurtle
    
    init(toRunLoop runLoop: CFRunLoop, gitAnnexTurtle: GitAnnexTurtle) {
        self.gitAnnexTurtle = gitAnnexTurtle
        super.init()
        let cfname = messagePortNameCommandRequests as CFString
        var context = CFMessagePortContext(version: 0, info: bridgedPtrCommandRequests(self), retain: nil, release: nil, copyDescription: nil)
        var shouldFreeInfo: DarwinBoolean = false
        let port: CFMessagePort = CFMessagePortCreateLocal(nil, cfname, commandRequestHandler(), &context, &shouldFreeInfo)
        let source = CFMessagePortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(runLoop, source, CFRunLoopMode.commonModes)
    }
    
    @objc func handleCommandRequests(_ msgid: Int32, data: Data) -> Data? {
        do {
            // parse received message
            let receivedMsg = try JSONDecoder().decode(SendPingData.self, from: data)
            TurtleLog.trace("handle command requests received msgid=\(msgid) msg=\(receivedMsg)")
            
            // prepare a response
            let responseData = try JSONEncoder().encode(PingResponseData(id: receivedMsg.id, timeStamp: Date().timeIntervalSince1970))
            gitAnnexTurtle.commandRequestsArePending()
            return responseData
        } catch {
            TurtleLog.error("unable to parse handle command requests message or create response \(error)")
        }
        
        return nil
    }
}

public class TurtleServerBadgeRequests: NSObject {
    let gitAnnexTurtle: GitAnnexTurtle

    init(toRunLoop runLoop: CFRunLoop, gitAnnexTurtle: GitAnnexTurtle) {
        self.gitAnnexTurtle = gitAnnexTurtle
        super.init()
        let cfname = messagePortNameBadgeRequests as CFString
        var context = CFMessagePortContext(version: 0, info: bridgedPtrBadgeRequests(self), retain: nil, release: nil, copyDescription: nil)
        var shouldFreeInfo: DarwinBoolean = false
        let port: CFMessagePort = CFMessagePortCreateLocal(nil, cfname, badgeRequestHandler(), &context, &shouldFreeInfo)
        let source = CFMessagePortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(runLoop, source, CFRunLoopMode.commonModes)
    }
    
    @objc func handleBadgeRequests(_ msgid: Int32, data: Data) -> Data? {
        do {
            // parse received message
            let receivedMsg = try JSONDecoder().decode(SendPingData.self, from: data)
            TurtleLog.trace("handle badge requests received msgid=\(msgid) msg=\(receivedMsg)")
            
            // prepare a response
            let responseData = try JSONEncoder().encode(PingResponseData(id: receivedMsg.id, timeStamp: Date().timeIntervalSince1970))
            gitAnnexTurtle.badgeRequestsArePending()
            return responseData
        } catch {
            TurtleLog.error("unable to parse handle badge requests message or create response \(error)")
        }
        
        return nil
    }
}
