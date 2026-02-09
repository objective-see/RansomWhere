//
//  file: XPCUserClient.m
//  project: RansomWhere? (launch daemon)
//  description: talk to the user, via XPC
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import OSLog;

#import "Rules.h"
#import "Event.h"
#import "Events.h"
#import "consts.h"
#import "XPCListener.h"
#import "XPCUserClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc connection
extern XPCListener* xpcListener;

@implementation XPCUserClient

//deliver alert to user
// note: this is synchronous so that errors can be detected
-(BOOL)deliverEvent:(Event*)event
{
    //flag
    __block BOOL xpcError = NO;
    
    //dbg msg
    os_log_debug(logHandle, "invoking user XPC method: 'alertShow'");
    
    //sanity check
    // no client connection?
    if(!xpcListener.client)
    {
        //dbg msg
        os_log_debug(logHandle, "no client is connected, alert will not be delivered");
        
        //set error
        xpcError = YES;
        
        //bail
        goto bail;
    }

    //send to user (client) to display
    [[xpcListener.client synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //set error
        xpcError = YES;
        
        //err msg
        os_log_error(logHandle, "ERROR: failed to invoke USER XPC method: 'alertShow' (error: %{public}@)", proxyError);

    }] alertShow:[event toAlert]];
    
bail:

    return !xpcError;
}


@end
