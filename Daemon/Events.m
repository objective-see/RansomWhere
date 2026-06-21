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
// idempotent: marks process.alertShown on success so concurrent callers
// don't double-deliver
-(BOOL)deliver:(Event*)event {

    @synchronized(self) {

        //already delivered? no-op
        if(event.process.alertShown) {
            os_log_debug(logHandle, "alert already shown for %{public}@, skipping", event.process.name);
            return YES;
        }

        //dbg msg
        os_log_debug(logHandle, "delivering alert to user: %{public}@", event);

        //send via XPC to user
        if(![xpcUserClient deliverEvent:event]) {
            os_log_debug(logHandle, "failed to deliver alert to user (no client?)");
            return NO;
        }

        //flag tied to actual XPC send
        event.process.alertShown = YES;
    }

    return YES;
}

@end
