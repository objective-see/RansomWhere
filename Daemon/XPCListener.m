//
//  file: XPCListener.m
//  project: RansomWhere? (launch daemon)
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"

#import "Rules.h"
#import "utilities.h"
#import "XPCDaemon.h"
#import "XPCListener.h"
#import "XPCUserProto.h"
#import "XPCDaemonProto.h"

#import <bsm/libbsm.h>

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

/* GLOBALS */

//log handle
extern os_log_t logHandle;


OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);

//global rules obj
extern Rules* rules;

@implementation XPCListener

@synthesize client;
@synthesize listener;

//init
// create XPC listener
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //setup XPC listener
        if(YES != [self initListener])
        {
            //unset
            self =  nil;
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return self;
}

//setup XPC listener
-(BOOL)initListener
{
    //result
    BOOL result = NO;
    
    //code signing requirement
    NSString* requirement = nil;
    
    //init listener
    listener = [[NSXPCListener alloc] initWithMachServiceName:DAEMON_MACH_SERVICE];
    if(!self.listener) {
        
        os_log_error(logHandle, "ERROR: failed to create mach service %{public}@", DAEMON_MACH_SERVICE);
        goto bail;
    }
    
    //init requirement
    // RansomWhere? helper, v2.0+
    // TODO: bump to v2.0.0 on release!
    requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"1.9.0\"", HELPER_ID, SIGNING_AUTH];
        
    //set requirement
    [self.listener setConnectionCodeSigningRequirement:requirement];
    
    //dbg msg
    os_log_debug(logHandle, "set XPC requirement %{public}@", requirement);

    //dbg msg
    os_log_debug(logHandle, "created mach service %{public}@", DAEMON_MACH_SERVICE);
    
    //set delegate
    self.listener.delegate = self;
    
    //ready to accept connections
    [self.listener resume];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}


#pragma mark -
#pragma mark NSXPCConnection method overrides

//automatically invoked
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    #pragma unused(listener)
    
    //dbg msg
    os_log_debug(logHandle, "'%s' invoked", __PRETTY_FUNCTION__);
    
    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[XPCDaemon alloc] init];
    
    //set type of remote object
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
    
    //save
    self.client = newConnection;
    
    //notify that a new client connected
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:USER_NOTIFICATION object:nil userInfo:nil];
    });
    
    //resume
    [newConnection resume];
    
    //dbg msg
    os_log_debug(logHandle, "allowing XPC connection (pid: %d)", newConnection.processIdentifier);
    
    return YES;
}
@end
