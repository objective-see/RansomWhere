//
//  Queue.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Queue.h"
#import "Consts.h"
#import "Logging.h"
#import "Process.h"
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
    
    //flag
    BOOL whiteListed = YES;
    
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
            
        //reset flag
        whiteListed = NO;
            
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
            
        //1ST
        // ->check if its whitelisted
        for(NSMutableDictionary* whitelistedEvent in ((AppDelegate*)[[NSApplication sharedApplication] delegate]).whiteList)
        {
            //check for match
            if(YES == [currentWatchEvent matchesWhiteListed:whitelistedEvent])
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, @"automatically allowing whitelisted event");
                #endif
                
                //set flag
                whiteListed = YES;
                
                //automatically allow it
                // ->plugins will be same
                [currentWatchEvent.plugin allow:currentWatchEvent];
                
                //bail from loop
                break;
            }
        }
            
        //handled?
        if(YES == whiteListed)
        {
            //loop to process next event
            continue;
        }
            
        //2ND:
        // ->check if new event is related to last one
        if(YES == [lastWatchEvent isRelated:currentWatchEvent])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"is a related event");
            #endif

            //set
            previousWatchEvent = lastWatchEvent;
        }
            
        //3RD:
        // ->check if new event matches a 'remembered' one
        if(nil == previousWatchEvent)
        {
            //iterated over all 'remembered' watch events
            // ->check if current watch event matches any
            for(WatchEvent* rememberedWatchEvent in ((AppDelegate*)[[NSApplication sharedApplication] delegate]).rememberedWatchEvents)
            {
                //check for match
                if(YES == [currentWatchEvent matchesRemembered:rememberedWatchEvent])
                {
                    //dbg msg
                    #ifdef DEBUG
                    logMsg(LOG_DEBUG, @"is a remembered event");
                    #endif
                    
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
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"event is related/remembered: %@ %@ (%@ -> %@)", currentWatchEvent.process.path, currentWatchEvent.plugin.alertMsg, currentWatchEvent.path, currentWatchEvent.itemObject]);
            #endif
            
            //prev. event one was blocked
            // ->block this one too
            if(YES == previousWatchEvent.wasBlocked)
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, @"automatically blocking related/remembered event");
                #endif
                
                //automatically block it
                // ->plugins will be same
                [lastWatchEvent.plugin block:currentWatchEvent];
            }
            //prev. event was allowed
            // ->allow this one too
            else
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, @"automatically allowing related/remembered event");
                #endif
                
                //automatically allow it
                // ->plugins will be same
                [lastWatchEvent.plugin allow:currentWatchEvent];
            }
            
        }//related/'remembered' event
    
        //it's new
        // ->and not whitelisted, related, nor remembered
        else
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"NEW WATCH EVENT (will broadcast): %@", currentWatchEvent]);
            #endif
        
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
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added watch event %@ to dictionary (%@)", currentWatchEvent.uuid,  ((AppDelegate*)[[NSApplication sharedApplication] delegate]).reportedWatchEvents]);
                #endif
                
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"pruning watch events...");
    #endif
    
    //get all keys
    keys = [reportedWatchEvents allKeys];
    
    //check all keys
    // ->remove old items
    for(NSString* key in keys)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"obj: %@", reportedWatchEvents[key]]);
        #endif
        
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
