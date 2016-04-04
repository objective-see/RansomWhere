//
//  main.m
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//
#import "Logging.h"

#import <syslog.h>
#import <Cocoa/Cocoa.h>



/* METHODS DECLARATIONS */

//spawn self as root
BOOL spawnAsRoot(char* path2Self);

/*CODE */

//main
// ->spawn self as r00t
int main(int argc, char *argv[])
{
    //return var
    int retVar = -1;
    
    //check for r00t
    // ->then spawn self via auth exec
    if(0 != geteuid())
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"non-root installer instance");
        
        //spawn as root
        if(YES != spawnAsRoot(argv[0]))
        {
            //err msg
            logMsg(LOG_ERR, @"failed to spawn self as r00t");
            
            //bail
            goto bail;
        }
        
        //happy
        retVar = 0;
    }
    
    //otherwise
    // ->just kick off app, as we're root now
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"root installer instance");
        
        //app away
        retVar = NSApplicationMain(argc, (const char **)argv);
    }
    
//bail
bail:
    
    return retVar;
}


//spawn self as root
BOOL spawnAsRoot(char* path2Self)
{
    //return/status var
    BOOL bRet = NO;
    
    //authorization ref
    AuthorizationRef authorizatioRef = {0};
    
    //args
    char *args[] = {NULL};
    
    //flag creation of ref
    BOOL authRefCreated = NO;
    
    //status code
    OSStatus osStatus = -1;
    
    //create authorization ref
    // ->and check
    osStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizatioRef);
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE RANSOMWHERE ERROR: AuthorizationCreate() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //set flag indicating auth ref was created
    authRefCreated = YES;
    
    //spawn self as r00t w/ install flag (will ask user for password)
    // ->and check
    osStatus = AuthorizationExecuteWithPrivileges(authorizatioRef, path2Self, 0, args, NULL);
    
    //check
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE RANSOMWHERE ERROR: AuthorizationExecuteWithPrivileges() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
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
