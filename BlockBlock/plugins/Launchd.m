//
//  kext.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "Launchd.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "WatchEvent.h"


@implementation Launchd

@synthesize itemBinary;

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
    // ->just looking for the create of the launch item plist
    if((FSE_CREATE_FILE == watchEvent.flags) &&
       [[watchEvent.path pathExtension] isEqualToString:@"plist"] )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ has 'FSE_CREATE_FILE' set and is a plist (not ignoring)", watchEvent.path]);
        
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
    
    //error
    NSError* error = nil;
    
    //status
    NSUInteger status = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), watchEvent.path]);
    
    //STEP 1: unload launch item via launchctl
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
    if(nil == self.itemBinary)
    {
        //try to get it
        // ->set's 'itemBinary' iVar
        [self startupItemBinary:watchEvent];
    }
    
    //delete binary
    if(nil != self.itemBinary)
    {
        //delete
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:self.itemBinary error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", self.itemBinary, error]);
            
            //don't bail since still want to delete plist...
        }
        //just dbg output
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted %@", self.itemBinary]);
        }
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
// ->'Label' from plist
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    //name of launch item
    NSString* itemName = nil;
    
    //get name
    // ->just value for 'Label'
    itemName = getValueFromPlist(watchEvent.path, @"Label", 1.0f);
    
    return itemName;
}

//get the binary of the launch item
//TODO: i don't think we should use an iVar for item name? like what if its another name?
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //array of 'ProgramArguments'
    NSArray* programArgs = nil;
    
    //only look up if not already found
    if(nil == self.itemBinary)
    {
        //get program args
        // ->path is in args[0]
        programArgs = getValueFromPlist(watchEvent.path, @"ProgramArguments", 1.0f);
        if(nil != programArgs)
        {
            //extract path to binary
            // ->save it into iVar
            self.itemBinary = programArgs[0];
        }
    }
    
    return self.itemBinary;
    
}
@end
