import Foundation

// https://stackoverflow.com/a/41165920/8671834
public class TurtleServer: NSObject {
    init(name: String, toRunLoop runLoop: CFRunLoop) {
        super.init()
        let cfname = name as CFString
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
            TurtleLog.info("ping received msgid=\(msgid) msg=\(receivedMsg)")
            
            // prepare a response
            let responseData = try JSONEncoder().encode(PingResponseData(id: receivedMsg.id, timeStamp: Date().timeIntervalSince1970))
            return responseData
        } catch {
            TurtleLog.error("unable to parse ping message or create response \(error)")
        }
        
        return nil
    }
}
