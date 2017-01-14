//
//  Install.m
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Consts.h"
#import "Control.h"
#import "Install.h"
#import "Utilities.h"
#import "Uninstall.h"
#import "Logging.h"

@implementation Control

@synthesize authPID;

//spawn (self) as r00t
-(BOOL)spawnAuthInstance:(NSString*)parameter;
{
    //return/status var
    BOOL bRet = NO;
    
    //authorization ref
    AuthorizationRef authorizatioRef = {0};
    
    //flag indicating auth ref was created
    BOOL authRefCreated = NO;
    
    //args
    const char* installArgs[0x2] = {0};
    
    //status code
    OSStatus osStatus = -1;
    
    //comms pipe
    FILE* commsPipe = NULL;
    
    //init args
    // ->install flag
    installArgs[0] = [parameter UTF8String];
    
    //init args
    // ->gotta end it in NULL
    installArgs[1] = NULL;
    
    //create authorization ref
    // ->and check
    osStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizatioRef);
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"AuthorizationCreate() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //set flag indicating auth ref was created
    authRefCreated = YES;
    
    //spawn self as r00t w/ install flag (will ask user for password)
    // ->and check
    osStatus = AuthorizationExecuteWithPrivileges(authorizatioRef, [[NSBundle mainBundle].executablePath UTF8String], 0, (char* const*)installArgs, &commsPipe);
    
    //check
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"AuthorizationExecuteWithPrivileges() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //get pid
    // ->child will write its PID to the comms pipe
    fread(&authPID, sizeof(self.authPID), 0x1, commsPipe);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got pid from (auth'd) child: %d", self.authPID]);
    #endif
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    //free auth ref
    if(YES == authRefCreated)
    {
        //free
        AuthorizationFree(authorizatioRef, kAuthorizationFlagDefaults);
    }
    
    return bRet;
}

//wait till the instance of the (auth'd) self exists
-(BOOL)waitTillPau
{
    //return/status var
    BOOL bRet = NO;
    
    //state of child process
    int childState = 0;
    
    //pid returned by waitpid
    pid_t returnedPID = -1;
    
    //installer result
    int installerResult = -1;
    
    //wait until (auth'd) self is pau
    // and check
    returnedPID = waitpid(self.authPID, &childState, 0);
    if(returnedPID <= 0)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"waitpid() failed with %d/%d", returnedPID, errno]);
        
        //bail
        goto bail;
    }
    
    //save exit status
    // ->normal exit
    if(0 != WIFEXITED(childState))
    {
        //save
        installerResult = WEXITSTATUS(childState);
    }
    
    //save exit status
    // ->signal exit
    else if(WIFSIGNALED(childState))
    {
        //save
        installerResult = WTERMSIG(childState);
    }
    
    //sanity check
    if(STATUS_SUCCESS != installerResult)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"installer, (child) failed with %d", installerResult]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//spawns auth'd instance of installer/uninstaller
// ->then wait till it exits
-(BOOL)execControlInstance:(NSString*)parameter
{
    //return var
    BOOL bRet = NO;
    
    //spawn self as r00t to perform priv'd action(s)
    // ->failure here is cuz of an auth error (as opposed to an action error)
    if(YES != [self spawnAuthInstance:parameter])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to spawn elevated self to perform install");
        
        //bail
        goto bail;
    }
    
    //while still in user's session
    // ->reset all prefs
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:[NSDictionary dictionary] forName:[[NSBundle mainBundle] bundleIdentifier]];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"removed app/user's preferences");
    #endif
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"auth'd %@ (%d) spawned OK, will wait...", parameter, self.authPID]);
    #endif
    
    //wait till (auth'd) installer complete
    if(YES != [self waitTillPau])
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"auth'd %@ exited OK", parameter]);
    #endif

    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//control a launch item
// ->either load/unload the launch daemon/agent via '/bin/launchctl'
-(BOOL)controlLaunchItem:(NSUInteger)itemType plist:(NSString*)plist uid:(NSNumber*)uid action:(NSString*)action
{
    //return var
    BOOL bRet = NO;
    
    //status
    NSUInteger status = -1;
    
    //current uid
    uid_t currentUID = 0;

    //parameter array
    NSMutableArray* parameters = nil;
    
    //init pararm array
    parameters = [NSMutableArray array];
    
    //save current euid
    currentUID = getuid();
    
    //init launch item's plist
    // ->daemon
    if(LAUNCH_ITEM_DAEMON == itemType)
    {
        //add action as first arg
        [parameters addObject:action];
        
        //add launch daemon plist as second arg
        [parameters addObject:plist];
        
        //make real id r00t
        if(-1 == setuid(0))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"setuid(0) in controlLaunchItem() failed with %d", errno]);
            
            //bail
            goto bail;
        }
    }
    //init launch item's plist
    // ->agent
    else
    {
        //make real id r00t
        if(-1 == setuid(0))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"setuid(0) in controlLaunchItem() failed with %d", errno]);
            
            //bail
            goto bail;
        }
        
        //add 'asuser' as first arg
        [parameters addObject:@"asuser"];
        
        //add console uid as second arg
        [parameters addObject:[NSString stringWithFormat:@"%d", [uid intValue]]];
        
        //add path to launchctl (again) as third arg
        [parameters addObject:LAUNCHCTL];
        
        //add action as fourth arg
        [parameters addObject:action];
        
        //arg 5
        // ->path to launch agent plist
        [parameters addObject:plist];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current UID: %d", currentUID]);
        #endif
    }

    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"performing %@", parameters]);
    #endif
    
    //control launch item
    // ->and check
    status = execTask(LAUNCHCTL, parameters, YES);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"%@'ing failed with %lu", action, (unsigned long)status]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    //restore real id
    if(currentUID != getuid())
    {
        //restore
        setreuid(currentUID, -1);
    }
    
    return bRet;
}

//start kext
// ->'kextload' <kext path>
-(BOOL)startKext
{
    //return var
    BOOL bRet = NO;
    
    //status
    NSUInteger status = -1;
    
    //parameter array
    NSMutableArray* parameters = nil;
    
    //init pararm array
    parameters = [NSMutableArray array];
    
    //add kext path as first (and only) arg
    [parameters addObject:kextPath()];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting kext with %@", parameters]);
    #endif

    //load kext
    status = execTask(KEXT_LOAD, parameters, YES);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"starting kext failed with %lu", (unsigned long)status]);
        
        //bail
        goto bail;
    }

    //happy
    bRet = YES;

//bail
bail:

    return bRet;
}

//stop kext
// ->'kextunload' -b <kext path>
-(BOOL)stopKext
{
    //return var
    BOOL bRet = NO;
    
    //status
    NSUInteger status = -1;
    
    //parameter array
    NSMutableArray* parameters = nil;
    
    //init pararm array
    parameters = [NSMutableArray array];
    
    //add -b as first arg
    [parameters addObject:@"-b"];
    
    //add kext bundle id/label as second arg
    [parameters addObject:KEXT_LABEL];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"stopping kext with %@", parameters]);
    #endif
    
    //unload kext
    status = execTask(KEXT_UNLOAD, parameters, YES);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"stopping kext failed with %lu", (unsigned long)status]);
        
        //bail
        goto bail;
    }
    
    //happy
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}


//start the launch daemon
-(BOOL)startDaemon
{
    //load launch daemon
    return [self controlLaunchItem:LAUNCH_ITEM_DAEMON plist:launchDaemonPlist() uid:nil action:@"load"];
}

//start the launch agent(s)
-(BOOL)startAgent:(NSString*)plist uid:(NSNumber*)uid
{
    //load launch agent(s)
    return [self controlLaunchItem:LAUNCH_ITEM_AGENT plist:plist uid:uid action:@"load"];
}

//stop the launch daemon
-(BOOL)stopDaemon
{
    //unload launch daemon
    return [self controlLaunchItem:LAUNCH_ITEM_DAEMON plist:launchDaemonPlist() uid:nil action:@"unload"];
}

//stop the launch agent
-(BOOL)stopAgent:(NSString*)plist uid:(NSNumber*)uid
{
    //unload launch agent
    return [self controlLaunchItem:LAUNCH_ITEM_AGENT plist:plist uid:uid action:@"unload"];
}


@end

