//
//  Install.m
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <OpenDirectory/OpenDirectory.h>


#import "Consts.h"
#import "Install.h"
#import "Utilities.h"
#import "Uninstall.h"
#import "Logging.h"


@implementation Install

@synthesize shouldStartDaemon;
//@synthesize installerStatus;
@synthesize installedLaunchAgents;


//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc
        installedLaunchAgents = [NSMutableArray array];
    }
    
    return self;
}


//install!
-(BOOL)install
{
    //return/status var
    BOOL bRet = NO;
    
    //installed state
    NSUInteger installStatus = INSTALL_STATE_NONE;
    
    //uninstaller obj
    Uninstall* uninstallObj = nil;
    
    //list of installed users
    NSMutableArray* installedUsers = nil;
    
    //upgrade flag
    BOOL isAnUpgrade = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"checking if already installed");
    
    //alloc uninstall obj
    uninstallObj = [[Uninstall alloc] init];
    
    //get install state
    installStatus = [self installState];
    
    //check if already installed
    // ->if so, uninstall to get a clean slate!
    if(INSTALL_STATE_NONE != installStatus)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"...already installed (state: %lu)", (unsigned long)installStatus]);
        
        //check if its installed for other users
        installedUsers = [self allInstalledUsers];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"installed users?: %@", installedUsers]);
        
        //check if its an upgrade
        isAnUpgrade = [self isUpgrade];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"is upgrade?: %d", isAnUpgrade]);
        
        //full uninstall
        // ->don't care about error (still want to try install)
        [uninstallObj uninstall];
    }
    
    //nothing installed
    // ->just dbg msg
    else
    {
        logMsg(LOG_DEBUG, @"not installed (so no need to uninstall anything)");
    }
    
    //if its already there
    // ->its cuz previous installer logic decided not to uninstall it, so no need to move
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:APPLICATION_PATH])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"application not found, installing %@ to %@", [NSBundle mainBundle].bundlePath, APPLICATION_PATH]);

        //move self into /Applications folder
        if(YES != [self moveIntoApplications])
        {
            //err msg
            logMsg(LOG_ERR, @"ERROR: failed to move self into /Applications");
            
            //set error
            //self.installerStatus = INSTALLER_STATUS_MOVE_FAILED;
            
            //bail
            goto bail;
        }
        
        //set group/owner to root/wheel
        setFileOwner(APPLICATION_PATH, @0, @0, YES);
    
    }
    //install as launch agent
    // ->copy launch item plist file(s) into ~/Library/LaunchAgent directory(s)
    if(YES != [self installLaunchAgent:installedUsers isUpgrade:isAnUpgrade])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to install launch agent(s)");
        
        //set error
        //self.installerStatus = INSTALLER_STATUS_LAUNCH_DAEMON_FAILED;
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"installed launch agent component(s)");
    
    //if launch daemon already/still exists
    // ->cuz previous installer logic decided not to uninstall it (same version/other users)
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonPlist()])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"launch daemon not found, installing....");
        
        //install as launch daemon
        // ->just copy launch item plist file into /Library/LaunchDaemon directory
        if(YES != [self installLaunchDaemon])
        {
            //err msg
            logMsg(LOG_ERR, @"ERROR: failed to install launch agent");
            
            //set error
            //self.installerStatus = INSTALLER_STATUS_LAUNCH_AGENT_FAILED;
            
            //bail
            goto bail;
        }
    }
        
    //dbg msg
    logMsg(LOG_DEBUG, @"installed launch daemon component");
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//check if install is to a newer version
-(BOOL)isUpgrade
{
    //flag
    BOOL bUpgrade = NO;
    
    NSString* installedVersion = nil;
    
    //get installed version
    installedVersion = getVersion(VERSION_INSTANCE_INSTALLED);
    
    //check if version that about to be installed
    // is greater than installed version
    if(nil != installedVersion)
    {
        //do version check
        if(YES == [getVersion(VERSION_INSTANCE_SELF) isGreaterThan:getVersion(VERSION_INSTANCE_INSTALLED)])
        {
            //upgrade
            bUpgrade = YES;
        }
    }
    
    
    return bUpgrade;
}

//check if this was installed for other user
-(NSMutableArray*)allInstalledUsers
{
    //installed users
    NSMutableArray* users = nil;
    
    //user home directories
    NSArray* userHomeDirectories = nil;
    
    //user home dir
    NSString* userHomeDirectory = nil;
    
    //alloc
    users = [NSMutableArray array];
    
    //check all users
    // ->do any have the launch agent installed?
    for(ODRecord* userRecord in getUsers())
    {
        //extract home dirs
        userHomeDirectories = [userRecord valuesForAttribute:kODAttributeTypeNFSHomeDirectory error:NULL];
        
        //check if there is a home dir
        if(0 == [userHomeDirectories count])
        {
            //skip
            continue;
        }
        
        //extract
        userHomeDirectory = [userHomeDirectories firstObject];
        
        //another user install?
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchAgentPlist(userHomeDirectory)])
        {
            //save
            [users addObject:userHomeDirectory];
        }
    }
    
    return users;
}


//move (self) into /Applications directory
-(BOOL)moveIntoApplications
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //move self into /Applications
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:[NSBundle mainBundle].bundlePath toPath:APPLICATION_PATH error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to copy self (bundle) into /Applications (%@)", error]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
    
}

//install launch agent
-(BOOL)installLaunchAgent:(NSMutableArray*)installedUsers isUpgrade:(BOOL)isAnUpgrade
{
    //return/status var
    BOOL bRet = NO;

    //launch item dir
    NSString* launchAgentDirectory = nil;
    
    //launch item plist
    NSMutableDictionary* launchItemPlist = nil;
    
    //load launch item plist
    launchItemPlist = [self loadLaunchItemPlist];
    
    //update first arg (path to binary) to location of installed app
    launchItemPlist[@"ProgramArguments"][0] = [NSString pathWithComponents:@[APPLICATION_PATH, BINARY_SUB_PATH]];
    
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current user: %@", getCurrentConsoleUser()]);
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current ~: %@", [@"~" stringByExpandingTildeInPath]]);
    
    //always install for self
    //[self.installedLaunchAgents addObject:launchAgentPlist(NSHomeDirectory())];
    
    //when upgrading
    // ->will replace all launch agents (since upgrading daemon/core)
    if(YES == isAnUpgrade)
    {
        //add users who have prev installed
        for(NSString* user in installedUsers)
        {
            //save
            [self.installedLaunchAgents addObject:launchAgentPlist(user)];
        }
    }
    else
    {
        //just add self
        [self.installedLaunchAgents addObject:launchAgentPlist(NSHomeDirectory())];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"configuring plist for launch agent(s)");
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user info: %@/home dir: %@", getCurrentConsoleUser(), NSHomeDirectory()]);
    
    //update label
    launchItemPlist[@"Label"] = LAUNCH_AGENT_LABEL;
    
    //set program arg to agent
    launchItemPlist[@"ProgramArguments"][1] = ACTION_RUN_AGENT;
    
    //write out (updated/config'd) plist to all launch agent directory(s)
    for(NSString* launchAgentPlist in self.installedLaunchAgents)
    {
        //init dir
        launchAgentDirectory = [launchAgentPlist stringByDeletingLastPathComponent];
        
        //check if dir exists
        // ->might not, e.g. on a new user/clean install
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:launchAgentDirectory])
        {
            //create it
            if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:launchAgentDirectory withIntermediateDirectories:YES attributes:nil error:nil])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to create launch agent dir: %@", launchAgentDirectory]);
                
                //bail
                goto bail;
            }
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
        
        //don't set owner to r00t
        // ->since agent stores stuff in it's plist, and i don't think there are any security issues
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
        launchItemPlist[@"ProgramArguments"][0] = [NSString pathWithComponents:@[APPLICATION_PATH, BINARY_SUB_PATH]];
        
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
        
        //set flag
        self.shouldStartDaemon = YES;
    }
    
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

//check if (any component of) BlockBlock is installed
// ->rets install state; none, partial, or full
-(NSUInteger)installState
{
    //return var
    NSUInteger installedState = INSTALL_STATE_NONE;
    
    //current user directory
    NSString* currentUserDirectory = nil;
    
    //get current user dir
    currentUserDirectory = [getCurrentConsoleUser() objectForKey:@"homeDirectory"];
    
    //sanity check
    if(nil == currentUserDirectory)
    {
        //user current user...might be r00t?
        currentUserDirectory = NSHomeDirectory();
    }
    
    //check for launch daemon
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonPlist()])
    {
        //set flag
        installedState = INSTALL_STATE_PARTIAL;
    }
    
    //check for app
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:APPLICATION_PATH])
    {
        //set flag
        installedState = INSTALL_STATE_PARTIAL;
    }
    
    //check for current user's launch agent
    // ->this implies a full install
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchAgentPlist(currentUserDirectory)])
    {
        //set flag
        installedState = INSTALL_STATE_FULL;
    }
    
    return installedState;
}

@end