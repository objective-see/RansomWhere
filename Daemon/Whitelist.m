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

//TODO: whitelist these all
/*
 
 <string>/Volumes/Citrix Online Launcher/Citrix Online Launcher.app/Contents/MacOS/Citrix Online Launcher</string>
 <string>/Users/patrickw/Library/Application Support/CitrixOnline/GoToMeeting/G2MUpdate</string>
 <string>/Users/patrickw/Downloads/AVRecorder/DerivedData/AVRecorder/Build/Products/Debug/AVRecorder copy.app/Contents/MacOS/AVRecorder</string>
 <string>/Users/patrickw/Downloads/AVRecorder/DerivedData/AVRecorder/Build/Products/Debug/AVRecorder.app/Contents/MacOS/AVRecorder</string>
 <string>/Applications/Utilities/Adobe Creative Cloud/CCXProcess/CCXProcess.app/Contents/libs/node</string>
 <string>/Users/patrickw/Projects/H.264/ffmpeg</string>
 <string>/Library/Google/GoogleSoftwareUpdate/GoogleSoftwareUpdate.bundle/Contents/MacOS/GoogleSoftwareUpdateDaemon</string>
 <string>/Applications/BitTorrent.app/Contents/MacOS/BitTorrent</string>
 <string>/private/var/folders/r3/9nbl60856zn82n6wdtwrxw8w0000gn/T/AppTranslocation/FEEA1D0A-449E-485C-8A9A-E0F366303965/d/Install Dashlane 2.app/Contents/MacOS/Install Dashlane</string>
 */


@implementation Whitelist

@synthesize baselinedBinaries;
@synthesize whitelistedDevIDs;
@synthesize userApprovedBinaries;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        
    }
    
    return self;
}

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
    
    //binary identifier
    // ->sha256 hash or developer id
    NSString* binaryIdentifier = nil;
    
    //alloc
    baselinedApps = [NSMutableDictionary dictionary];
    
    //init path to save list of installed apps
    installedAppsFile = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:BASELINED_FILE];
    
    //bail if already have baselined
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:installedAppsFile])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"baseline app file %@ exists, so no need to baseline", installedAppsFile]);
        #endif
        
        //bail
        goto bail;
    }
    
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
        //create binary object
        binary = [[Binary alloc] init:appBinary attributes:nil];
        if(nil == binary)
        {
            //skip
            continue;
        }
        
        //try grab developer id
        if(nil != binary.signingInfo[KEY_SIGNING_AUTHORITIES])
        {
            //last auth is developer id
            binaryIdentifier = [binary.signingInfo[KEY_SIGNING_AUTHORITIES] lastObject];
        }
        //otherwise use sha256 hash
        else
        {
            //use hash
            binaryIdentifier = binary.sha256Hash;
        }
        
        //skip any ones that couldn't be id'd
        if(nil == binaryIdentifier)
        {
            //skip
            continue;
        }
        
        //add to list
        baselinedApps[binary.path] = binaryIdentifier;
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
    
//bail
bail:
    
    return;
}

//load whitelisted dev IDs, baselined & allowed apps
-(void)loadItems
{
    //load whitelisted developers
    self.whitelistedDevIDs = [NSMutableArray arrayWithContentsOfFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:WHITE_LISTED_FILE]];
    
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
    //approved binary id
    NSString* binaryID = nil;
    
    //first try use binary dev ID
    if( (0 == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
        (nil != [binary.signingInfo[KEY_SIGNING_AUTHORITIES] lastObject]) )
    {
        binaryID = [binary.signingInfo[KEY_SIGNING_AUTHORITIES] lastObject];
    }
    //otherwise use hash
    else
    {
        //hash
        binaryID = binary.sha256Hash;
    }
    
    //sanity check
    if(nil == binaryID)
    {
        //TODO:err msg
        
        //bail
        goto bail;
    }
    
    //add to list of user-approved binaries
    self.userApprovedBinaries[binary.path] = binaryID;
    
    //write out
    [self.userApprovedBinaries writeToFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_FILE] atomically:YES];

//bail
bail:

    return;
}

//determine if binary is allowed
// ->either baselined or approved based on path *and* hash
-(BOOL)isWhitelisted:(Binary*)binary
{
    //flag
    BOOL whiteListed = NO;
    
    //approved binary
    NSString* approvedBinaryID = nil;
    
    //CHECK 1: binary signed with a whitelisted developer ID?
    if(0 == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //check each
        for(NSString* signingAuth in binary.signingInfo[KEY_SIGNING_AUTHORITIES])
        {
            //check
            if(YES == [self.whitelistedDevIDs containsObject:signingAuth])
            {
                //found!
                whiteListed = YES;
            
                //bail
                goto bail;
            }
        }
    }
    
    //CHECK 2: binary a baselined one?
    approvedBinaryID = self.baselinedBinaries[binary.path];
    if(nil != approvedBinaryID)
    {
        //match base on dev id
        if( (0 == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
            (YES == [approvedBinaryID isEqualToString:[binary.signingInfo[KEY_SIGNING_AUTHORITIES] lastObject]]) )
        {
            //found!
            whiteListed = YES;
            
            //bail
            goto bail;
        }
        //match on hash
        else if(YES == [approvedBinaryID isEqualToString:binary.sha256Hash])
        {
            //found!
            whiteListed = YES;
            
            //bail
            goto bail;
        }
        //path matched, but not id
        // ->maybe app was infected, or unsigned & updated
        //   either way, remove it from list as its not verifiable anymore
        [self.baselinedBinaries removeObjectForKey:binary.path];
        
        //write out
        [self.baselinedBinaries writeToFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:BASELINED_FILE] atomically:YES];
    }
    
    //CHECK 3: binary a user-approved one?
    approvedBinaryID = self.userApprovedBinaries[binary.path];
    if(nil != approvedBinaryID)
    {
        //match base on dev id
        if( (0 == [binary.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
            (YES == [approvedBinaryID isEqualToString:[binary.signingInfo[KEY_SIGNING_AUTHORITIES] lastObject]]) )
        {
            //found!
            whiteListed = YES;
            
            //bail
            goto bail;
        }
        //match on hash
        else if(YES == [approvedBinaryID isEqualToString:binary.sha256Hash])
        {
            //found!
            whiteListed = YES;
            
            //bail
            goto bail;
        }
        //path matched, but not id
        // ->maybe app was infected, or unsigned & updated
        //   either way, remove it from list as its not verifiable anymore
        [self.userApprovedBinaries removeObjectForKey:binary.path];
        
        //write out
        [self.userApprovedBinaries writeToFile:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_FILE] atomically:YES];
    }

//bail
bail:
    
    return whiteListed;
}

@end

