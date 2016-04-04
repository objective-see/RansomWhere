//
//  Queue.h
//  RansomWhere
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSMutableArray+QueueAdditions.h"

@interface Queue : NSObject
{
    
}

/* PROPERTIES */

//event queue
@property(retain, atomic)NSMutableArray* eventQueue;

//condition for queue's status
@property (nonatomic, retain)NSCondition* queueCondition;

//processes explicity allowed by the user
@property (nonatomic, retain)NSMutableDictionary* allowedProcs;

//processes explicity disallowed by the user
@property (nonatomic, retain)NSMutableDictionary* disallowedProcs;


/* METHODS */

//add an object to the queue
-(void)enqueue:(id)anObject;

//dequeue
// ->forever, process events from queue
-(void)dequeue:(id)threadParam;

@end
