//
//  Install.m
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenDirectory/OpenDirectory.h>

#import "Consts.h"
#import "Install.h"
#import "Logging.h"
#import "Utilities.h"
#import "Uninstall.h"

@implementation Install

//install
-(BOOL)install
{
    //return/status var
    BOOL bRet = NO;
    
    //uninstaller obj
    Uninstall* uninstallObj = nil;
    
    //list of installed launch agents
    // ->can be multiple ones if other users have installed
    NSMutableArray* launchAgentPaths = nil;
    
    //destination path to binary
    NSString* destBinaryPath = nil;
    
    //init destination path for binary
    destBinaryPath = [INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME];

    //check if already installed
    // ->if so, uninstall to get a clean slate!
    if(YES == [Install isInstalled])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"already installed (will uninstall)");
        
        //alloc uninstall obj
        uninstallObj = [[Uninstall alloc] init];
        
        //launch agent can be installed for other users
        // ->grab existing launch agent paths *before* uninstalling
        launchAgentPaths = [self existingLaunchAgents];
    
        //fully uninstall
        [uninstallObj uninstall];
    }
    
    //first check for '/sbin/kextload'
    // ->sometimes boxes don't have this, which will be a problem
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:KEXT_LOAD])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"kext loader (%@) not found", KEXT_LOAD]);
        
        //bail
        goto bail;
    }
    
    //create main install folder
    if(YES != [self createInstallDirectory:INSTALL_DIRECTORY])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to create install directory (%@)", INSTALL_DIRECTORY]);
        
        //bail
        goto bail;
    }
    
    //install binary
    if(YES != [self installBinary:destBinaryPath])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to install binary (%@)", destBinaryPath]);
        
        //bail
        goto bail;
    }
    
    //install as launch agent
    // ->copy launch item plist file into current and other (prev installed) ~/Library/LaunchAgents
    if(YES != [self installLaunchAgent:launchAgentPaths])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to install launch agent(s)");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"installed launch agent component(s)");
    
    //install as launch daemon
    // ->just copy launch item plist file into /Library/LaunchDaemon directory
    if(YES != [self installLaunchDaemon])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to install launch agent");
        
        //bail
        goto bail;
    }
        
    //dbg msg
    logMsg(LOG_DEBUG, @"installed launch deamon");
    
    //install kext
    // ->copy kext (bundle) to /Library/Extensions and set permissions
    if(YES != [self installKext])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to install kext");
        
        //bail
        goto bail;
    }
        
    //dbg msg
    logMsg(LOG_DEBUG, @"installed kext");
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//class method
// ->check if already installed (launch agent)
+(BOOL)isInstalled
{
    //flag
    BOOL installed = NO;
    
    //home directory
    NSString* userHomeDirectory = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"checking if already installed");
    
    //grab home directory of current user
    userHomeDirectory = [getCurrentConsoleUser() objectForKey:@"homeDirectory"];
    if(nil == userHomeDirectory)
    {
        //try another way
        userHomeDirectory = NSHomeDirectory();
    }
    
    //check for launch agent
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchAgentPlist(userHomeDirectory)])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"launch agent exists, so installed already");
        
        //installed!
        installed = YES;
    }

    return installed;
}

//launch agent can be installed for other users
// ->so iterate over all users and save any existing launch agent paths
-(NSMutableArray*)existingLaunchAgents
{
    //(per) user existing plist
    NSString* existingPlist = nil;
    
    //array of all installed launch agents
    NSMutableArray* existingPlists = nil;
    
    //user home directories
    NSArray* userHomeDirectories = nil;
    
    //alloc
    existingPlists = [NSMutableArray array];
    
    //check all users
    // ->do any have the launch agent installed?
    for(ODRecord* userRecord in getUsers())
    {
        //extract home dirs
        userHomeDirectories = [userRecord valuesForAttribute:kODAttributeTypeNFSHomeDirectory error:NULL];
        if(0 == [userHomeDirectories count])
        {
            //skip
            continue;
        }
        
        //get path to where launch agent plist would be
        existingPlist = launchAgentPlist([userHomeDirectories firstObject]);
        
        //save those that exist
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:existingPlist])
        {
            //save
            [existingPlists addObject:existingPlist];
        }
    }
    
    return existingPlists;
}

//create install dir
// -> /Library/BlockBlock, and sets it to be owned by root
-(BOOL)createInstallDirectory:(NSString*)directory
{
    //error
    NSError* error = nil;
    
    //flag
    BOOL createdDirectory = NO;
    
    //create it
    if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create install directory %@ (%@)", directory, error]);
        
        //bail
        goto bail;
    }
    
    //set group/owner to root/wheel
    if(YES != setFileOwner(directory, @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set install directory %@ to be owned by root", directory]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created install directory, %@", directory]);
    #endif
        
    //happy
    createdDirectory = YES;
    
//bail
bail:
    
    return createdDirectory;
}

//copy binary into install directory
// also sets binary to be owned by root
-(BOOL)installBinary:(NSString*)path
{
    //error
    NSError* error = nil;
    
    //flag
    BOOL installedBinary = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"installing binary %@ to %@", [NSBundle mainBundle].bundlePath, path]);
    
    //move self into /Library/BlockBlock
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:[NSBundle mainBundle].bundlePath toPath:path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to copy self (bundle) into %@ (%@)", path, error]);
        
        //bail
        goto bail;
    }
    
    //set group/owner to root/wheel
    if(YES != setFileOwner(path, @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set binary %@ to be owned by root", path]);
        
        //bail
        goto bail;
    }
        
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied binary to install directory, %@", path]);
    #endif
        
    //happy
    installedBinary = YES;
    
//bail
bail:
    
    return installedBinary;
}



//install launch agent
// ->might have to install to multiple locations, if multiple users had it installed
-(BOOL)installLaunchAgent:(NSMutableArray*)destinationPaths
{
    //return/status var
    BOOL bRet = NO;

    //launch item dir
    NSString* launchAgentDirectory = nil;
    
    //array of launch agent (plists)
    NSMutableArray* installedLaunchAgents = nil;
    
    //launch item plist
    NSMutableDictionary* launchItemPlist = nil;
    
    //user's directory permissions
    // ->used to match any created directories
    NSDictionary* userDirAttributes = nil;
    
    //current user's home directory
    NSString* userHomeDirectory = nil;
    
    //current user's launch agent plist
    NSString* userLaunchAgentPlist = nil;
    
    //alloc
    installedLaunchAgents = [NSMutableArray array];
    
    //load launch item plist
    launchItemPlist = [self loadLaunchItemPlist];
    
    //update first arg (path to binary) to location of installed binary
    launchItemPlist[@"ProgramArguments"][0] = [NSString pathWithComponents:@[[INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME], BINARY_SUB_PATH]];
    
    //grab home directory of current user
    userHomeDirectory = [getCurrentConsoleUser() objectForKey:@"homeDirectory"];
    if(nil == userHomeDirectory)
    {
        //try another way
        userHomeDirectory = NSHomeDirectory();
    }

    //expand
    userLaunchAgentPlist = launchAgentPlist(userHomeDirectory);
    
    //ensure that current user is in list of destination paths
    if(YES != [destinationPaths containsObject:userLaunchAgentPlist])
    {
        //need to alloc?
        if(nil == destinationPaths)
        {
            //alloc
            destinationPaths = [NSMutableArray array];
        }
        
        //add
        [destinationPaths addObject:userLaunchAgentPlist];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"configuring plist for launch agent(s): %@", destinationPaths]);
    
    //update label
    launchItemPlist[@"Label"] = LAUNCH_AGENT_LABEL;
    
    //set program arg to agent
    launchItemPlist[@"ProgramArguments"][1] = ACTION_RUN_AGENT;
    
    //write out (updated/config'd) launch agent plist(s) to for all users that had it installed
    for(NSString* launchAgentPlist in destinationPaths)
    {
        //init directory for launch agent
        launchAgentDirectory = [launchAgentPlist stringByDeletingLastPathComponent];
        
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:launchAgentDirectory withIntermediateDirectories:YES attributes:nil error:nil])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to create launch agent dir: %@", launchAgentDirectory]);
            
            //bail
            goto bail;
        }
        
        //get permissions of one directory up
        // -> ~/Library
        userDirAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[launchAgentDirectory stringByDeletingLastPathComponent] error:nil];
        
        //assuming required attributes were found
        // ->make sure newly created directory is owned by correct user
        if( (nil != userDirAttributes) &&
            (nil != userDirAttributes[@"NSFileGroupOwnerAccountID"]) &&
            (nil != userDirAttributes[@"NSFileOwnerAccountID"]) )
        {
            //match newly created directory w/ user
            setFileOwner(launchAgentDirectory, userDirAttributes[@"NSFileGroupOwnerAccountID"], userDirAttributes[@"NSFileOwnerAccountID"], NO);
        }
        
        //save to disk
        if(YES != [launchItemPlist writeToFile:launchAgentPlist atomically:YES])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to save launch agent plist: %@", launchAgentPlist]);
        
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saving updated plist %@ to %@", launchItemPlist, launchAgentPlist]);
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
    
}

//install launch daemon
-(BOOL)installLaunchDaemon
{
    //return/status var
    BOOL bRet = NO;
    
    //launch item plist
    NSMutableDictionary* launchItemPlist = nil;
    
    //if lauch daemon already exists
    // ->cuz previous installer logic decided not to uninstall it, so no need to move
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonPlist()])
    {
        //load launch item plist
        launchItemPlist = [self loadLaunchItemPlist];
        
        //update first arg (path to binary) to location of installed app
        launchItemPlist[@"ProgramArguments"][0] = [NSString pathWithComponents:@[[INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME], BINARY_SUB_PATH]];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"configuring plist for launch daemon");
        
        //update label
        launchItemPlist[@"Label"] = LAUNCH_DAEMON_LABEL;

        //set program arg to daemon
        launchItemPlist[@"ProgramArguments"][1] = ACTION_RUN_DAEMON;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saving updated plist %@ to %@", launchItemPlist, launchDaemonPlist()]);
            
        //save (updated/config'd) plist to launch item directory
        if(YES != [launchItemPlist writeToFile:launchDaemonPlist() atomically:YES])
        {
            //err msg
            logMsg(LOG_ERR, @"ERROR: failed to save launch item plist");
            
            //bail
            goto bail;
        }
        
        //set group/owner to root/wheel
        setFileOwner(launchDaemonPlist(), @0, @0, NO);
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//install kext
// ->copy kext (bundle) to /Library/Extensions and set permissions
-(BOOL)installKext
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //move kext into /Libary/Extensions
    // ->orginally stored in applications /Resource bundle
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:KEXT_NAME] toPath:kextPath() error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to copy kext into /Library/Extensions (%@)", error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied kext to %@", kextPath()]);
    
    //always set group/owner to root/wheel
    setFileOwner(kextPath(), @0, @0, YES);
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//load the template launch item plist
-(NSMutableDictionary*)loadLaunchItemPlist
{
    //source path to launch agent plist
    NSString* sourcePath = nil;
        
    //launch item plist
    NSMutableDictionary* launchItemPlist = nil;
        
    //get path to launch item plist
    sourcePath = [[NSBundle mainBundle] pathForResource:@"launchItem" ofType:@"plist"];
    if(nil == sourcePath)
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to find launch item plist");
        
        //bail
        goto bail;
    }
    
    //load plist into memory
    launchItemPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:sourcePath];
    
    //check since loading might have failed
    if(nil == launchItemPlist)
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to load launch item plist");
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return launchItemPlist;
}

@end
