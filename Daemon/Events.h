//
//  file: Events.m
//  project: RansomWhere? (launch daemon)
//  description: send alert to user via XPC
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//


@class Event;

@import Foundation;

#import "XPCUserProto.h"
#import "XPCUserClient.h"

@interface Events : NSObject

/* PROPERTIES */

//observer for new client/user
@property(nonatomic, retain)id userObserver;

//xpc client for talking to user (login item)
//@property(nonatomic, retain)XPCUserClient* xpcUserClient;

//console user
@property(nonatomic, retain)NSString* consoleUser;

/* METHODS */

//create an alert object
//-(NSMutableDictionary*)create:(Event*)event;

//via XPC, send an alert
-(BOOL)deliver:(Event*)event;

@end
