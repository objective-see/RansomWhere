//
//  NSMutableArray+QueueAdditions.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (QueueAdditions)
{
    
}

//METHODS
-(id) dequeue;
-(void) enqueue:(id)obj;
-(id) peek:(int)index;
-(id) peekHead;
-(id) peekTail;
-(BOOL) empty;

@end
