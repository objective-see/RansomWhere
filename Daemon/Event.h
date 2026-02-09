//
//  Event.h
//  RansomWhere?
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

@class Item;
@class Event;
@class PluginBase;

@import Foundation;

#import "Process.h"
#import <Security/AuthSession.h>
#import <EndpointSecurity/EndpointSecurity.h>

@interface Event : NSObject
{
    
}

/* PROPERTIES */

//process object
@property(nonatomic, retain)Process* process;

//(startup) item
@property(nonatomic, retain)Item* item;

//(user) action
@property NSUInteger action;

/* METHODS */

//init
-(id)init:(Process*)process;

//create an (deliverable) obj
-(NSMutableDictionary*)toAlert;

/* PROPERTIES */

//uuid
@property (nonatomic, retain)NSString* uuid;

//time stamp
@property (nonatomic, retain)NSDate *timestamp;

@end
