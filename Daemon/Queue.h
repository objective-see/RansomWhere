//
//  Queue.h
//  RansomWhere
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

@class Event;

#import <Foundation/Foundation.h>
#import "NSMutableArray+QueueAdditions.h"

@interface Queue : NSObject
{
    
}

/* PROPERTIES */

//path to icon
// ->shown in alert to user
@property(nonatomic, retain)NSURL* icon;

//event queue
@property(retain, atomic)NSMutableArray* eventQueue;

//condition for queue's status
@property(nonatomic, retain)NSCondition* queueCondition;


/* METHODS */

//add an object to the queue
-(void)enqueue:(id)anObject;

//dequeue
// ->forever, process events from queue
-(void)dequeue;

//determine if process is a known encryption utility
// that is creating encrypted file (can check arguments)
-(BOOL) isEncryptionUtility:(Event*)event;

//show alert to the user
// ->block until response, which is returned from this method
-(CFOptionFlags)alertUser:(Event*)event;

@end
