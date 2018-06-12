//
//  Configure.m
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>


#import "Consts.h"
#import "Configure.h"
#import "Utilities.h"
#import "../Shared/Logging.h"

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
    
    //check if daemon's plist or destination folders (which will contain daemon) exists
    if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_PLIST_KEY]]) ||
        (YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_FOLDER_OLD]]) ||
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
    
    //set daemon's old location
    paths[DAEMON_DEST_FOLDER_OLD] = DAEMON_DEST_FOLDER_OLD;
    
    //set daemon src path
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_PATH_KEY] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DAEMON_NAME];

    //set daemon dest path
    // ->'/Library/Objective-See/RansomWhere/' + daemon name
    paths[DAEMON_DEST_PATH_KEY] = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:DAEMON_NAME];
    
    //set daemon src plist
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_PLIST_KEY] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DAEMON_PLIST];
    
    //set daemon dest plist
    // ->'/Library/LauchDaemons' + daemon plist
    paths[DAEMON_DEST_PLIST_KEY] = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:DAEMON_PLIST];
    
    //set daemon icon src path
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_ICON_KEY] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:ALERT_ICON];

    //set daemon icon dest path
    // ->'/Library/Objective-See/RansomWhere/' + icon name
    paths[DAEMON_DEST_ICON_KEY] = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:ALERT_ICON];
    
    //set daemon whitelist src path
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_WHITE_LIST] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:WHITE_LIST_FILE];
    
    //set daemon whitelist dest path
    // ->'/Library/Objective-See/RansomWhere/' + whitelist.plist
    paths[DAEMON_DEST_WHITE_LIST] = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:WHITE_LIST_FILE];
    
    //set daemon graylist src path
    // ->orginally stored in installer app's /Resource bundle
    paths[DAEMON_SRC_GRAY_LIST] = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:GRAY_LIST_FILE];
    
    //set daemon graylist dest path
    // ->'/Library/Objective-See/RansomWhere/' + graylist.plist
    paths[DAEMON_DEST_GRAY_LIST] = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:GRAY_LIST_FILE];
    
//bail
bail:
    
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"installing...");
        #endif
        
        //if already installed though
        // ->uninstall everything first, except user's pref
        if(YES == [self isInstalled])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"already installed, so partially uninstalling...");
            #endif
            
            //uninstall (and stop)
            if(YES != [self uninstall:PARTIAL_UNINSTALL])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"uninstalled & stopped daemon");
            #endif
        }
        
        //install daemon (and start)
        if(YES != [self install])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"installed & started daemon");
        #endif
    }
    //uninstall & stop daemon
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"uninstalling...");
        #endif
        
        //uninstall (and stop)
        // ->also delete user's prefs
        if(YES != [self uninstall:FULL_UNINSTALL])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"uninstalled & stopped daemon");
        #endif
    }

    //no errors
    wasConfigured = YES;
    
//bail
bail:
    
    return wasConfigured;
}



//install daemon
// a) copy plist to /Library/LauchDaemons
// b) copy daemon binary /Library/Objective-See/RansomWhere
// c) start it
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;
    
    //info dictionary
    NSMutableDictionary* daemonInfo = nil;
    
    //all files
    NSArray* files = nil;
    
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created %@", daemonInfo[DAEMON_DEST_FOLDER]]);
        #endif
    }
    
    //check that daemon was found in installer
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_SRC_PATH_KEY]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find %@", daemonInfo[DAEMON_SRC_PATH_KEY]]);
        
        //bail
        goto bail;
    }

    //move daemon binary into persistent location
    // ->'/Library/RansomWhere/Objective-See/' + daemon name
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_PATH_KEY] toPath:daemonInfo[DAEMON_DEST_PATH_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy daemon into %@ (%@)", daemonInfo[DAEMON_DEST_PATH_KEY], error]);
        
        //bail
        goto bail;
    }
    
    //check daemon plist was found in installer
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_SRC_PLIST_KEY]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find %@", daemonInfo[DAEMON_SRC_PLIST_KEY]]);
        
        //bail
        goto bail;
    }
    
    //move daemon plist into /Libary/LaunchDaemons
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_PLIST_KEY] toPath:daemonInfo[DAEMON_DEST_PLIST_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy daemon's plist into %@ (%@)", DAEMON_DEST_PLIST_KEY, error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", daemonInfo[DAEMON_SRC_PLIST_KEY], daemonInfo[DAEMON_DEST_PLIST_KEY]]);
    #endif
    
    //set plist's group/owner to root/wheel
    if(YES != setFileOwner(daemonInfo[DAEMON_DEST_PLIST_KEY], @0, @0, YES))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set %@, to be owned by root", daemonInfo[DAEMON_DEST_PLIST_KEY]]);
        
        //bail
        goto bail;
    }
    
    //set plist's permissions to rw-r-r
    // ->otherwise launchd will reject it
    if(YES != setFilePermissions(daemonInfo[DAEMON_DEST_PLIST_KEY], 0644))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set daemon's plist %@, to be 'rw-r-r'", daemonInfo[DAEMON_DEST_PLIST_KEY]]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"set daemon's plist %@, to be 'rw-r-r'", daemonInfo[DAEMON_DEST_PLIST_KEY]]);
    #endif
    
    //check daemon alert icon was found in installer
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_SRC_ICON_KEY]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find %@", daemonInfo[DAEMON_SRC_ICON_KEY]]);
        
        //bail
        goto bail;
    }

    //move icon for user alert into persistent location
    // ->'/Library/RansomWhere/Objective-See/' + icon name
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_ICON_KEY] toPath:daemonInfo[DAEMON_DEST_ICON_KEY] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy user alert icon into %@ (%@)", daemonInfo[DAEMON_DEST_ICON_KEY], error]);
        
        //bail
        goto bail;
    }

    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", daemonInfo[DAEMON_SRC_PATH_KEY], daemonInfo[DAEMON_DEST_PATH_KEY]]);
    #endif
    
    //check daemon whitelist was found in installer
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_SRC_WHITE_LIST]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find %@", daemonInfo[DAEMON_SRC_WHITE_LIST]]);
        
        //bail
        goto bail;
    }

    //copy over whitelist
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_WHITE_LIST] toPath:daemonInfo[DAEMON_DEST_WHITE_LIST] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy user whitelist %@ (%@)", daemonInfo[DAEMON_DEST_WHITE_LIST], error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", daemonInfo[DAEMON_SRC_WHITE_LIST], daemonInfo[DAEMON_DEST_WHITE_LIST]]);
    #endif
    
    //check daemon graylist was found in installer
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_SRC_GRAY_LIST]])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to find %@", daemonInfo[DAEMON_SRC_GRAY_LIST]]);
        
        //bail
        goto bail;
    }
    
    //copy over graylist
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:daemonInfo[DAEMON_SRC_GRAY_LIST] toPath:daemonInfo[DAEMON_DEST_GRAY_LIST] error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy user graylist %@ (%@)", daemonInfo[DAEMON_DEST_GRAY_LIST], error]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", daemonInfo[DAEMON_SRC_GRAY_LIST], daemonInfo[DAEMON_DEST_GRAY_LIST]]);
    #endif
    
    //get all files
    files = [[NSFileManager defaultManager] directoryContentsAtPath:daemonInfo[DAEMON_DEST_FOLDER]];
    
    //set em all to be owned as root
    for(NSString* file in files)
    {
        //set group/owner to root/wheel
        if(YES != setFileOwner([daemonInfo[DAEMON_DEST_FOLDER] stringByAppendingPathComponent:file], @0, @0, YES))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set %@, to be owned by root", [daemonInfo[DAEMON_DEST_FOLDER] stringByAppendingPathComponent:file]]);
            
            //bail
            goto bail;
        }
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
// c) delete daemon binary & folder; /Library/Objective-See/RansomWhere
-(BOOL)uninstall:(NSUInteger)type
{
    //return/status var
    BOOL wasUninstalled = NO;
    
    //status var
    // ->since want to try all uninstall steps, but record if any fail
    BOOL bAnyErrors = NO;
    
    //info dictionary
    NSMutableDictionary* daemonInfo = nil;
    
    //directory enumerator
    NSDirectoryEnumerator* fileEnumerator = nil;
    
    //error
    NSError* error = nil;
    
    //get info about daemon's paths
    daemonInfo = [self daemonInfo];
    
    //when daemon's plist exists
    // ->stop daemon and delete plist
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_PLIST_KEY]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %@, so will stop daemon & delete plist", DAEMON_DEST_PLIST_KEY]);
        #endif
        
        //stop daemon
        if(YES != [self controlLaunchItem:DAEMON_UNLOAD plist:daemonInfo[DAEMON_DEST_PLIST_KEY]])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to stop daemon");
            
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
    }
    
    //always try delete old folder
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_FOLDER_OLD]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %@, so will delete", DAEMON_DEST_FOLDER_OLD]);
        #endif
        
        //delete
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:daemonInfo[DAEMON_DEST_FOLDER_OLD] error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete daemon's (old) folder %@ (%@)", daemonInfo[DAEMON_DEST_FOLDER_OLD], error]);
            
            //set flag
            bAnyErrors = YES;
            
            //keep uninstalling...
        }
    }
    
    //when daemon's folder exists
    // ->delete it all (when not saving user prefs), or everything, but
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:daemonInfo[DAEMON_DEST_FOLDER]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found %@, so will delete", DAEMON_DEST_FOLDER]);
        #endif
        
        //delete entire folder & contents
        if(FULL_UNINSTALL == type)
        {
            //delete
            if(YES != [[NSFileManager defaultManager] removeItemAtPath:daemonInfo[DAEMON_DEST_FOLDER] error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete daemon's folder %@ (%@)", daemonInfo[DAEMON_DEST_FOLDER], error]);
                
                //set flag
                bAnyErrors = YES;
                
                //keep uninstalling...
            }
        }
        //otherwise delete everything but user prefs/baselined apps
        else
        {
            //init directory enumerator
            fileEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:daemonInfo[DAEMON_DEST_FOLDER]];
            
            //delete most
            for(NSString* file in fileEnumerator)
            {
                //skip user files
                if(YES == [file isEqualToString:USER_APPROVED_BINARIES])
                {
                    //skip
                    continue;
                }
                
                //skip pre-installed files list
                if(YES == [file isEqualToString:BASELINED_FILE])
                {
                    //skip
                    continue;
                }
                
                //delete file
                if(YES != [[NSFileManager defaultManager] removeItemAtPath:[daemonInfo[DAEMON_DEST_FOLDER] stringByAppendingPathComponent:file] error:&error])
                {
                    //err msg
                    logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete daemon's folder %@ (%@)", daemonInfo[DAEMON_DEST_FOLDER], error]);
                    
                    //set flag
                    bAnyErrors = YES;
                    
                    //keep uninstalling...
                }
                
            }//all files
        
        }//keep user files
    
    }//folder exists
    
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking %@ with %@ %@ ", LAUNCHCTL, actionString, plist]);
    #endif

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

