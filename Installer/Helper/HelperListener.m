//
//  file: HelperListener.m
//  project: (open-source) installer
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "consts.h"
#import "XPCProtocol.h"
#import "HelperListener.h"
#import "HelperInterface.h"

#import <bsm/libbsm.h>
#import <Security/AuthSession.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation HelperListener

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
    
    //requirement
    NSString* requirement = nil;
    
    //init listener
    listener = [[NSXPCListener alloc] initWithMachServiceName:CONFIG_HELPER_ID];
    if(!self.listener) {
        os_log_error(logHandle, "ERROR: failed to create mach service %{public}@", CONFIG_HELPER_ID);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "created mach service %{public}@", CONFIG_HELPER_ID);
    
    //init requirement
    // TODO: bump this to v2.0 on release!
    requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"1.9.0\"", INSTALLER_ID, SIGNING_AUTH];
    
    //set requirement
    [self.listener setConnectionCodeSigningRequirement:requirement];
    
    //dbg msg
    os_log_debug(logHandle, "set XPC requirement %{public}@", requirement);
    
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
    os_log_debug(logHandle, "received request to connect to XPC interface");
    
    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[HelperInterface alloc] init];
    
    //resume
    [newConnection resume];
    
    //dbg msg
    os_log_debug(logHandle, "allowed XPC connection: %{public}@", newConnection);
    
    return YES;
}

@end
