#import <Foundation/Foundation.h>

@class TurtleServerPing;
extern CFMessagePortCallBack pingHandler(void);
extern void *bridgedPtr(TurtleServerPing *server);

@class TurtleServerCommandRequests;
extern CFMessagePortCallBack commandRequestHandler(void);
extern void *bridgedPtrCommandRequests(TurtleServerCommandRequests *server);

@class TurtleServerBadgeRequests;
extern CFMessagePortCallBack badgeRequestHandler(void);
extern void *bridgedPtrBadgeRequests(TurtleServerBadgeRequests *server);
