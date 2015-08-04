//
//  WatchEvent.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

@class Process;
#import "PluginBase.h"

#import <Foundation/Foundation.h>
#import <Security/AuthSession.h>



@interface WatchEvent : NSObject
{
    //path
    NSString* path;
    
    //matched path
    NSString* match;
    
    //plugin
    PluginBase* plugin;
    
    //flags
    NSUInteger flags;

    //process object
    Process* process;

    //flag indicating user choose to block
    BOOL wasBlocked;
    
    //flag indicating user set 'remember' (action) option
    BOOL shouldRemember;
}

/* METHODS */

//determines is a (new) watch event is related
// ->checks things like process ids, plugins, paths, etc
-(BOOL)isRelated:(WatchEvent*)newWatchEvent;

//determines if a new watch event matches a prev. 'remembered' event
// ->checks paths, etc
-(BOOL)matchesRemembered:(WatchEvent*)rememberedEvent;

//takes a watch event and creates an alert dictionary that's serializable into a plist
// ->needed since notification framework can only handle dictionaries of this kind
-(NSMutableDictionary*)createAlertDictionary;

/* PROPERTIES */



@property BOOL wasBlocked;
@property NSUInteger flags;
@property BOOL shouldRemember;
@property (nonatomic, retain)NSString* path;
@property (nonatomic, retain)NSString* match;

//item binary
// ->need this for matching 'remembered' items
@property (nonatomic, retain)NSString* itemBinary;



@property (nonatomic, retain)Process* process;
@property (nonatomic, retain)PluginBase* plugin;

//uuid
@property (nonatomic, retain)NSUUID* uuid;

//time stamp
@property (nonatomic, retain)NSDate *timestamp;

//reported session
// ->which UID was watch event sent to?
@property uid_t reportedUID;

@end
