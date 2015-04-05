//
//  Watcher.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import <Foundation/Foundation.h>


#import "Queue.h"
#import "fsEvents.h"


@class WatchEvent;

@interface Watcher : NSObject
{
    //iVARS
    
    //file <-> plugin mappings
    NSMutableDictionary* pluginMappings;
    
    //watch files
    NSArray* watchItems;
    
    //reference to stream
    FSEventStreamRef streamRef;
    
    //watcher thread
    NSThread* watcherThread;
    
    //plugins
    NSMutableArray* plugins;
    
}

//METHODS

//load watch list and enable watches
-(BOOL)watch;

//create a watch event
// ->most of the logic is creating/finding the process object
-(WatchEvent*)createWatchEvent:(NSString*)path fsEvent:(kfs_event_a *)fsEvent;

//update the path to watch
// ->basiscally expands all '~'s into registered agent(s)
-(void)updateWatchedPaths:(NSMutableDictionary*)registeredAgents;

@property (nonatomic, retain)NSMutableDictionary* pluginMappings;
@property (nonatomic, retain)NSArray* watchItems;
@property (nonatomic, retain)NSThread* watcherThread;
@property (nonatomic, retain)NSMutableDictionary* runningApps;
@property (nonatomic, retain)NSMutableArray* plugins;


@end
