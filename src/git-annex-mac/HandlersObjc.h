#import <Foundation/Foundation.h>

@class TurtleServerPing;
extern CFMessagePortCallBack pingHandler(void);
extern void *bridgedPtr(TurtleServerPing *server);
