#import "HandlersObjc.h"
#import "git_annex_turtle-Swift.h" // auto-generated during build

static CFDataRef handlePingCFData(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    TurtleServerPing *server = (__bridge TurtleServerPing *)info;
    NSData *responseData = [server handlePing:msgid data:(__bridge NSData *)(data)];
    if (responseData != NULL) {
        CFDataRef cfdata = CFDataCreate(nil, responseData.bytes, responseData.length);
        return cfdata;
    }
    else {
        return NULL;
    }
}

CFMessagePortCallBack pingHandler() {
    return handlePingCFData;
}

void *bridgedPtr(TurtleServerPing *server) {
    return (__bridge void *)server;
}
