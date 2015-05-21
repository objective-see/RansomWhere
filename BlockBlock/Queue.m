//
//  Queue.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "Queue.h"
#import "Consts.h"
#import "Logging.h"
#import "PluginBase.h"
#import "WatchEvent.h"
#import "AppDelegate.h"

@implementation Queue

@synthesize eventQueue;
@synthesize queueCondition;
@synthesize qProcessorThread;

-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init queue
        eventQueue = [NSMutableArray array];
        
        //init empty condition
        queueCondition = [[NSCondition alloc] init];
        
        //spin up thread to watch/process queue
        self.qProcessorThread = [[NSThread alloc] initWithTarget:self selector:@selector(processQueue:) object:nil];
        
        //start it
        [self.qProcessorThread start];

    }
    
    return self;
}

//process events from Q
-(void)processQueue:(id)threadParam
{
    //most recent watch event
    WatchEvent* lastWatchEvent = nil;
    
    //previous watch event
    // ->will either be 'lastWatchEvent' or 'rememberedWatchEvent'
    WatchEvent* previousWatchEvent = nil;
    
    //current watch item
    WatchEvent* currentWatchEvent = nil;
    
    //information about alert
    // ->passed via notification to UI (launch agent) instance
    NSMutableDictionary* alertInfo = nil;
    
    //reported watch events from app delegate
    // ->this var is just for convience/shorthand
    NSMutableDictionary* reportedWatchEvents = nil;
    
    //init
    // ->grab global
    reportedWatchEvents = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).reportedWatchEvents;
    
    //for ever
    while(YES)
    {
        //pool
        @autoreleasepool {
            
        //always reset this var
        previousWatchEvent = nil;
            
        //lock
        [self.queueCondition lock];
        
        //wait while queue is empty
        while(YES == [self.eventQueue empty])
        {
            //wait
            [self.queueCondition wait];
        }
        
        //get item off queue
        currentWatchEvent = [eventQueue dequeue];
        
        //unlock
        [self.queueCondition unlock];
            
        //check if new event is related to last one
        if(YES == [lastWatchEvent isRelated:currentWatchEvent])
        {
            //set
            previousWatchEvent = lastWatchEvent;
        }
        //also check if new event matches a 'remembered' one
        else
        {
            //iterated over all 'remembered' watch events
            // ->check if current watch event matches any
            for(WatchEvent* rememberedWatchEvent in ((AppDelegate*)[[NSApplication sharedApplication] delegate]).rememberedWatchEvents)
            {
                //check for match
                if(YES == [currentWatchEvent matchesRemembered:rememberedWatchEvent])
                {
                    //got match
                    // ->save
                    previousWatchEvent = rememberedWatchEvent;
                    
                    //bail from loop
                    break;
                }
            }
        }
            
        //for related/'remembered' events
        // ->handle appropriately by either automatically allowing or blocking
        if(nil != previousWatchEvent)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"watch event is RELATED || 'REMEMBERED'");
            
            //prev. event one was blocked
            // ->block this one too
            if(YES == previousWatchEvent.wasBlocked)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"automatically blocking related/remembered event");
            
                //automatically block it
                // ->plugins will be same
                [lastWatchEvent.plugin block:currentWatchEvent];
            }
            //prev. event was allowed
            // ->allow this one too (i.e., don't do anything)
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"automatically allowing related/remembered event");
            }
            
        }//related/'remembered' event
    
        //its new/unrelated
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"NEW WATCH EVENT (will broadcast): %@", currentWatchEvent]);
        
            //make an alert dictionary
            // ->contains everything needed to display the alert to the user
            alertInfo = [currentWatchEvent createAlertDictionary];
            
            //broadcast notification to (UI) agents via IPC
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendAlertToAgent:currentWatchEvent userInfo:alertInfo];
            
            //any access events needs to be locked
            @synchronized(reportedWatchEvents)
            {
                //save watch event (keyed by its UUID) into global dictionary
                // ->will allow daemon to validate block requests from ui (agent) instance
                reportedWatchEvents[[currentWatchEvent.uuid UUIDString]] = currentWatchEvent;
                
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added watch event %@ to dictionary (%@)", currentWatchEvent.uuid,  ((AppDelegate*)[[NSApplication sharedApplication] delegate]).reportedWatchEvents]);
                
                //check on number of stored watch events
                // ->prune (remove old ones) if needed
                if(MAX_WATCH_EVENTS <= reportedWatchEvents.count)
                {
                    //prune!
                    [self pruneWatchEvents:reportedWatchEvents];
                }
            }
            //since current watch event was handled
            // ->save to check if event is related
            lastWatchEvent = currentWatchEvent;
        }
            
        //pool
        }
        
    }//foreverz process queue
        
    return;
}


//add an object to the queue
-(void)enqueue:(id)anObject
{
    //lock
    [self.queueCondition lock];
    
    //add to queue
    [self.eventQueue enqueue:anObject];
    
    //signal
    [self.queueCondition signal];
    
    //unlock
    [self.queueCondition unlock];
    
    return;
}

//for any old reported watch events
// ->remove em, to keep numbers in check!
-(void)pruneWatchEvents:(NSMutableDictionary*)reportedWatchEvents
{
    //keys in watch event dictionary
    NSArray* keys = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"pruning watch events...");
    
    //get all keys
    keys = [reportedWatchEvents allKeys];
    
    //check all keys
    // ->remove old items
    for(NSString* key in keys)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"obj: %@", reportedWatchEvents[key]]);
        
        //check for old events
        // ->anything over 1 hr
        if(60*60 <= [[NSDate date] timeIntervalSinceDate:((WatchEvent*)reportedWatchEvents[key]).timestamp])
        {
            //old, so remove
            [reportedWatchEvents removeObjectForKey:key];
        }
    }
    
    return;
}

@end
