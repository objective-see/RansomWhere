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

//TODO: update website with new directory

/* manually:
 sudo kextunload -b com.objectiveSee.kext.BlockBlock
 sudo rm -rf /Library/Extensions/BlockBlock.kext
 sudo launchctl unload /Library/LaunchDaemons/com.objectiveSee.blockblock.plist
 sudo rm -rf /Library/LaunchDaemons/com.objectiveSee.blockblock.plist
 launchctl unload ~/Library/LaunchAgents/com.objectiveSee.blockblock.plist
 rm -rf ~/Library/LaunchAgents/com.objectiveSee.blockblock.plist
 sudo rm -rf /Applications/BlockBlock.app
 rm -rf ~/Library/Application Support/com.objectiveSee.BlockBlock
 sudo killall BlockBlock
 */


@implementation Uninstall

@synthesize controlObj;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init control object
        controlObj = [[Control alloc] init];
    }
    
    return self;
}

//uninstall
-(BOOL)uninstall:(BOOL)viaInstaller
{
    //return var
    BOOL bRet = NO;
    
    //status var
    // ->since want to try all uninstall steps, but record if any fail
    BOOL bAnyErrors = NO;
    
    //installed state
    NSUInteger installedState = INSTALL_STATE_NONE;
    
    //console user
    NSDictionary* consoleUser = nil;
    
    //home directory
    NSString* userHomeDirectory = nil;
    
    //list of installed launch agents
    // ->can be multiple ones if other users have installed
    NSMutableArray* launchAgents = nil;
    
    //destination path to binary
    NSString* appPath = nil;
    
    //error
    NSError* error = nil;

    //dbg msg
    logMsg(LOG_DEBUG, @"beginning uninstall (as r00t)");
    
    //alloc
    launchAgents = [NSMutableArray array];
    
    //get install state
    installedState = [Install installedState];
    
    //get installed launch agents
    launchAgents = [Install existingLaunchAgents];
    
    //full uninstall when current user is only one w/ it installed
    // or when invoked via installer, since want everybody on the same version
    if( (YES == viaInstaller) ||
        (INSTALL_STATE_SELF_ONLY == installedState) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing FULL uninstall");

        //init destination path of app
        appPath = [INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME];
        
        //when kext is present
        // ->stop, then delete it
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:kextPath()])
        {
            //uninstall
            if(YES != [self uninstallKext])
            {
                //set flag
                bAnyErrors = YES;
                
                //err msg
                logMsg(LOG_ERR, @"failed to uninstall kext");
                
                //don't bail
                // ->might as well keep on uninstalling other components
            }
            
            //just logic for dbg msg
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"fully uninstalled kext");
            }
        }
        
        //when launch daemon's plist is present
        // ->stop, then delete it
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonPlist()])
        {
            //uninstall launch daemon
            if(YES != [self uninstallLaunchDaemon])
            {
                //set flag
                bAnyErrors = YES;
                
                //err msg
                logMsg(LOG_ERR, @"failed to uninstall launch daemon");
                
                //don't bail
                // ->might as well keep on uninstalling other components
            }
            
            //just logic for dbg msg
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"fully uninstalled launch daemon");
            }
        }
        
        //uninstall launch agent(s)
        if(YES != [self uninstallLaunchAgent:launchAgents])
        {
            //set flag
            bAnyErrors = YES;
            
            //err msg
            logMsg(LOG_ERR, @"failed to uninstall launch agent(s)");
            
            //don't bail
            // ->might as well keep on uninstalling other components
        }
        //just logic for dbg msg
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"fully uninstalled launch agent");
        }
        
        //uninstall app
        // ->handle case for both old & new
        if(YES != [self uninstallApp])
        {
            //set flag
            bAnyErrors = YES;
            
            //err msg
            logMsg(LOG_ERR, @"failed to delete application (%@)");
            
            //don't bail
            // ->might as well keep on uninstalling other components
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"deleted application");
        
        //remove install directory
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:INSTALL_DIRECTORY])
        {
            //delete
            if(YES != [[NSFileManager defaultManager] removeItemAtPath:INSTALL_DIRECTORY error:&error])
            {
                //set flag
                bAnyErrors = YES;
                
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete install directory (%@)", error]);
            }
        }
        
    }//full uninstall
    
    //partial uninstall
    // ->just stop/remove launch agent for self
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing PARTIAL uninstall logic");
        
        //get console user
        consoleUser = getCurrentConsoleUser();
        
        //grab home directory of current user
        userHomeDirectory = consoleUser[@"homeDirectory"];
        if(nil == userHomeDirectory)
        {
            //try another way
            userHomeDirectory = NSHomeDirectory();
        }
        
        //if launch agent's plist is present
        // ->stop, then delete it
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchAgentPlist(userHomeDirectory)])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"uninstalling %@", launchAgentPlist(userHomeDirectory)]);
        
            //uninstall launch agent
            if(YES != [self uninstallLaunchAgent:@[@{@"uid":consoleUser[@"uid"], @"plist":launchAgentPlist(userHomeDirectory)}]])
            {
                //set flag
                bAnyErrors = YES;
                
                //err msg
                logMsg(LOG_ERR, @"ERROR: failed to uninstall launch agent");
                
                //don't bail
                // ->might as well keep on uninstalling other components
            }
            
            //just logic for dbg msg
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"fully uninstalled launch agent");
            }
        }
        
    }//partial uninstall
    
    //always delete app support dir
    // ->for now just has log file, etc
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:supportDirectory()])
    {
        //delete it
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:supportDirectory() error:nil])
        {
            //set flag
            bAnyErrors = YES;
            
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to remove app support (logging) directory, %@", supportDirectory()]);
            
            //don't bail
            // ->might as well keep on uninstalling other components
        }
        //just logic for dbg msg
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removed app's support directory, %@", supportDirectory()]);
        }
    }
    
//bail
bail:
    
    //only success when there were no errors
    if(YES != bAnyErrors)
    {
        //happy
        bRet = YES;
    }
    
    return bRet;
}

//stop and remove launch daemon
-(BOOL)uninstallLaunchDaemon
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found: %@", launchDaemonPlist()]);
        
    //dbg msg
    logMsg(LOG_DEBUG, @"will attempt to stop daemon");
    
    //stop launch daemon
    if(YES != [controlObj stopDaemon])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to stop launch daemon");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped launch daemon");
    
    //delete launch daemon's plist
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:launchDaemonPlist() error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete launch daemon's plist (%@)", error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted launch daemon's plist (%@)", launchDaemonPlist()]);
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//stop and remove launch agent(s)
-(BOOL)uninstallLaunchAgent:(NSArray*)installedLaunchAgents;
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //unload Launch Agent for all users who've got it installed
    for(NSDictionary* installedLaunchAgent in installedLaunchAgents)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"attempting to stop launch agent %@", installedLaunchAgent]);
        
        //stop launch agent
        if(YES != [controlObj stopAgent:installedLaunchAgent[@"plist"] uid:installedLaunchAgent[@"uid"]])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to stop launch agent");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"stopped launch agent");
        
        //delete launch agent's plist
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:installedLaunchAgent[@"plist"] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete launch agent's plist (%@)", error]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted launch agent's plist (%@)", installedLaunchAgent]);
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:

    return bRet;
}

//unload and remove kext
-(BOOL)uninstallKext
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //path to kext
    NSString* path = nil;
    
    //get kext's path
    path = kextPath();
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"uninstalling kext (%@)", path]);
    
    //stop (unload) kext
    if(YES != [controlObj stopKext])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to stop kext");
        
        //don't bail since still want to to try delete...
    }
    //stopped ok
    // ->just dbg msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"stopped kext");
    }
    
    //delete kext
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete kext (%@)", error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"deleted kext");
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//uninstall app
// ->checks location of both old and new
-(BOOL)uninstallApp
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //check old location
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[@"/Applications" stringByAppendingPathComponent:APPLICATION_NAME]])
    {
        //delete it
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:[@"/Applications" stringByAppendingPathComponent:APPLICATION_NAME] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete (old) application (%@)", error]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted application (%@)", [@"/Applications" stringByAppendingPathComponent:APPLICATION_NAME]]);
    }
    //check new location
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME]])
    {
        //delete it
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete application (%@)", error]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted application (%@)", [INSTALL_DIRECTORY stringByAppendingPathComponent:APPLICATION_NAME]]);
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

        


@end
