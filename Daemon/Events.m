//
//  file: Events.m
//  project: RansomWhere? (launch daemon)
//  description: send alert to user via XPC
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "Event.h"
#import "consts.h"
#import "Events.h"
#import "Monitor.h"
#import "utilities.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//monitor obj
extern Monitor* monitor;

//user client
XPCUserClient* xpcUserClient;

@implementation Events

//init
-(id)init {
    //super
    self = [super init];
    if(nil != self) {
        
        //init user xpc client
        xpcUserClient = [[XPCUserClient alloc] init];
    }
    
    return self;
}

//via XPC, send an alert
// response is handled by other callback
-(BOOL)deliver:(Event*)event {
    
    //dbg msg
    os_log_debug(logHandle, "delivering alert to user: %{public}@", event);
    
    //send via XPC to user
    if(![xpcUserClient deliverEvent:event]) {
        os_log_debug(logHandle, "failed to deliver alert to user (no client?)");
        return NO;
    }
    
    return YES;
}

@end
