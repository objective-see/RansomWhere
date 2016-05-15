//
//  main.m
//  RansomWhere
//
//  Created by Patrick Wardle on 3/20/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <pthread.h>
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "main.h"
#import "Queue.h"
#import "Consts.h"
#import "Logging.h"
#import "Binary.h"
#import "Exception.h"
#import "Utilities.h"
#import "FSMonitor.h"
#import "3rdParty/ent/ent.h"

//global list of binary objects
// ->running/installed/user approved apps
NSMutableDictionary* binaryList = nil;

//global current user
CFStringRef consoleUserName = NULL;

//main interface
// ->init some procs, kick off file-system watcher, then just runloop()
int main(int argc, const char * argv[])
{
    //pool
    @autoreleasepool
    {
        //NSLog(@"%d", isEncrypted([NSString stringWithUTF8String:argv[1]]));
        //return 0;
        
        //update thread
        pthread_t updateThread = NULL;
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"daemon instance started!");
        #endif
        
        //sanity check
        // ->gotta be r00t
        if(0 != geteuid())
        {
            //err msg
            // ->syslog() & printf() since likely run from cmdline for this to happen?
            logMsg(LOG_ERR, @"must be run as r00t");
            printf("\nRANSOMWHERE ERROR: must be run as r00t\n\n");
            
            //bail
            goto bail;
        }
        
        //first thing...
        // ->install exception handlers
        installExceptionHandlers();
        
        //check OS version
        if(YES != isSupportedOS())
        {
            //err msg
            logMsg(LOG_ERR, @"unsupported OS (requires OS X 10.8+)");
            
            //bail
            goto bail;
        }
        
        //handle '-reset'
        // ->delete list of installed/approved apps, etc
        if( (2 == argc) &&
            (0 == strcmp(argv[1], RESET_FLAG)) )
        {
            //do it
            reset();
            
            //all pau
            goto bail;
        }
        
        //alloc global dictionary for binary list
        binaryList = [NSMutableDictionary dictionary];
        
        //init paths
        // ->this logic will only be needed if daemon is executed from non-standard location (i.e. debugger)
        if(YES != initPaths())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize paths");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"enumerating all installed applications, to baseline system");
        #endif
        
        //create binary objects for all baselined app
        // ->first time; generate list from OS (this might take a while)
        if(YES != processBaselinedApps())
        {
            //err msg
            // ->but don't bail
            logMsg(LOG_ERR, @"failed to enumerate/process baselined apps");
            
            //bail
            //goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"enumerating all 'user-approved' applications");
        #endif
        
        //create binary objects for all (persistent) user-approved binaries
        if(YES != processApprovedBins())
        {
            //err msg
            // ->but don't bail
            logMsg(LOG_ERR, @"failed to enumerate/process user-approved apps");
            
            //bail
            //goto bail;
        }
    
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"enumerating all running processes");
        #endif
        
        //create binary objects for all currently running processes
        if(YES != processRunningProcs())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to enumerate running processing");
            
            //bail
            goto bail;
        }
        
        //grab user name
        // ->also register callback for user changes
        if(YES != initUserName())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize callback for login/logout events");
            
            //bail
            goto bail;
        }
    
        //priority++
        setpriority(PRIO_PROCESS, getpid(), PRIO_MIN+1);
        
        //io policy++
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        
        //msg
        // ->always print
        syslog(LOG_ERR, "OBJECTIVE-SEE RANSOMWHERE?: completed initializations; monitoring engaged!\n");
        
        //start file system monitoring
        [NSThread detachNewThreadSelector:@selector(monitor) toTarget:[[FSMonitor alloc] init] withObject:nil];
        
        //start thread to handle update check
        pthread_create(&updateThread, NULL, checkForUpdate, NULL);
        
        //detatch
        // ->don't care about waiting for update thread to return
        pthread_detach(updateThread);
        
        //run
        CFRunLoopRun();
    
    }//pool
    
//bail
bail:
    
    //release user name
    if(NULL != consoleUserName)
    {
        //release
        CFRelease(consoleUserName);
        
        //unset
        consoleUserName = NULL;
    }

    //dbg msg
    // ->shouldn't exit unless manually unloaded, reset mode, etc
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"exiting");
    #endif
    
    return 0;
}

//delete list of installed/approved apps & restart daemon
// ->note: as invoked via cmdline, use printf()'s for output
BOOL reset()
{
    //flag
    BOOL fullReset = NO;
    
    //error
    NSError* error = nil;
    
    //status var
    // ->since want to keep trying
    BOOL bAnyErrors = NO;
    
    //path to prev. saved list of installed apps
    NSString* installedAppsFile = nil;
    
    //file for user approved bins
    NSString* approvedBinsFile = nil;
    
    //path to daemon's plist
    NSString* daemonPlist =  nil;
    
    //init path to save list of installed apps
    installedAppsFile = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:INSTALLED_APPS];
    
    //when found
    // ->delete list of installed apps
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:installedAppsFile])
    {
        //delete
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:installedAppsFile error:&error])
        {
            //set flag
            bAnyErrors = YES;
            
            //err msg
            printf("ERROR: failed to list of installed apps %s (%s)", installedAppsFile.UTF8String, error.description.UTF8String);
        }
    }
    
    //init path for where to save user approved binaries
    approvedBinsFile = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_BINARIES];
    
    //when found
    // ->delete list of 'user approved' apps
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:approvedBinsFile])
    {
        //delete
        if(YES != [[NSFileManager defaultManager] removeItemAtPath:approvedBinsFile error:&error])
        {
            //set flag
            bAnyErrors = YES;
            
            //err msg
            printf("ERROR: failed to list of approvedBinsFile apps %s (%s)\n", approvedBinsFile.UTF8String, error.description.UTF8String);
        }
    }
    
    //init daemon's plist
    daemonPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:DAEMON_PLIST];
    
    //stop daemom
    controlLaunchItem(DAEMON_UNLOAD, daemonPlist);
    
    //start daemon
    controlLaunchItem(DAEMON_LOAD, daemonPlist);
    
    //all good?
    if(YES != bAnyErrors)
    {
        //set flag
        fullReset = YES;
        
        //dbg msg(s)
        printf("\nRANSOMWHERE: reset\n");
        printf("\t      a) removed list of installed/approved binaries\n");
        printf("\t      b) stopped, then (re)started the launch daemon\n\n");
    }

    return fullReset;
}

//init paths
// ->this logic will only be needed if daemon is executed from non-standard location
BOOL initPaths()
{
    //flag
    BOOL pathsInitd = NO;
    
    //error
    NSError* error = nil;
    
    //check if daemon's installation directory needs to be created
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:DAEMON_DEST_FOLDER])
    {
        //create it
        if(YES != [[NSFileManager defaultManager] createDirectoryAtPath:DAEMON_DEST_FOLDER withIntermediateDirectories:YES attributes:nil error:&error])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create daemon's directory %@ (%@)", DAEMON_DEST_FOLDER, error]);
            
            //bail
            goto bail;
        }
        
        //set group/owner to root/wheel
        if(YES != setFileOwner(DAEMON_DEST_FOLDER, @0, @0, YES))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set daemon's directory %@ to be owned by root", DAEMON_DEST_FOLDER]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created %@", DAEMON_DEST_FOLDER]);
        #endif
    }
    
    //happy
    pathsInitd = YES;
    
//bail
bail:
    
    return pathsInitd;
}

//load list of apps installed at time of baseline
// ->first time; generate them (this might take a while)
BOOL processBaselinedApps()
{
    //flag
    BOOL wereProcessed = NO;
    
    //list of installed apps
    NSMutableArray* installedApps = nil;

    //path to prev. saved list of installed apps
    NSString* installedAppsFile = nil;
    
    //binary object
    Binary* binary = nil;
    
    //init path to save list of installed apps
    installedAppsFile = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:INSTALLED_APPS];
    
    //enumerate apps if necessary
    // ->done via system_profiler, w/ 'SPApplicationsDataType' flag (slow!)
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:installedAppsFile])
    {
        //enumerate
        installedApps = enumerateInstalledApps();
        if( (nil == installedApps) ||
            (0 == installedApps.count) )
        {
            //err msg
            logMsg(LOG_ERR, @"failed to enumerate installed apps");
            
            //bail
            goto bail;
        }
        
        //save to disk
        if(YES != [installedApps writeToFile:installedAppsFile atomically:NO])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save installed apps to %@", installedAppsFile]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saved list of installed apps to %@", installedAppsFile]);
        #endif
    }
    
    //already enumerated
    // ->load them from disk into memory
    else
    {
        //load
        installedApps = [NSMutableArray arrayWithContentsOfFile:installedAppsFile];
        if(nil == installedApps)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load installed apps from %@", installedAppsFile]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded list of installed apps from %@", installedAppsFile]);
        #endif
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing %lu installed applications", (unsigned long)installedApps.count]);
    #endif
    
    //iterate overall all installed apps
    // ->create binary objects for all, passing in 'baselined' flag
    for(NSString* appPath in installedApps)
    {
        //init binary object
        binary = [[Binary alloc] init:appPath attributes:@{@"baselined":[NSNumber numberWithBool:YES]}];
        
        //nap to reduce CPU warnings/usage
        [NSThread sleepForTimeInterval:0.05];
        
        //add to global list
        // ->path is key; object is value
        binaryList[binary.path] = binary;
    }
    
    //happy
    wereProcessed = YES;
    
//bail
bail:
    
    return wereProcessed;
}

//create binary objects for all (persistent) user-approved binaries
BOOL processApprovedBins()
{
    //flag
    BOOL wereProcessed = NO;
    
    //file for user approved bins
    NSString* approvedBinsFile = nil;
    
    //array for approved bins
    NSMutableArray* userApprovedBins = nil;
    
    //binary object
    Binary* binary = nil;
    
    //init path for where to save user approved binaries
    approvedBinsFile = [DAEMON_DEST_FOLDER stringByAppendingPathComponent:USER_APPROVED_BINARIES];
    
    //bail if file doesn't exist yet
    // ->for example, first time daemon is run
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:approvedBinsFile])
    {
        //not an error though!
        wereProcessed = YES;
        
        //bail
        goto bail;
    }
    
    //load from disk
    userApprovedBins = [NSMutableArray arrayWithContentsOfFile:approvedBinsFile];
    if(nil == userApprovedBins)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loaded user approved binaries from %@", approvedBinsFile]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded list of user approved binaries from %@", approvedBinsFile]);
    #endif
    
    //iterate overall all approved binaries
    // ->create binary objects for all, passing in 'approved' flag
    for(NSString* binaryPath in userApprovedBins)
    {
        //init binary object
        binary = [[Binary alloc] init:binaryPath attributes:@{@"approved":[NSNumber numberWithBool:YES]}];
        
        //add to global list
        // ->path is key; object is value
        binaryList[binary.path] = binary;
    }
    
    //happy
    wereProcessed = YES;
    
//bail
bail:
    
    return wereProcessed;
}

//create binary objects for all currently running processes
BOOL processRunningProcs()
{
    //flag
    BOOL wereProcessed = NO;
    
    //running processes
    NSMutableArray* runningProcesses = nil;
    
    //process path
    NSString* processPath = nil;
    
    //binary object
    Binary* binary = nil;
    
    //enumerate all running processes
    runningProcesses = enumerateProcesses();
    if( (nil == runningProcesses) ||
        (0 == runningProcesses.count) )
    {
        //err msg
        logMsg(LOG_ERR, @"failed to enumerate running processes");
        
        //bail
        goto bail;
    }
    
    //iterate over all running processes
    // ->create binary objs & save into global list
    for(NSNumber* processID in runningProcesses)
    {
        //get process path from pid
        processPath = getProcessPath(processID.unsignedIntValue);
        if(nil == processPath)
        {
            //skip
            continue;
        }
        
        //skip existing binary objects
        // ->since existings ones will be baselined/approved, so don't want to overwrite
        if(nil != binaryList[processPath])
        {
            //skip
            continue;
        }
        
        //init binary object
        binary = [[Binary alloc] init:processPath attributes:@{@"processID":processID}];
        if(nil == binary)
        {
            //skip
            continue;
        }
        
        //add to global list
        // ->path is key; object is value
        binaryList[binary.path] = binary;
        
        //nap to reduce CPU warnings/usage
        [NSThread sleepForTimeInterval:0.05];
    }
    
    //happy
    wereProcessed = YES;
    
//bail
bail:
    
    return wereProcessed;
}

//grab current user
// ->note: NULL is returned if none, or user is 'loginwindow'
static CFStringRef CopyCurrentConsoleUsername(SCDynamicStoreRef store)
{
    //result
    CFStringRef userName = NULL;
    
    //grab user
    userName = SCDynamicStoreCopyConsoleUser(store, NULL, NULL);
    
    //treat 'loginwindow' as no user
    if((NULL != userName) &&
       (CFEqual(userName, CFSTR("loginwindow"))) )
    {
        //release
        CFRelease(userName);
        
        //unset
        userName = NULL;
    }
    
    return userName;
}

//callback function that's invoked when user changes
// ->release old user name and safe new one into global
static void userChangedCallback(SCDynamicStoreRef store, CFArrayRef changedKeys, void * info)
{
    //release previous user
    if(NULL != consoleUserName)
    {
        //release
        CFRelease(consoleUserName);
        
        //unset
        consoleUserName = NULL;
    }
    
    //grab new one
    // ->might be NULL (user logged out), but that's ok
    consoleUserName = CopyCurrentConsoleUsername(store);
    
    //dbg msg(s)
    #ifdef DEBUG
    
    //user logged in
    if(NULL != consoleUserName)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current user name: %@", consoleUserName]);
    }
    
    //no logged in user
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no logged in user");
    }
    #endif
    
    return;
}

//get current user
// ->then, setup callback for changes
BOOL initUserName()
{
    //flag
    BOOL wasInitialize = NO;
    
    //store
    SCDynamicStoreRef store = NULL;
    
    //key
    CFStringRef key = NULL;
    
    //key array
    CFArrayRef keys = NULL;
    
    //runloop
    CFRunLoopSourceRef runloopSource = NULL;
    
    //grab current user
    consoleUserName = CopyCurrentConsoleUsername(store);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current user name: %@", consoleUserName]);
    #endif

    //create store for user change notifications
    store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), userChangedCallback, NULL);
    if(NULL == store)
    {
        //bail
        goto bail;
    }
    
    //create store key for user
    key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    if(NULL == key)
    {
        //bail
        goto bail;
    }
    
    //create array for callback
    keys = CFArrayCreate(NULL, (const void **)&key, 1, &kCFTypeArrayCallBacks);
    if(NULL == keys)
    {
        //bail
        goto bail;
    }
    
    //set callback
    if(TRUE != SCDynamicStoreSetNotificationKeys(store, keys, NULL))
    {
        //bail
        goto bail;
    }
    
    //create runloop souce
    runloopSource = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    if(NULL == runloopSource)
    {
        //bail
        goto bail;
    }
    
    //add callback to runloop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runloopSource, kCFRunLoopDefaultMode);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"registered for login in/out events");
    #endif
    
    //happy
    wasInitialize = YES;
    
//bail
bail:
    
    //release run loop source
    if(NULL != runloopSource)
    {
        //release
        CFRelease(runloopSource);
        
        //reset
        runloopSource = NULL;
    }
    
    return wasInitialize;
}

//check for update
// ->query website for json file w/ version info
void* checkForUpdate(void *threadParam)
{
    //version string
    NSMutableString* versionString = nil;
    
    //user's response
    CFOptionFlags response = 0;
    
    //header for alert
    CFStringRef title = NULL;
    
    //body for alert
    CFStringRef body = NULL;
    
    //pool
    @autoreleasepool
    {
    
    //alloc string
    versionString = [NSMutableString string];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"in 'check for update' thread");
    #endif
    
    //wait for user to login in
    do
    {
        //nap
        sleep(10);
    
    //user yet?
    }while(NULL == consoleUserName);
    
    //nap a bit more
    // ->just in case user is logging in
    sleep(10);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"user logged in, checking for version");
    #endif
    
    //ok got user
    // ->check if available version is newer
    // ->show update window
    if(YES != isNewVersion(versionString))
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"no updates available (or check failed)");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", versionString]);
    #endif
    
    //init title for alert
    title = (__bridge CFStringRef)([NSString stringWithFormat:@"a new version (%@) is available!", versionString]);
    
    //init body
    body = (__bridge CFStringRef)([NSString stringWithFormat:@"currently, you have version %@ installed", getDaemonVersion()]);
    
    //show alert
    // ->will block until user interaction, then response saved in 'response' variable
    CFUserNotificationDisplayAlert(0.0f, kCFUserNotificationStopAlertLevel, (CFURLRef)[NSURL URLWithString:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:ALERT_ICON]], NULL, NULL, title, body, (__bridge CFStringRef)@"Upgrade", (__bridge CFStringRef)@"Ignore", NULL, &response);
    
    //user selected 'Upgrade'
    // ->lazy, just open URL of product
    if(UPDATE_INSTALL == response)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"user selected 'upgrade' - launching browser");
        #endif
        
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    }
    //user selected 'Ignore'
    // ->just log this, but nothing else needed
    else
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"user selected 'ignore'");
        #endif
    }
    
//bail
bail:
        
    ;
    
    }//pool
        
    //bye-bye
    pthread_exit(NULL);
    
}
