//
//  WatchEvent.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "PluginBase.h"
#import "WatchEvent.h"



@implementation WatchEvent

@synthesize path;
@synthesize uuid;
@synthesize flags;
@synthesize match;
@synthesize plugin;
@synthesize process;
@synthesize timestamp;
@synthesize wasBlocked;
@synthesize reportedUID;


//init
-(id)init
{
    self = [super init];
    if(self)
    {
        //create a uuid
        uuid = [NSUUID UUID];
        
        //create timestamp
        timestamp = [NSDate date];
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created watch ID with %@", self.uuid]);
    }
    
    return self;
}

//determines is a (new) watch event is related
// ->checks things like process ids, plugins, paths, etc
-(BOOL)isRelated:(WatchEvent*)newWatchEvent
{
    //case 1:
    // ->different processes mean unrelated watch events
    if(self.process.pid != newWatchEvent.process.pid)
    {
        //nope!
        return NO;
    }
    
    //case 2:
    // ->different plugins mean unrelated watch events
    if(self.plugin != newWatchEvent.plugin)
    {
        //nope!
        return NO;
    }
    
    //case 3:
    // ->10s between now and last watch event means unrelated watch events
    if(10 <= [[NSDate date] timeIntervalSinceDate:self.timestamp])
    {
        //nope!
        return NO;
    }

    
    //case 4:
    // ->watch items paths aren't related means unrelated watch events
    // TODO: use 'in directory' code - google this!
    // check both paths to make sure a isn't in b and b isn't in a
    
    
    
    //events appear to be related
    return YES;
}

//takes a watch event and creates an alert dictionary that's serializable into a plist
// ->needed since notification framework can only handle dictionaries of this kind
-(NSMutableDictionary*)createAlertDictionary
{
    //watch event as dictionary
    NSMutableDictionary* alertInfo = nil;
    
    //alloc dictionary
    alertInfo = [NSMutableDictionary dictionary];
    
    //save watch item ID
    alertInfo[KEY_WATCH_EVENT_UUID] = [self.uuid UUIDString];
    
    /* for top of alert window */
    
    //add process label
    alertInfo[@"processLabel"]  = [self valueForStringItem:self.process.name];
    
    //add alert msg
    alertInfo[@"alertMsg"] = [self valueForStringItem:self.plugin.alertMsg];
    
    /* for bottom of alert window */
    
    //add process name
    alertInfo[@"processName"] = [self valueForStringItem:self.process.name];
    
    //add process pid
    alertInfo[@"processID"] = [NSString stringWithFormat:@"%d", self.process.pid];
    
    //add full path to process
    alertInfo[@"processPath"] = [self valueForStringItem:self.process.path];
    
    //set name of startup item
    alertInfo[@"itemName"] = [self valueForStringItem:[self.plugin startupItemName:self]];
    
    //set file of startup item
    alertInfo[@"itemFile"] = [self valueForStringItem:self.path];
    
    //set binary (path) of startup item
    alertInfo[@"itemBinary"] = [self valueForStringItem: [self.plugin startupItemBinary:self]];
    
    //add process pid
    alertInfo[@"parentID"] = [NSString stringWithFormat:@"%d", self.process.ppid];
    
    //dbg msg
    // ->here since don't want to print out icon!
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"ALERT INFO dictionary: %@", alertInfo]);
    
    //add icon
    alertInfo[@"processIcon"] = [[self.process getIconForProcess] TIFFRepresentation];
    
    return alertInfo;
}


//check if something is nil
// ->if so, return a default ('unknown') value
-(NSString*)valueForStringItem:(NSString*)item
{
    //return value
    NSString* value = nil;
    
    //check if item is nil
    if(nil != item)
    {
        //just set to item
        value = item;
    }
    else
    {
        //set to default
        value = @"unknown";
    }
    
    return value;
}

//for pretty print
-(NSString *)description {
    return [NSString stringWithFormat: @"process=%@, file path=%@, flags=%lx, timestamp: %@", self.process, self.path, (unsigned long)self.flags, self.timestamp];
}


@end
