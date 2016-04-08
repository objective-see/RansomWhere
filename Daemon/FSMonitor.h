//
//  Watcher.h
//  RansomWhere
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright © Objective-See. All rights reserved.
//

#import "Queue.h"
#import "fsEvents.h"

#import <Foundation/Foundation.h>

@class WatchEvent;

@interface FSMonitor : NSObject
{
    //iVARS
    
    //reference to stream
    FSEventStreamRef streamRef;
}

/* METHODS */

//monitor file-system events
-(void)monitor;

//determine if a path is, or is under a watched path
-(BOOL)isWatched:(NSString*)path;


/* PROPERTIES */

//watched directories
@property (nonatomic, retain)NSMutableSet* watchDirectories;

//regex for 'window_<digits>.data' files
//@property (nonatomic, retain)NSRegularExpression* windowRegex;

//file-system event queue
@property (nonatomic, retain)Queue* eventQueue;

//pid -> path mappings
// ->timestamp ensures its still timely, cuz at this point can't detect when procs exit, so this is kinda of a hack...
@property (nonatomic, retain)NSMutableDictionary* pidPathMappings;

@end
