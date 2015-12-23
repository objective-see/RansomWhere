//
//  AppLoginItem.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Process.h"
#import "Logging.h"
#import "Utilities.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "AppLoginItem.h"
#import "ProcessMonitor.h"
#import "OrderedDictionary.h"

@implementation AppLoginItem

@synthesize matchPredicate;

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
        self.type = PLUGIN_TYPE_APP_LOGIN_ITEM;
        
        //init match predicate
        self.matchPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", APP_LOGIN_ITEM_REGEX];
    }

    return self;
}

//take a closer look to make sure watch event is really one we care about
// ->for app login items, look for exact match on any /Applications/*/Contents/Library/LoginItems/*.app
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    //flag
    // ->default to ignore
    BOOL shouldIgnore = YES;
    
    //directory flag
    BOOL isDirectory = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is a app helper login item", watchEvent.path]);
    
    //ignore anything that's not a directory
    // ->since app helper login items are bundles (directories)
    if( (YES != [[NSFileManager defaultManager] fileExistsAtPath:watchEvent.path isDirectory:&isDirectory]) ||
        (YES != isDirectory) )
    {
        //bail
        goto bail;
    }

    //skip things that don't look like an app login item
    // ->'/Applications/*/Contents/Library/LoginItems/*.app'
    if(YES != [self.matchPredicate evaluateWithObject:watchEvent.path])
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is not a regex match, so ignoring", watchEvent.path]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ matches regex, so not ignoring", watchEvent.path]);
    
    //set flag
    shouldIgnore = NO;
    
//bail
bail:

    return shouldIgnore;
}

//invoked when user clicks 'block'
// ->just delete login item app bundle
-(BOOL)block:(WatchEvent*)watchEvent;
{
    //return var
    BOOL wasBlocked = NO;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), watchEvent.path]);
    
    //delete login item app
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:watchEvent.path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", watchEvent.path, error]);
        
        //bail
        goto bail;
    }
    
    //TODO: FIX!!! this logic is wrong -gotta look up from proc list (see loginItem.m)
    
    //kill the persistent process
    if(0 != watchEvent.process.pid)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killing %@ (pid: %d)", watchEvent.path, watchEvent.process.pid]);
        if(0 != kill(watchEvent.process.pid, SIGKILL))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill login item %@ (pid: %d)", watchEvent.path, watchEvent.process.pid]);
        }
    }
    //pid not found
    // ->just log msg about this (might not have been started yet, etc)
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to find pid for %@", watchEvent.path]);
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"application login item was blocked!");
    
    //happy
    wasBlocked = YES;
    
//bail
bail:
    
    return wasBlocked;
}

//get the name of the app login item
// ->try load bundle in a loop (as it might not exist yet), then extract name
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    //name of app login item
    NSString* name = nil;
    
    //max wait time
    // ->1 second
    float maxWait = 1.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracting app login item name for %@", watchEvent.path]);
    
    //try to get name of kext
    // ->might have to try several time since Info.plist may not exist right away...
    do
    {
        //nap (.1 seconds)
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //load bundle
        // ->and see if name is available
        bundle = [NSBundle bundleWithPath:watchEvent.path];
        if( (nil != bundle) &&
            (nil != bundle.infoDictionary[@"CFBundleName"]) )
        {
            //save it
            name = bundle.infoDictionary[@"CFBundleName"];
            
            //got name, so bail
            break;
        }
        
        //inc
        currentWait += WAIT_INTERVAL;
        
    //while timeout isn't hit
    } while(currentWait < maxWait);
    
    //sanity check
    if(nil == name)
    {
        //dbg err msg
        logMsg(LOG_DEBUG, @"failed to find name for app login item");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat: @"extracted name: %@", name]);
    
//bail
bail:
    
    return name;
}

//get the binary of the login item
// ->try load bundle in a loop (as it might not exist yet), then extract binary
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //name of kext
    NSString* binary = nil;
    
    //max wait time
    // ->1 second
    float maxWait = 1.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracting app login item binary for %@", watchEvent.path]);
    
    //try to get name of kext
    // ->might have to try several time since bundle may not exist right away...
    do
    {
        //nap
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //load bundle
        // ->and see if name is available
        bundle = [NSBundle bundleWithPath:watchEvent.path];
        
        //extract kext name
        if( (nil != bundle) &&
            (nil != bundle.executablePath) )
        {
            //save it
            binary = bundle.executablePath;
            
            //got it, so bail
            break;
        }
        
        //inc
        currentWait += WAIT_INTERVAL;
        
        //while timeout isn't hit
    } while(currentWait < maxWait);
    
    //sanity check
    if(nil == binary)
    {
        //dbg err msg
        logMsg(LOG_DEBUG, @"failed to find binary for app login item");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracted name: %@", binary]);
    
//bail
bail:
    
    return binary;
}

@end
