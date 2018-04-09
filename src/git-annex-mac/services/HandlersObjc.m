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


static CFDataRef handleCommandRequestCFData(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    TurtleServerCommandRequests *server = (__bridge TurtleServerCommandRequests *)info;
    NSData *responseData = [server handleCommandRequests:msgid data:(__bridge NSData *)(data)];
    if (responseData != NULL) {
        CFDataRef cfdata = CFDataCreate(nil, responseData.bytes, responseData.length);
        return cfdata;
    }
    else {
        return NULL;
    }
}
CFMessagePortCallBack commandRequestHandler() {
    return handleCommandRequestCFData;
}
void *bridgedPtrCommandRequests(TurtleServerCommandRequests *server) {
    return (__bridge void *)server;
}

static CFDataRef handleBadgeRequestCFData(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    TurtleServerBadgeRequests *server = (__bridge TurtleServerBadgeRequests *)info;
    NSData *responseData = [server handleBadgeRequests:msgid data:(__bridge NSData *)(data)];
    if (responseData != NULL) {
        CFDataRef cfdata = CFDataCreate(nil, responseData.bytes, responseData.length);
        return cfdata;
    }
    else {
        return NULL;
    }
}
CFMessagePortCallBack badgeRequestHandler() {
    return handleBadgeRequestCFData;
}
void *bridgedPtrBadgeRequests(TurtleServerBadgeRequests *server) {
    return (__bridge void *)server;
}

static CFDataRef handleVisibleFolderUpdatesCFData(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    TurtleServerVisibleFolderUpdates *server = (__bridge TurtleServerVisibleFolderUpdates *)info;
    NSData *responseData = [server handleVisibleFolderUpdates:msgid data:(__bridge NSData *)(data)];
    if (responseData != NULL) {
        CFDataRef cfdata = CFDataCreate(nil, responseData.bytes, responseData.length);
        return cfdata;
    }
    else {
        return NULL;
    }
}
CFMessagePortCallBack visibleFolderUpdatesHandler() {
    return handleVisibleFolderUpdatesCFData;
}
void *bridgedPtrVU(TurtleServerVisibleFolderUpdates *server) {
    return (__bridge void *)server;
}
