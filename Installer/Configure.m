//
//  Configure.m
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Logging.h"
#import "Consts.h"
#import "Configure.h"
#import "Utilities.h"

@implementation Configure

//determine if installed
// ->looks for daemon's plist or destination folder
-(BOOL)isInstalled
{
    //flag
    BOOL installed = NO;
    
    //info dictionary
    NSMutableDictionary* daemonInfo = nil;
    
    //get info about daemon's paths
    daemonInfo = [self daemonInfo];
    
    //check if daemon's plist or destination folder (which will contain daemon) exists
    if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_PLIST_KEY]]) ||
        (YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_FOLDER]]) )
    {
        //set flag
        installed = YES;
    }

    return installed;
}

//build info dictionary about daemon paths
// ->its source and destination paths for itself and its plist
-(NSMutableDictionary*)daemonInfo
{
    //dictionary
    NSMutableDictionary* paths = nil;
    
    //alloc
    paths = [NSMutableDictionary dictionary];
    
    //set daemon dest folder
    // ->done for completeness of dictionary
    paths[DAEMON_DEST_FOLDER] = DAEMON_DEST_FOLDER;
    
    //set daemon src path
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_PATH_KEY] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DAEMON_NAME];
    
    //set daemon dest path
    // ->'/Library/RansomWhere/' + daemon name
    paths[DAEMON_DEST_PATH_KEY] = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:DAEMON_NAME];
    
    //set daemon src plist
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_PLIST_KEY] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DAEMON_PLIST];
    
    //set daemon dest plist
    // ->'/Library/LauchDaemons' + daemon plist
    paths[DAEMON_DEST_PLIST_KEY] = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:DAEMON_PLIST];
    
    //set daemon icon src path
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_ICON_KEY] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:ICON_NAME];
    
    //set daemon icon dest path
    // ->'/Library/RansomWhere/' + icon name
    paths[DAEMON_DEST_ICON_KEY] = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:ICON_NAME];
    
    return paths;
}

//perform install || uninstall logic
-(BOOL)configure:(NSUInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;
    
    //make real id r00t
    if(-1 == setuid(0))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"setuid(0) in controlLaunchItem() failed with %d", errno]);
        
        //bail
        goto bail;
    }
    
    //install & start daemon
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");
        
        //install daemon (and start)
        if(YES != [self install])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"installed & started daemon");
    }
    //uninstall & stop daemon
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalling...");
        
        //uninstall (and stop)
        if(YES != [self uninstall])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalled & stopped daemon");
    }

    //no errors
    wasConfigured = YES;
    
//bail
bail:
    
    return wasConfigured;
}



//install daemon
// a) copy plist to /Library/LauchDaemons
// b) copy daemon binary /Library/RansomWhere
// c) start it
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;
    
    //info dictionary
    NSMutableDictionary* daemonInfo = nil;
    
    //error
    NSError* error = nil;
    
    //get info about daemon's paths
    daemonInfo = [self daemonInfo];
    
    //check if daemon's installation directory needs to be created
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_FOLDER]])
    {
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:daemonInfo[DAEMON_DEST_FOLDER] withIntermediateDirectories:YES attributes:nil error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create daemon's directory %@ (%@)", daemonInfo[DAEMON_DEST_FOLDER], error]);
            
            //bail
            goto bail;
        }
        
        //set group/owner to root/wheel
        if(YES != setFileOwner(daemonInfo[DAEMON_DEST_FOLDER], @0, @0, YES))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set daemon's directory %@ to be owned by root", daemonInfo[DAEMON_DEST_FOLDER]]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created %@", daemonInfo[DAEMON_DEST_FOLDER]]);
    }
    
    //move daemon binary into persistent location
    // ->'/Library/RansomWhere/' + daemon name
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_PATH_KEY] toPath:daemonInfo[DAEMON_DEST_PATH_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy daemon into %@ (%@)", DAEMON_DEST_PATH_KEY, error]);
        
        //bail
        goto bail;
    }
    
    //move icon for user alert into persistent location
    // ->'/Library/RansomWhere/' + icon name
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_ICON_KEY] toPath:daemonInfo[DAEMON_DEST_ICON_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy user alert icon into %@ (%@)", daemonInfo[DAEMON_DEST_ICON_KEY], error]);
        
        //bail
        goto bail;
    }
    
    //set group/owner to root/wheel
    if(YES != setFileOwner(daemonInfo[DAEMON_DEST_ICON_KEY], @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set daemon %@ to be owned by root", daemonInfo[DAEMON_DEST_ICON_KEY]]);
        
        //bail
        goto bail;
    }


    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", daemonInfo[DAEMON_SRC_PATH_KEY], daemonInfo[DAEMON_DEST_PATH_KEY]]);

    //set group/owner to root/wheel
    if(YES != setFileOwner(daemonInfo[DAEMON_DEST_PATH_KEY], @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set daemon %@ to be owned by root", daemonInfo[DAEMON_DEST_PATH_KEY]]);
        
        //bail
        goto bail;
    }
    
    //move daemon plist into /Libary/LauchDaemons
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_PLIST_KEY] toPath:daemonInfo[DAEMON_DEST_PLIST_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy daemon's plist into %@ (%@)", DAEMON_DEST_PLIST_KEY, error]);
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", daemonInfo[DAEMON_SRC_PLIST_KEY], daemonInfo[DAEMON_DEST_PLIST_KEY]]);
    
    //set group/owner to root/wheel
    if(YES != setFileOwner(daemonInfo[DAEMON_DEST_PLIST_KEY], @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set daemon's plist %@ to be owned by root", daemonInfo[DAEMON_DEST_PLIST_KEY]]);
        
        //bail
        goto bail;
    }
    
    //start daemon
    if(YES != [self controlLaunchItem:DAEMON_LOAD plist:daemonInfo[DAEMON_DEST_PLIST_KEY]])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start daemon");
        
        //bail
        goto bail;
    }
    
    //no errors
    wasInstalled = YES;
    
//bail
bail:
    
    return wasInstalled;
}

//uninstall daemon
// a) stop it
// b) delete plist from to /Library/LauchDaemons
// c) delete daemon binary & folder; /Library/RansomWhere
-(BOOL)uninstall
{
    //return/status var
    BOOL wasUninstalled = NO;
    
    //status var
    // ->since want to try all uninstall steps, but record if any fail
    BOOL bAnyErrors = NO;
    
    //info dictionary
    NSMutableDictionary* daemonInfo = nil;
    
    //error
    NSError* error = nil;
    
    //get info about daemon's paths
    daemonInfo = [self daemonInfo];
    
    //stop daemom
    if(YES != [self controlLaunchItem:DAEMON_UNLOAD plist:daemonInfo[DAEMON_DEST_PLIST_KEY]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to stop daemon"]);
        
        //set flag
        bAnyErrors = YES;
        
        //keep uninstalling...
    }
    
    //delete plist
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:daemonInfo[DAEMON_DEST_PLIST_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete daemon plist %@ (%@)", daemonInfo[DAEMON_DEST_PLIST_KEY], error]);
        
        //set flag
        bAnyErrors = YES;
        
        //keep uninstalling...
    }
    
    //delete daemon's folder
    // ->include's binary and anything else
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:daemonInfo[DAEMON_DEST_FOLDER] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete daemon's folder %@ (%@)", daemonInfo[DAEMON_DEST_FOLDER], error]);
        
        //set flag
        bAnyErrors = YES;
        
        //keep uninstalling...
    }
    
    //only success when there were no errors
    if(YES != bAnyErrors)
    {
        //happy
        wasUninstalled = YES;
    }

    return wasUninstalled;
}


//load or unload the launch daemon via '/bin/launchctl'
-(BOOL)controlLaunchItem:(NSUInteger)action plist:(NSString*)plist
{
    //return var
    BOOL bRet = NO;
    
    //status
    NSUInteger status = -1;
    
    //action string
    // ->passed to launchctl
    NSString* actionString = nil;
    
    //set action string: load
    if(ACTION_INSTALL_FLAG == action)
    {
        //load
        actionString = @"load";
    }
    //set action string: unload
    else
    {
        //unload
        actionString = @"unload";
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking %@ with %@ %@ ", LAUNCHCTL, actionString, plist]);

    //control launch item
    // ->and check
    status = execTask(LAUNCHCTL, @[actionString, plist]);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"%@'ing failed with %lu", actionString, (unsigned long)status]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}


@end

