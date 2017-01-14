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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        #endif
        
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
    
    //app login item directory
    NSString* loginItemDirectory = nil;
    
    //app login item
    NSString* loginItem = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is/or has an app helper login item", watchEvent.path]);
    #endif
    
    //ignore anything that's not a directory
    // ->since app helper login items are bundles (directories)
    if( (YES != [[NSFileManager defaultManager] fileExistsAtPath:watchEvent.path isDirectory:&isDirectory]) ||
        (YES != isDirectory) )
    {
        //bail
        goto bail;
    }
    
    //ignore things that aren't creation/rename events
    if( (FSE_CREATE_DIR != watchEvent.flags) &&
        (FSE_RENAME != watchEvent.flags) )
    {
        //bail
        goto bail;
    }
    
    //bail if it doesn't end in .app
    // ->should at least get an alert for either the top-level app, or the login item app
    if(YES != [watchEvent.path hasSuffix:@".app"])
    {
        //bail
        goto bail;
    }
    
    //path ends in .app, check if its an app login item
    // ->if not, often don't get the notification for the login item
    //   so manually try find one
    if(YES != [self.matchPredicate evaluateWithObject:watchEvent.path])
    {
        //init login item directory
        loginItemDirectory = [NSString pathWithComponents:@[watchEvent.path, @"/Contents/Library/LoginItems/"]];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"looking for login item in %@", loginItemDirectory]);
        #endif
        
        //try manually find it
        do
        {
            //nap (.1 seconds)
            [NSThread sleepForTimeInterval:WAIT_INTERVAL];
            
            //grab any .app bundles in app's LoginItems/
            loginItem = [[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:loginItemDirectory error:nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.app'"]] firstObject];

            //found it?
            if(nil != loginItem)
            {
                //update watch path
                watchEvent.path = [NSString pathWithComponents:@[loginItemDirectory, loginItem]];
                
                //set flag
                shouldIgnore = NO;
                
                //exit loop
                break;
            }
            
            //inc
            currentWait += WAIT_INTERVAL;
            
        //while timeout isn't hit
        } while(currentWait < 1.0f);
    }
    //fsevent for the login item
    else
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ matches regex, so not ignoring", watchEvent.path]);
        #endif
        
        //set flag
        shouldIgnore = NO;
    }

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
    
    //pid
    pid_t loginItemPID = 0;
    
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
    
    //get most recent process that matches path
    loginItemPID = mostRecentProc(((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList, watchEvent.path);
    
    //kill the persistent process
    if(0 != loginItemPID)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killing %@ (pid: %d)", watchEvent.path, loginItemPID]);
        #endif
        
        //kill
        if(0 != kill(loginItemPID, SIGKILL))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill login item %@ (pid: %d)", watchEvent.path, loginItemPID]);
        }
    }
    
    //pid not found
    // ->just log msg about this (might not have been started yet, etc)
    #ifdef DEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to find pid for %@", watchEvent.path]);
    }
    #endif
    
    #ifdef DEBUG
    //dbg msg
    logMsg(LOG_DEBUG, @"application login item was blocked!");
    #endif
    
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracting app login item name for %@", watchEvent.path]);
    #endif
    
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat: @"extracted name: %@", name]);
    #endif
    
//bail
bail:
    
    return name;
}

//get the binary of the login item
// ->try load bundle in a loop (as it might not exist yet), then extract binary
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //name of binary
    NSString* binary = nil;
    
    //max wait time
    // ->1 second
    float maxWait = 1.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracting app login item binary for %@", watchEvent.path]);
    #endif
    
    //try to get name of binary
    // ->might have to try several time since bundle may not exist right away...
    do
    {
        //nap
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //load bundle
        // ->and see if name is available
        bundle = [NSBundle bundleWithPath:watchEvent.path];
        
        //extract binary name
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"failed to find binary for app login item");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracted name: %@", binary]);
    #endif
    
//bail
bail:
    
    return binary;
}

@end
