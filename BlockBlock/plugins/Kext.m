//
//  kext.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "kext.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "WatchEvent.h"

#import <libkern/OSReturn.h>
#include <IOKit/kext/KextManager.h>

@implementation Kext

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
        self.type = PLUGIN_TYPE_KEXT;
    }

    return self;
}


//take a closer look to make sure watch event is really one we care about
// for kext, only care about the creation of the .kext directory (not files under it)
// TODO: add support modifications of existing .kexts
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    //flag
    // ->default to ignore
    BOOL shouldIgnore = YES;
    
    //directory flag
    BOOL isDirectory = NO;
    
    //ignore anything that's not a directory
    // ->since .kexts are bundles (directories)
    if( (YES != [[NSFileManager defaultManager] fileExistsAtPath:watchEvent.path isDirectory:&isDirectory]) ||
        (YES != isDirectory) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is not a directory, so ignoring", watchEvent.path]);
        #endif
        
        //bail
        goto bail;
    }
    
    //check creation of directory or rename
    //  note: rename, to account for atomically created dirs?
    if( (FSE_CREATE_DIR == watchEvent.flags) ||
        (FSE_RENAME == watchEvent.flags) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is a directory and has 'FSE_CREATE_DIR/FSE_RENAME' set (not ignoring)", watchEvent.path]);
        #endif
        
        //don't ignore
        shouldIgnore = NO;
    }

//bail
bail:
    
    return shouldIgnore;
}


//for kext
// ->unload, then delete entire kext directory
-(BOOL)block:(WatchEvent*)watchEvent;
{
    //return var
    BOOL wasBlocked = NO;
    
    //error
    NSError* error = nil;
    
    //status from unloading kext
    OSReturn status = !STATUS_SUCCESS;
    
    //bundle
    NSBundle* bundle = nil;
    
    //bundle (kext) id
    NSString* bundleID = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), watchEvent.path]);
    #endif
    
    //load bundle
    // ->need bundle (kext) ID
    bundle = [NSBundle bundleWithPath:watchEvent.path];
    
    //try get bundle (kext) ID
    if( (nil != bundle) && (nil != bundle.executablePath) )
    {
        //save it
        bundleID = bundle.bundleIdentifier;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got kext id: %@", bundleID]);
    #endif
    
    //try unload kext
    if(nil != bundleID)
    {
        //unload
        status = KextManagerUnloadKextWithIdentifier((__bridge CFStringRef)(bundleID));
        if(STATUS_SUCCESS != status)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to unload kext (%d)", status]);
            
            //don't bail
            // ->still want to delete .kext
        }
        
        //unloaded ok
        // ->just log this fact...
        else
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"successfully unloaded kext");
            #endif
        }
    }
    
    //delete directory
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:watchEvent.path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete %@ (%@)", watchEvent.path, error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"kext was blocked!");
    #endif
    
    //happy
    wasBlocked = YES;
    
//bail
bail:
    
    return wasBlocked;
}

//get the name of the kext
// ->try load bundle in a loop (as it might not exist yet), then extract name
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    //name of kext
    NSString* kextName = nil;
    
    //max wait time
    // ->1 second
    float maxWait = 1.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracting kext name for %@", watchEvent.path]);
    #endif
    
    //try to get name of kext
    // ->might have to try several time since Info.plist may not exist right away...
    do
    {
        //dbg msg
        //logMsg(LOG_DEBUG, @"napping...waiting for kext's name");
        
        //nap (.1 seconds)
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //load bundle
        // ->use name of binary
        bundle = [NSBundle bundleWithPath:watchEvent.path];
        if( (nil != bundle) &&
            (nil != bundle.infoDictionary[@"CFBundleExecutable"]) )
        {
            //save it
            kextName = [bundle.infoDictionary[@"CFBundleExecutable"] lastPathComponent];
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat: @"extracted name: %@", kextName]);
            #endif
            
            //got name, so bail
            break;
        }
        
        //inc
        currentWait += WAIT_INTERVAL;
        
    //while timeout isn't hit
    } while(currentWait < maxWait);
    
    //couldn't extract?
    // ->just use name from path
    if(nil == kextName)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"couldn't extract kext name, using file name");
        #endif
        
        //set
        kextName = [watchEvent.path lastPathComponent];
    }
    
    return kextName;
}

//get the binary of the kext
// ->try load bundle in a loop (as it might not exist yet), then extract binary
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //name of kext
    NSString* kextBinary = nil;
    
    //max wait time
    // ->2 second
    float maxWait = 2.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracting kext binary for %@", watchEvent.path]);
    #endif

    //try to get name of kext
    // ->might have to try several time since bundle may not exist right away...
    do
    {
        //nap
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"napping...waiting for kext's binary name"]);
        #endif
        
        //load bundle
        // ->and see if name is available
        bundle = [NSBundle bundleWithPath:watchEvent.path];
       
        //extract kext name
        if( (nil != bundle) &&
            (nil != bundle.executablePath) )
        {
            //save it
            kextBinary = bundle.executablePath;
            
            //got it, so bail
            break;
        }
        
        //inc
        currentWait += WAIT_INTERVAL;
        
    //while timeout isn't hit
    } while(currentWait < maxWait);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracted name: %@", kextBinary]);
    #endif

    return kextBinary;
}

@end
