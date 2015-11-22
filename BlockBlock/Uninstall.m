//
//  Install.m
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Consts.h"
#import "Utilities.h"
#import "Install.h"
#import "Uninstall.h"
#import "Logging.h"


/* manually:
 sudo kextunload -b com.objective-see.kext.BlockBlock
 sudo rm -rf /Library/Extensions/BlockBlock.kext
 sudo launchctl unload /Library/LaunchDaemons/com.objectiveSee.blockblock.plist
 sudo rm -rf /Library/LaunchDaemons/com.objectiveSee.blockblock.plist
 launchctl unload ~/Library/LaunchAgents/com.objectiveSee.blockblock.plist
 rm -rf ~/Library/LaunchAgents/com.objectiveSee.blockblock.plist
 sudo rm -rf /Applications/BlockBlock.app
 sudo killall BlockBlock
 
 */


@implementation Uninstall

@synthesize controlObj;

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
-(BOOL)uninstall
{
    //return var
    BOOL bRet = NO;
    
    //status var
    // ->since want to try all uninstall steps, but record if any fail
    BOOL bAnyErrors = NO;
    
    //error
    NSError* error = nil;
    
    //install object
    // ->needed since we need to know if we should do a full/partial uninstall
    Install* installObj = nil;
    
    //list of installed users
    NSMutableArray* installedUsers = nil;
    
    //current user
    NSString* currentUserDirectory = nil;
    
    //upgrade flag
    BOOL isAnUpgrade = NO;
    
    //installed state
    NSUInteger installedState = INSTALL_STATE_NONE;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"beginning uninstall (as r00t)");
    
    //alloc uninstall obj
    installObj = [[Install alloc] init];
    
    //check if its installed for other users
    installedUsers = [installObj allInstalledUsers];
    
    //check if its an upgrade
    isAnUpgrade = [installObj isUpgrade];
    
    //get install state
    installedState = [installObj installState];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"install state: %lu", (unsigned long)installedState]);
    
    //get current user
    currentUserDirectory = [getCurrentConsoleUser() objectForKey:@"homeDirectory"];
    
    //sanity check
    if(nil == currentUserDirectory)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find current user's home directory"]);
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"INFO: installed users:%@ upgrade? %d/ home: %@ / %@ / %@", installedUsers, isAnUpgrade, NSHomeDirectory(), getCurrentConsoleUser(), currentUserDirectory]);
    
    //check for full uninstall
    // ->nobody else has it installed, or doing an upgrade
    if( ( (0x1 == [installedUsers count]) && ([installedUsers.firstObject isEqualToString:currentUserDirectory]) ) ||
        (YES == isAnUpgrade) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing FULL uninstall");
        
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
                logMsg(LOG_ERR, @"ERROR: failed to uninstall kext");
                
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
                logMsg(LOG_ERR, @"ERROR: failed to uninstall launch daemon");
                
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
        
        //full uninstall
        // ->uninstall all launch agents
        if(YES != [self uninstallLaunchAgent:installedUsers])
        {
            //set flag
            bAnyErrors = YES;
            
            //err msg
            logMsg(LOG_ERR, @"ERROR: failed to uninstall launch agent(s)");
            
            //don't bail
            // ->might as well keep on uninstalling other components
        }
        
        //if app binary is present
        // ->just delete it
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:APPLICATION_PATH])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found: %@", APPLICATION_PATH]);
            
            //delete it
            if(YES != [[NSFileManager defaultManager] removeItemAtPath:APPLICATION_PATH error:&error])
            {
                //set flag
                bAnyErrors = YES;
                
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to delete application (%@)", error]);
                
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"deleted application");
        }

    }//full uninstall
    
    //fully installed, but there aren't other users
    // ->just unload/remove current user's launch agent
    else if(INSTALL_STATE_FULL == installedState)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing PARTIAL uninstall logic");
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"uninstalling %@", launchAgentPlist(currentUserDirectory)]);
        
        //if launch agent's plist is present
        // ->stop, then delete it
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:launchAgentPlist(currentUserDirectory)])
        {
            //uninstall launch agent
            if(YES != [self uninstallLaunchAgent:@[currentUserDirectory]])
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
    
    //only success when there were no errors
    if(YES != bAnyErrors)
    {
        //happy
        bRet = YES;
    }

//bail
bail:
    
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
        logMsg(LOG_ERR, @"ERROR: failed to stop launch daemon");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped launch daemon");
    
    //delete launch daemon's plist
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:launchDaemonPlist() error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to delete launch daemon's plist (%@)", error]);
        
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

//stop and remove launch agent
-(BOOL)uninstallLaunchAgent:(NSArray*)installedUsers;
{
    //return/status var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //unload Launch Agent for all users who've got it installed
    for(NSString* user in installedUsers)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found: %@", launchAgentPlist(user)]);
        
        //dbg msg
        logMsg(LOG_DEBUG, @"will attempt to stop agent");
        
        //stop launch agent
        if(YES != [controlObj stopAgent:launchAgentPlist(user)])
        {
            //err msg
            logMsg(LOG_ERR, @"ERROR: failed to stop launch agent");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"stopped launch agent");
        
        //delete launch agent's plist
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:launchAgentPlist(user) error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to delete launch agent's plist (%@)", error]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted launch agent's plist (%@)", launchAgentPlist(user)]);
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
        logMsg(LOG_ERR, @"ERROR: failed to stop kext");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"stopped kext");
    
    //delete kext
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to delete kext (%@)", error]);
        
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


@end