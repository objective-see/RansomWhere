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

//processes explicity disallowed by the user
@property(nonatomic, retain)NSMutableDictionary* disallowedProcs;

//process that were reported to the user
@property(nonatomic, retain)NSMutableSet* reportedProcs;

//pid -> last encrypted file timestamp
@property(nonatomic, retain)NSMutableDictionary* lastEncryptedFiles;

//white-listed apps
@property(nonatomic, retain)NSMutableSet* whiteList;


/* METHODS */

//add an object to the queue
-(void)enqueue:(id)anObject;

//dequeue
// ->forever, process events from queue
-(void)dequeue:(id)threadParam;

//show alert to the user
// ->block until response, which is returned from this method
-(CFOptionFlags)alertUser:(Event*)event prevEncryptedFile:(NSString*)prevEncryptedFile;

@end
