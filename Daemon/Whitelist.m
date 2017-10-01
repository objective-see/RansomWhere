//
//  WhiteList.m
//  Daemon
//
//  Created by Patrick Wardle on 3/4/17.
//  Copyright © 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "Whitelist.h"

#import <Foundation/Foundation.h>

@implementation Whitelist

@synthesize baselinedBinaries;
@synthesize whitelistedDevIDs;
@synthesize graylistedBinaries;
@synthesize userApprovedBinaries;


//enumerate all installed apps
// ->only done once, unless -reset
-(void)baseline
{
    //list of installed apps
    NSMutableArray* installedApps = nil;
    
    //path to prev. saved list of installed apps
    NSString* installedAppsFile = nil;
    
    //binary object
    Binary* binary = nil;
    
    //list of baseline app binaries/signing info
    NSMutableDictionary* baselinedApps = nil;
    
    //alloc
    baselinedApps = [NSMutableDictionary dictionary];
    
    //init path to save list of installed apps
    installedAppsFile = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:BASELINED_FILE];
    
    //bail if we've already baselined
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:installedAppsFile])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"baseline app file %@ exists, so no need to baseline", installedAppsFile]);
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"execing 'system_profiler' to enumerate all installed apps (please wait!)");
    #endif
    
    //enumerate via 'system_profiler'
    installedApps = enumerateInstalledApps();
    if( (nil == installedApps) ||
        (0 == installedApps.count) )
    {
        //err msg
        logMsg(LOG_ERR, @"failed to enumerate installed apps");
        
        //bail
        goto bail;
    }
    
    //process each path
    for(NSString* appBinary in installedApps)
    {
        //pool
        @autoreleasepool
        {
        
        //create binary object
        binary = [[Binary alloc] init:appBinary];
        if( (nil == binary) ||
            (nil == binary.identifier) )
        {
            //skip
            continue;
        }
        
        //add to list
        baselinedApps[binary.path] = binary.identifier;
            
        }//pool
    }
        
    //save them all to disk
    if(YES != [baselinedApps writeToFile:installedAppsFile atomically:YES])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save installed apps to %@", installedAppsFile]);
        
        //bail
        goto bail;
    }
        
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saved list of installed/baseline apps to %@", installedAppsFile]);
    #endif
    
bail:
    
    return;
}

//load whitelisted dev IDs, baselined & allowed apps
-(void)loadItems
{
    //load whitelisted developers
    self.whitelistedDevIDs = [NSMutableArray arrayWithContentsOfFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:WHITE_LISTED_FILE]];
    
    //load graylisted apps
    self.graylistedBinaries = [NSMutableArray arrayWithContentsOfFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:GRAY_LIST_FILE]];
    
    //load baseline'd binaries
    self.baselinedBinaries = [NSMutableDictionary dictionaryWithContentsOfFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:BASELINED_FILE]];
    
    //load user-approved binaries
    self.userApprovedBinaries = [NSMutableDictionary dictionaryWithContentsOfFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_FILE]];
    
    return;
}

//update list of approved apps
// ->when user 'allows'/approves app
-(void)updateApproved:(Binary*)binary
{
    //sanity check
    if(nil == binary.identifier)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"%@ doesn't have an identifier, so can't permanently approve", binary.path]);
        
        //bail
        goto bail;
    }
    
    //first one?
    if(nil == self.userApprovedBinaries)
    {
        //init
        userApprovedBinaries = [NSMutableDictionary dictionary];
    }
    
    //sync
    @synchronized (self.userApprovedBinaries)
    {
    
    //add to list of user-approved binaries
    self.userApprovedBinaries[binary.path] = binary.identifier;
    
    //write out
    [self.userApprovedBinaries writeToFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_FILE] atomically:YES];
    
    }//sync
        
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updated persistent list of user approved apps (%@)", USER_APPROVED_FILE]);
    #endif
    
bail:

    return;
}

//classify binary
// ->either baselined, approved, whitelisted, or graylisted
-(void)classify:(Binary*)binary
{
    //approved binary
    NSString* approvedBinaryID = nil;
    
    //CHECK 1: binary signed with a whitelisted developer ID?
    if(noErr == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //check each
        for(NSString* signingAuth in binary.signingInfo[KEY_SIGNING_AUTHORITIES])
        {
            //check
            if(YES == [self.whitelistedDevIDs containsObject:signingAuth])
            {
                //set flag
                binary.isWhiteListed = YES;
                
                //done with this check
                break;
            }
        }
    }
    
    //CHECK 2: binary a baselined one?
    approvedBinaryID = self.baselinedBinaries[binary.path];
    if(nil != approvedBinaryID)
    {
        //match?
        if(YES == [approvedBinaryID isEqualToString:binary.identifier])
        {
            //set flag
            binary.isBaseline = YES;
        }
        
        //found a path match, in list of baseline'd binary, but not an id match
        // ->that's odd (something changed), so remove as it's not verifable anymore
        else
        {
            //remove
            [self.baselinedBinaries removeObjectForKey:binary.path];
    
            //write out
            [self.baselinedBinaries writeToFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:BASELINED_FILE] atomically:YES];
        }
    }
    
    //CHECK 3: binary a user-approved one?
    approvedBinaryID = self.userApprovedBinaries[binary.path];
    if(nil != approvedBinaryID)
    {
        //match?
        if(YES == [approvedBinaryID isEqualToString:binary.identifier])
        {
            //set flag
            binary.isApproved = YES;
        }
        
        //found a path match, in list of baseline'd binary, but not an id match
        // ->that's odd (something changed), so remove as it's not verifable anymore
        else
        {
            //sync
            @synchronized (self.userApprovedBinaries)
            {
                
            //remove
            [self.userApprovedBinaries removeObjectForKey:binary.path];
            
            //write out
            [self.userApprovedBinaries writeToFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_FILE] atomically:YES];
                
            }//sync
        }
    }
    
    //CHECK 4: binary in hardcoded gray list?
    if(noErr == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //set flag
        binary.isGrayListed = [self.graylistedBinaries containsObject:binary.signingInfo[KEY_SIGNATURE_IDENTIFIER]];
    }
    
    return;
}

@end

