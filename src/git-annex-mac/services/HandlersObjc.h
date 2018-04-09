#import <Foundation/Foundation.h>

@class TurtleServerPing;
@class TurtleServerCommandRequests;
@class TurtleServerBadgeRequests;
@class TurtleServerVisibleFolderUpdates;

extern CFMessagePortCallBack pingHandler(void);
extern CFMessagePortCallBack commandRequestHandler(void);
extern CFMessagePortCallBack badgeRequestHandler(void);
extern CFMessagePortCallBack visibleFolderUpdatesHandler(void);

extern void *bridgedPtrVU(TurtleServerVisibleFolderUpdates *server);
extern void *bridgedPtr(TurtleServerPing *server);
extern void *bridgedPtrCommandRequests(TurtleServerCommandRequests *server);
extern void *bridgedPtrBadgeRequests(TurtleServerBadgeRequests *server);

