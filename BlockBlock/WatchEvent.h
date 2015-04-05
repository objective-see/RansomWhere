//
//  WatchEvent.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "Process.h"

#import <Foundation/Foundation.h>
#import <Security/AuthSession.h>

@class PluginBase;

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
}

/* METHODS */

//determines is a (new) watch event is related
// ->checks things like process ids, plugins, paths, etc
-(BOOL)isRelated:(WatchEvent*)newWatchEvent;

//takes a watch event and creates an alert dictionary that's serializable into a plist
// ->needed since notification framework can only handle dictionaries of this kind
-(NSMutableDictionary*)createAlertDictionary;

@property BOOL wasBlocked;
@property NSUInteger flags;
@property (nonatomic, retain)NSString* path;
@property (nonatomic, retain)NSString* match;
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
