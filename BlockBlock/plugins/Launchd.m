//
//  kext.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Launchd.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "WatchEvent.h"


@implementation Launchd

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    if(nil != self)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        
        //set type
        self.type = PLUGIN_TYPE_LAUNCHD;
    }

    return self;
}


//take a closer look to make sure watch event is really one we care about
// for launch daemon and agents, it's (for now) the creation of the plist

// TODO: add support modifications of existing launch items
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    //flag
    // ->default to ignore
    BOOL shouldIgnore = YES;
    
    //check creation of file
    // ->just looking for the create/rename of the launch item plist
    //   note: rename, to account for atomically created files
    if( ( (FSE_CREATE_FILE == watchEvent.flags) || (FSE_RENAME == watchEvent.flags) ) &&
        [[watchEvent.path pathExtension] isEqualToString:@"plist"] )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ has 'FSE_CREATE_FILE || FSE_RENAME' set and is a plist (not ignoring)", watchEvent.path]);
        
        //don't ignore
        shouldIgnore = NO;
    }
    
    return shouldIgnore;
}


//for launch item
// ->unload, then delete plist and binary it references
-(BOOL)block:(WatchEvent*)watchEvent;
{
    //return var
    BOOL wasBlocked = NO;
    
    //binary (path) of launch item
    NSString* itemBinary = nil;
    
    //error
    NSError* error = nil;
    
    //status
    NSUInteger status = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), watchEvent.path]);
    
    //STEP 1: unload launch item via launchctl
    
    //unload via 'launchctl'
    status = execTask(LAUNCHCTL, @[@"unload", watchEvent.path], YES);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unload %@, error: %lu", watchEvent.path, (unsigned long)status]);
        
        //don't bail since still want to delete, etc
    }
    //just dbg output
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"unload %@", watchEvent.path]);
    }
    
    //STEP 2: delete launch item binary
   
    //get name of startup binary
    itemBinary = [self startupItemBinary:watchEvent];
    
    //delete binary
    if(nil != itemBinary)
    {
        //delete
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:itemBinary error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", itemBinary, error]);
            
            //don't bail since still want to delete plist...
        }
        //just dbg output
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted %@", itemBinary]);
        }
    }
    //couldn't get path to binary
    // ->just log msg (since still want to try delete plist)
    else
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find launch item binary in %@", watchEvent.path]);
    }
    
    //STEP 3: delete the launch item's plist
    
    //delete
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:watchEvent.path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", watchEvent.path, error]);
        
        //don't bail since still want to delete plist...
    }
    //just dbg output
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted %@", watchEvent.path]);
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"launch item was blocked!");
    
    //happy
    wasBlocked = YES;
    
    return wasBlocked;
}


//get the name of the launch item
// ->use name of binary from plist
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    //get binary path
    // ->just return binary name
    return [[self startupItemBinary:watchEvent] lastPathComponent];
}

//get the binary (path) of the launch item
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //path to launch item binary
    NSString* itemBinary = nil;
    
    //value of 'ProgramArguments'
    // ->can either be array or string
    id programArgs = nil;
    
    //get program args
    // ->path is in args[0]
    programArgs = getValueFromPlist(watchEvent.path, @"ProgramArguments", 1.0f);
    if(nil != programArgs)
    {
        //when its an array
        // ->first object is the item binary
        if(YES == [programArgs isKindOfClass:[NSArray class]])
        {
            //extract path to binary
            itemBinary = [(NSArray*)programArgs firstObject];
        }
        //otherwise, its likely a string
        // ->just use as is (assume no args)
        else if(YES == [programArgs isKindOfClass:[NSString class]])
        {
            //assign
            itemBinary = (NSString*)programArgs;
        }
    }
    //when 'ProgramArguments' fails
    // ->check for just 'Program' key and use that
    else
    {
        //get value for 'ProgramArguments'
        // ->always a string
        itemBinary = getValueFromPlist(watchEvent.path, @"Program", 1.0f);
    }
    
    return itemBinary;
}
@end
