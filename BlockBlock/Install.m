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
    NSMutableArray* launchAgents = nil;
    
    //destination path to binary
    NSString* destBinaryPath = nil;
    
    //init destination path for binary
    destBinaryPath = [INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME];

    //check if already installed for anybody
    // ->if so, uninstall to get a clean slate!
    if(INSTALL_STATE_NONE != [Install installedState])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"already installed (will uninstall)");
        
        //alloc uninstall obj
        uninstallObj = [[Uninstall alloc] init];
        
        //launch agent can be installed for other users
        // ->grab existing launch agent paths *before* uninstalling
        launchAgents = [Install existingLaunchAgents];
    
        //uninstall
        // ->pass in 'YES' to say invoked via installer
        [uninstallObj uninstall:YES];
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
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create install directory (%@)", INSTALL_DIRECTORY]);
        
        //bail
        goto bail;
    }
    
    //install binary
    if(YES != [self installBinary:destBinaryPath])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to install binary (%@)", destBinaryPath]);
        
        //bail
        goto bail;
    }
    
    //install as launch agent
    // ->copy launch item plist file into current and other (prev installed) ~/Library/LaunchAgents
    if(YES != [self installLaunchAgent:launchAgents])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to install launch agent(s)");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"installed launch agent(s)");
    
    //install as launch daemon
    // ->just copy launch item plist file into /Library/LaunchDaemon directory
    if(YES != [self installLaunchDaemon])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to install launch agent");
        
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
        logMsg(LOG_ERR, @"failed to install kext");
        
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

//get install state
// ->a) not installed at all
//   b) installed for just user
//   c) installed for other user(s)
+(NSUInteger)installedState
{
    //status
    NSUInteger state = INSTALL_STATE_NONE;
    
    //home directory
    NSString* userHomeDirectory = nil;
    
    //(all) installed launch agents
    NSMutableArray* existingLaunchAgents;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"checking installed state");
    
    //get all installed launch agents
    existingLaunchAgents = [Install existingLaunchAgents];
    
    //grab home directory of current user
    userHomeDirectory = [getCurrentConsoleUser() objectForKey:@"homeDirectory"];
    if(nil == userHomeDirectory)
    {
        //try another way
        userHomeDirectory = NSHomeDirectory();
    }
    
    //CHECK 1:
    // ->check for kext to see if its installed at all
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:kextPath()])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"not installed for anybody");
        
        //set
        state = INSTALL_STATE_NONE;
        
        //all set
        goto bail;
    }
    
    //CHECK 2:
    // ->check if only installed for current user
    if( (1 == existingLaunchAgents.count) &&
        (YES == [[[existingLaunchAgents firstObject] objectForKey:@"plist"] isEqualToString:launchAgentPlist(userHomeDirectory)]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"only installed for self");
        
        //set
        state = INSTALL_STATE_SELF_ONLY;
        
        //all set
        goto bail;
    }
    
    //check if installed for self and others
    for(NSDictionary* existingLaunchAgent in existingLaunchAgents)
    {
        //self included?
        if(YES == [[existingLaunchAgent objectForKey:@"plist"] isEqualToString:launchAgentPlist(userHomeDirectory)])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"installed for self and others");
            
            //set
            state = INSTALL_STATE_SELF_AND_OTHERS;
            
            //all set
            goto bail;
        }
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"only installed for others");
    
    //if we get here
    // ->means it's just installed for others!
    state = INSTALL_STATE_OTHERS_ONLY;
    
//bail
bail:
    
    return state;
}

//launch agent can be installed for other users
// ->so iterate over all users and save any existing launch agent paths
+(NSMutableArray*)existingLaunchAgents
{
    //array of all installed launch agents
    NSMutableArray* existingLaunchAgents = nil;
    
    //user home directories
    NSArray* userHomeDirectories = nil;
    
    //user's id
    NSString* userID = nil;
    
    //alloc
    existingLaunchAgents = [NSMutableArray array];
    
    //check all users
    // ->do any have the launch agent installed?
    for(ODRecord* userRecord in getUsers())
    {
        //get uid
        userID = [[userRecord valuesForAttribute:kODAttributeTypeUniqueID error:NULL] firstObject];
        if(nil == userID)
        {
            //skip
            continue;
        }
        
        //extract home dirs
        userHomeDirectories = [userRecord valuesForAttribute:kODAttributeTypeNFSHomeDirectory error:NULL];
        if(0 == [userHomeDirectories count])
        {
            //skip
            continue;
        }
        
        //get path to where launch agent plist would be
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:launchAgentPlist([userHomeDirectories firstObject])])
        {
            //skip
            continue;
        }
        
        //add to list
        [existingLaunchAgents addObject:@{@"uid":[NSNumber numberWithInt:[userID intValue]], @"plist":launchAgentPlist([userHomeDirectories firstObject])}];
    }
    
    return existingLaunchAgents;
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
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy self (bundle) into %@ (%@)", path, error]);
        
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
-(BOOL)installLaunchAgent:(NSMutableArray*)prevInstalledAgents
{
    //return/status var
    BOOL bRet = NO;
    
    //flag
    BOOL includesCurrentUser = NO;

    //launch item dir
    NSString* launchAgentDirectory = nil;
    
    //array of launch agent (plists)
    NSMutableArray* installedLaunchAgents = nil;
    
    //launch item plist
    NSMutableDictionary* launchItemPlist = nil;
    
    //console user
    NSDictionary* consoleUser = nil;
    
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
    
    //get console user
    consoleUser = getCurrentConsoleUser();
    
    //grab home directory of current user
    userHomeDirectory = consoleUser[@"homeDirectory"];
    if(nil == userHomeDirectory)
    {
        //try another way
        userHomeDirectory = NSHomeDirectory();
    }

    //expand
    userLaunchAgentPlist = launchAgentPlist(userHomeDirectory);
    
    //check if current user is in prev installed launch agents
    // ->if not, need to add since we want to install it obvisouly for self (too)
    for(NSDictionary* prevInstalledAgents in prevInstalledAgents)
    {
        //check
        if(YES == [prevInstalledAgents[@"plist"] isEqualToString:userLaunchAgentPlist])
        {
            //exits
            includesCurrentUser = YES;
            
            //can stop searching
            break;
        }
    }
    
    //need to add current user to list?
    if(YES != includesCurrentUser)
    {
        //need to alloc?
        if(nil == prevInstalledAgents)
        {
            //alloc
            prevInstalledAgents = [NSMutableArray array];
        }
        
        //add
        [prevInstalledAgents addObject:@{@"uid":consoleUser[@"uid"], @"plist":userLaunchAgentPlist}];

    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"configuring plist for launch agent(s): %@", prevInstalledAgents]);
    
    //update label
    launchItemPlist[@"Label"] = LAUNCH_AGENT_LABEL;
    
    //set program arg to agent
    launchItemPlist[@"ProgramArguments"][1] = ACTION_RUN_AGENT;
    
    //write out (updated/config'd) launch agent plist(s) to for all users that had it installed
    for(NSDictionary* launchAgent in prevInstalledAgents)
    {
        //init directory for launch agent
        launchAgentDirectory = [launchAgent[@"plist"] stringByDeletingLastPathComponent];
        
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:launchAgentDirectory withIntermediateDirectories:YES attributes:nil error:nil])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create launch agent dir: %@", launchAgentDirectory]);
            
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
        if(YES != [launchItemPlist writeToFile:launchAgent[@"plist"] atomically:YES])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save launch agent plist: %@", launchAgent[@"plist"]]);
        
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saving updated plist %@ to %@", launchItemPlist, launchAgent[@"plist"]]);
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
            logMsg(LOG_ERR, @"failed to save launch item plist");
            
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
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy kext into /Library/Extensions (%@)", error]);
        
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
        logMsg(LOG_ERR, @"failed to find launch item plist");
        
        //bail
        goto bail;
    }
    
    //load plist into memory
    launchItemPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:sourcePath];
    
    //check since loading might have failed
    if(nil == launchItemPlist)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to load launch item plist");
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return launchItemPlist;
}

@end
