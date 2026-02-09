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

//event queue
@property (nonatomic, strong) dispatch_queue_t eventQueue;

//plugin (objects)
@property (nonatomic, retain)NSMutableArray* plugins;

//last event
@property (nonatomic, retain)Event* lastEvent;

//observer for new client/user
@property(nonatomic, retain)id userObserver;

//interpreters
@property(nonatomic, retain)NSSet* interpreters;


/* METHODS */

-(BOOL)start;
-(void)handleResponse:(NSDictionary*)alert;
-(void)resetProcess:(NSString*)path action:(NSInteger)action;
-(void)dispatchFSEvent:(NSNumber*)processKey path:(NSString *)filePath;

//stop
-(BOOL)stop;

@end
