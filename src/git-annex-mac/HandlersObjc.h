#import <Foundation/Foundation.h>

@class TurtleServer;
extern CFMessagePortCallBack pingHandler(void);
extern void *bridgedPtr(TurtleServer *server);
