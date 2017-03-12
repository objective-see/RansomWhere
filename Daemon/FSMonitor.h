//
//  FSMonitor.h
//  RansomWhere
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) Objective-See. All rights reserved.
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

//determine if a path should be ignored
-(BOOL)shouldIgnore:(NSString*)path;

/* PROPERTIES */

//use process monitor (on newer versions of macOS)
@property BOOL waitForProcessMonitor;

//file-system event queue
@property (nonatomic, retain)Queue* eventQueue;

@end
