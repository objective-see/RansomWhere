//
//  Monitor.h
//  RansomWhere?
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

#import "Event.h"
#import "Process.h"

#import <bsm/libbsm.h>
#import <EndpointSecurity/EndpointSecurity.h>

@import OSLog;

@interface Monitor : NSObject <NSCacheDelegate>
{

}

/* PROPERTIES */

//endpoint (process) client
@property es_client_t* endpointProcessClient;

//process cache
@property (nonatomic, retain)NSCache* processCache;

//paths of (observed) interpreters
// never muted, as a mute is by path & permanent, so muting an interpreter
// would blind us to every script it subsequently runs
@property (nonatomic, retain)NSMutableSet* interpreterPaths;

//event queue
@property (nonatomic, strong) dispatch_queue_t eventQueue;

//plugin (objects)
@property (nonatomic, retain)NSMutableArray* plugins;

//last event
@property (nonatomic, retain)Event* lastEvent;

//observer for new client/user
@property(nonatomic, retain)id userObserver;

/* METHODS */

-(BOOL)stop;
-(BOOL)start;
-(void)resetProcess:(NSString*)path;
-(void)handleResponse:(NSDictionary*)alert;
-(void)dispatchFSEvent:(NSNumber*)processKey processPath:(NSString *)processPath filePath:(NSString*)filePath;

@end
