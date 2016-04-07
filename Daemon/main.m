//
//  main.m
//  RansomWhere
//
//  Created by Patrick Wardle on 3/20/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#import "main.h"
#import "Queue.h"
#import "Consts.h"
#import "Logging.h"
#import "Process.h"
#import "Exception.h"
#import "Utilities.h"
#import "ProcessMonitor.h"
#import "FSMonitor.h"
#import "3rdParty/ent/ent.h"


//sudo chown -R root:wheel  /Users/patrick/objective-see/tbd/DerivedData/tbd/Build/Products/Debug/tbd
//sudo chmod 4755 /Users/patrick/objective-see/tbd/DerivedData/tbd/Build/Products/Debug/tbd

//global list of installed apps
NSMutableSet* installedApps = nil;

//global list of running processes
NSMutableDictionary* processList = nil;

//global list of user approved binaries
NSMutableSet* userApprovedBins = nil;

//TODO: don't need entropy? (pi is enough?)
//TODO: don't need pid?

//TODO: allow apps from app store
//      see: https://github.com/ole/NSBundle-OBCodeSigningInfo/blob/master/NSBundle%2BOBCodeSigningInfo.m & https://github.com/rmaddy/VerifyStoreReceiptiOS
//      though looks like not trivial to do...

//main interface
// ->init some procs, kick off file-system watcher, then just runloop()
int main(int argc, const char * argv[])
{
    //pool
    @autoreleasepool
    {
        //isEncrypted([NSString stringWithUTF8String:argv[1]]);
        //return 0;
        
        //sanity check
        // ->gotta be r00t
        if(0 != geteuid())
        {
            //err msg
            logMsg(LOG_ERR, @"must run as r00t");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"daemon instance");
        
        //first thing...
        // ->install exception handlers
        installExceptionHandlers();
        
        //priority++
        setpriority(PRIO_PROCESS, getpid(), PRIO_MIN+1);
        
        //io policy++
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        
        //load list of apps installed installed at baseline
        // ->first time; generate them (this might take a while)
        initInstalledApps();
        
        //init list of user approved binaries
        // ->loads from disk, into global variable
        initApprovedBins();
        
        //init proc list
        // ->enumerates running processes to generate process objs
        initProcessList();
        
        //msg
        // ->always print
        syslog(LOG_ERR, "OBJECTIVE-SEE RANSOMWHERE: completed initializations; monitoring engaged!\n");
        
        //start file system monitoring
        [NSThread detachNewThreadSelector:@selector(monitor) toTarget:[[FSMonitor alloc] init] withObject:nil];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"started file system monitor");
        
        //run
        CFRunLoopRun();
    }
    
//bail
bail:
    
    //dbg msg
    // ->shouldn't exit unless manually unloaded, etc
    logMsg(LOG_DEBUG, @"exiting");
    
    return 0;
}

//load list of apps installed installed at baseline
// ->first time; generate them (this might take a while)
void initInstalledApps()
{
    //path to prev. saved list of installed apps
    NSString* installedAppsFile = nil;
    
    //enumerated apps
    // ->array of detailed app dictionaries
    NSMutableArray* enumeratedApps = nil;
    
    //app bundle path
    NSString* appBundlePath = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //app path
    NSString* appPath = nil;
    
    //alloc global set for installed apps
    installedApps = [NSMutableSet set];
    
    //init path to save list of installed apps
    installedAppsFile = [[NSProcessInfo.processInfo.arguments[0] stringByDeletingLastPathComponent] stringByAppendingPathComponent:INSTALLED_APPS];
    
    //enumerate apps if necessary
    // ->note: this is will be slow!
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:installedAppsFile])
    {
        //enumerate
        enumeratedApps = enumerateInstalledApps();
        if(nil == enumeratedApps)
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"enumerated all installed applications");
        
        //process all enumerated apps
        // ->extract app path and load bundle to get full path
        for(NSDictionary* enumeratedApp in enumeratedApps)
        {
            //grab path to app's bundle
            appBundlePath = [enumeratedApp objectForKey:@"path"];
            if(nil == appBundlePath)
            {
                //skip
                continue;
            }
            
            //load app bundle
            appBundle = [NSBundle bundleWithPath:appBundlePath];
            if(nil == appBundle)
            {
                //skip
                continue;
            }
            
            //grab full path to app's binary
            appPath = appBundle.executablePath;
            if(nil == appPath)
            {
                //skip
                continue;
            }
            
            //save
            [installedApps addObject:appPath];
        }
       
        //save to disk
        if(YES != writeSetToFile(installedApps, installedAppsFile))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save installed apps to %@", installedAppsFile]);
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"saved list of installed apps to %@", installedAppsFile]);
    }
    
    //already enumerated
    // ->load them from disk into memory
    else
    {
        //load
        installedApps = readSetFromFile(installedAppsFile);
        if(nil == installedApps)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to load installed apps from %@", installedAppsFile]);
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded list of installed apps from %@", installedAppsFile]);
    }
    
//bail
bail:
    
    return;
}

//init list of user approved binaries
// ->loads from disk, into global variable
void initApprovedBins()
{
    //file for user approved bins
    NSString* approvedBinsFile = nil;
    
    //alloc global set
    userApprovedBins = [NSMutableSet set];
    
    //init path for where to save user approved binaries
    approvedBinsFile = [[NSProcessInfo.processInfo.arguments[0] stringByDeletingLastPathComponent] stringByAppendingPathComponent:USER_APPROVED_BINARIES];
    
    //bail if file doesn't exist yet
    // ->for example, first time daemon is run
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:approvedBinsFile])
    {
        //bail
        goto bail;
    }
    
    //load from disk
    userApprovedBins = readSetFromFile(approvedBinsFile);
    if(nil == userApprovedBins)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loaded user approved binaries from %@", approvedBinsFile]);
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded list of user approved binaries from %@", approvedBinsFile]);
        
//bail
bail:
    
    return;
}


//init process list
// ->make process objects of all currently running processes
void initProcessList()
{
    //process object
    Process* process = nil;
    
    //alloc global dictionary for process list
    processList = [NSMutableDictionary dictionary];
    
    //iterate over all running processes
    // ->create process obj & save into global list
    for(NSNumber* processID in enumerateProcesses())
    {
        //create new process obj
        process = [[Process alloc] initWithPid:processID.unsignedIntValue infoDictionary:nil];
        if(nil == process)
        {
            //skip
            continue;
        }
        
        //add to path:proc
        processList[process.path] = process;
    }
    
    return;
}
