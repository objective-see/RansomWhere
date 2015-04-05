//
//  NSMutableArray+QueueAdditions.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "NSMutableArray+QueueAdditions.h"

@implementation NSMutableArray (QueueAdditions)

// Add to the tail of the queue
-(void)enqueue:(id)anObject
{
    //TODO: add @synchronized - maybe not if atomic in property is ok!!!
    
        // Push the item in
        [self addObject: anObject];
    
}

// Grab the next item in the queue, if there is one
-(id)dequeue
{
    //TODO: add @synchronized
    
    // Set aside a reference to the object to pass back
    id queueObject = nil;
    
    // Do we have any items?
    if ([self lastObject]) {
        // Pick out the first one
        queueObject = [self objectAtIndex: 0];
        
        // Remove it from the queue
        [self removeObjectAtIndex: 0];
    }
    
    // Pass back the dequeued object, if any
    return queueObject;
}

// Takes a look at an object at a given location
-(id)peek: (int) index
{
    // Set aside a reference to the peeked at object
    id peekObject = nil;
    // Do we have any items at all?
    if ([self lastObject]) {
        // Is this within range?
        if (index < [self count]) {
            // Get the object at this index
            peekObject = [self objectAtIndex: index];
        }
    }
    
    // Pass back the peeked at object, if any
    return peekObject;
}

// Let's take a look at the next item to be dequeued
-(id)peekHead
{
    // Peek at the next item
    return [self peek: 0];
}

// Let's take a look at the last item to have been added to the queue
-(id)peekTail
{
    // Pick out the last item
    return [self lastObject];
}

// Checks if the queue is empty
-(BOOL)empty
{
    return ([self lastObject] == nil);
}

@end