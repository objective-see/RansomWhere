//
//  Queue.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


//from: https://github.com/esromneb/ios-queue-object/blob/master/NSMutableArray%2BQueueAdditions.h

#import <Foundation/Foundation.h>
#import "NSMutableArray+QueueAdditions.h"

@interface Queue : NSObject
{
    //the queue
    NSMutableArray* eventQueue;
    
    //queue processor thread
    NSThread* qProcessorThread;
    
    //condition for queue's status
    NSCondition* queueCondition;
    
    //condition for continuation
    //NSCondition* continueCondition;
    
    //flag indicating queue can continue processing
    //BOOL canContinue;
}


//event queue
@property(retain, atomic)NSMutableArray* eventQueue;


@property (nonatomic, retain)NSThread* qProcessorThread;
@property (nonatomic, retain)NSCondition* queueCondition;


//METHODS

//add an object to the queue
-(void)enqueue:(id)anObject;

//for any old reported watch events
// ->remove em, to keep numbers in check!
-(void)pruneWatchEvents:(NSMutableDictionary*)reportedWatchEvents;

@end
