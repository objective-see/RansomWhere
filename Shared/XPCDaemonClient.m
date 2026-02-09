//
//  file: XPCDaemonClient.m
//  project: RansomWhere? (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "XPCUser.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//alert (windows)
extern NSMutableDictionary* alerts;

@implementation XPCDaemonClient

@synthesize daemon;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        daemon = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.daemon.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
        
        //set exported object interface (protocol)
        self.daemon.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
        
        //set exported object
        // this will allow daemon to invoke user methods!
        self.daemon.exportedObject = [[XPCUser alloc] init];
    
        //resume
        [self.daemon resume];
    }
    
    return self;
}

//get preferences
// note: synchronous, will block until daemon responds
-(NSDictionary*)getPreferences
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //request preferences
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
        
     }] getPreferences:^(NSDictionary* preferencesFromDaemon)
     {
         //dbg msg
         os_log_debug(logHandle, "got preferences: %{public}@", preferencesFromDaemon);
         
         //save
         preferences = preferencesFromDaemon;
         
     }];
    
    return preferences;
}

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //update prefs
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
          
    }] updatePreferences:preferences];
    
    return;
}

//get rules
// note: synchronous, will block until daemon responds
-(NSDictionary*)getRules
{
    __block NSDictionary* rules = nil;
    
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
        
    }] getRules:^(NSDictionary* rulesFromDaemon)
    {
        rules = rulesFromDaemon;
    }];
    
    return rules;
}

//add rule
-(void)addRule:(NSString *)path action:(NSNumber*)action {
    
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //delete rule
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
        
    }] addRule:path action:action];
}

//delete rule
-(void)deleteRule:(NSString*)path {
    
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //delete rule
    [[self.daemon synchronousRemoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
        
    }] deleteRule:path];
}

//send alert response back to the deamon
-(void)alertReply:(NSDictionary*)alert
{
    //pool
    @autoreleasepool {
        
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //respond to alert
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
        
    }] alertReply:alert];
    
    //sync to remove alert (window)
    @synchronized(alerts)
    {
        //remove
        alerts[alert[ALERT_UUID]] = nil;
    }
    
    //set app's background/foreground state
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
        
    } //pool

    return;
}

//quit
-(void)quit
{
    //dbg msg
    os_log_debug(logHandle, "invoking daemon XPC method, '%s'", __PRETTY_FUNCTION__);
    
    //update prefs
    [[self.daemon remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to execute daemon XPC method '%s' (error: %{public}@)", __PRETTY_FUNCTION__, proxyError);
          
    }] quit];
    
    return;
}

@end
