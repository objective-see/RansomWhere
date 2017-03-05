//
//  Enumerator.m
//  Daemon
//
//  Created by Patrick Wardle on 5/22/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Binary.h"
#import "Logging.h"
#import "Utilities.h"
#import "Enumerator.h"

@implementation Enumerator

@synthesize binaryList;
@synthesize bins2Process;
@synthesize processingComplete;

//init with app path
// ->locate/load/decode receipt, etc
-(instancetype)init
{
    //init
    if(self = [super init])
    {
        //alloc global dictionary for binaries to process
        bins2Process = [NSMutableDictionary dictionary];
        
        //alloc global dictionary for binary list
        binaryList = [NSMutableDictionary dictionary];
        
        //init flag off
        self.processingComplete = NO;
    }
    
    return self;
}

//enumerate all baselined/approved/running binaries
// ->adds/classfies them into bins2Process dictionary
-(void)enumerateBinaries
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"enumerating all 'baselined' applications");
    #endif
    
    //create binary objects for all baselined app
    // ->first time; generate list from OS (this might take a while)
    if(YES != [self enumBaselinedApps])
    {
        //err msg
        // ->but don't bail
        logMsg(LOG_ERR, @"failed to enumerate/process baselined apps");
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"enumerating all 'user-approved' applications");
    #endif
    
    //create binary objects for all (persistent) user-approved binaries
    if(YES != [self enumApprovedBins])
    {
        //err msg
        // ->but don't bail
        logMsg(LOG_ERR, @"failed to enumerate/process user-approved apps");
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"enumerating all running processes");
    #endif
    
    //create binary objects for all currently running processes
    if(YES != [self enumRunningProcs])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to enumerate running processing");
    }
    
    return;
}

//generate binary object for all enumerated bins
// ->this is slow and CPU intensive, so invoked as a thread method
-(void)processBinaries
{
    //binary object
    Binary* binary = nil;
    
    //lower priority
    // 0.0 is the lowest
    [NSThread setThreadPriority:0.0];
    
    //process running binaries first
    // ->ideally will mean less binary 'misses' in FS monitor
    for(NSString* binaryPath in self.bins2Process[KEY_RUNNING_BINARY])
    {
        //sync
        @synchronized(self.binaryList)
        {
            //check if already created
            // ->FS monitor might have already processed (new) binary
            if(nil != self.binaryList[binaryPath])
            {
                //skip
                continue;
            }
        }
        
        //init binary object
        // ->pass in nil for attributes to trigger lookup (approved/baseline) logic
        binary = [[Binary alloc] init:binaryPath attributes:nil];
        
        //nap to reduce CPU warnings/usage
        [NSThread sleepForTimeInterval:0.25];
        
        //sync
        @synchronized(self.binaryList)
        {
            //add to global list
            // ->path is key; object is value
            self.binaryList[binary.path] = binary;
        }
        
    }//running processes
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"done processing running binaries");
    #endif
    
    //enumerate all keys
    // ->process baselined/approved keys
    for(NSString* key in self.bins2Process)
    {
        //skip running apps
        // ->already processed (above)
        if(YES == [key isEqualToString:KEY_RUNNING_BINARY])
        {
            //skip
            continue;
        }
        
        //generate binary objects for enumerated binaries
        for(NSString* binaryPath in self.bins2Process[key])
        {
            //sync
            @synchronized (self.binaryList)
            {
                //check if already created
                // ->FS monitor might have already processed (new) binary
                if(nil != self.binaryList[binaryPath])
                {
                    //skip
                    continue;
                }
            }
            
            //init binary object
            // ->key passes in attributes (KEY_BASELINED_BINARY, etc)
            binary = [[Binary alloc] init:binaryPath attributes:@{key:[NSNumber numberWithBool:YES]}];
            
            //nap to reduce CPU warnings/usage
            [NSThread sleepForTimeInterval:1.0];
            
            //sync
            @synchronized (self.binaryList)
            {
                //add to global list
                // ->path is key; object is value
                self.binaryList[binary.path] = binary;
            }
            
        }// all binaries
        
    }//all keys

    //set flag
    self.processingComplete = YES;
    
    //priority++
    setpriority(PRIO_PROCESS, getpid(), PRIO_MIN+1);
    
    //io policy++
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"done processing all enumerated binaries (set flag)");
    #endif
    
    return;
}

//load list of apps installed at time of baseline
// ->first time; generate them (this might take a while)
-(BOOL)enumBaselinedApps
{
    //flag
    BOOL wereProcessed = NO;
    
    //list of installed apps
    NSMutableArray* installedApps = nil;
    
    //path to prev. saved list of installed apps
    NSString* installedAppsFile = nil;
    
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"enumerated %lu installed applications", (unsigned long)installedApps.count]);
    #endif
    
    //save
    self.bins2Process[KEY_BASELINED_BINARY] = [NSSet setWithArray:installedApps];

    //happy
    wereProcessed = YES;
    
//bail
bail:
    
    return wereProcessed;
}

//load all (persistent) 'user-approved' binaries
-(BOOL)enumApprovedBins
{
    //flag
    BOOL wereProcessed = NO;
    
    //file for user approved bins
    NSString* approvedBinsFile = nil;
    
    //approved binaries
    NSArray* approvedBinaries = nil;
    
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
    approvedBinaries = [NSArray arrayWithContentsOfFile:approvedBinsFile];
    if(nil == approvedBinaries)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loaded user approved binaries from %@", approvedBinsFile]);
        
        //bail
        goto bail;
    }
    
    //save
    self.bins2Process[KEY_APPROVED_BINARY] = [NSSet setWithArray:approvedBinaries];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded list of user-approved binaries from %@", approvedBinsFile]);
    #endif
    
    //happy
    wereProcessed = YES;
    
//bail
bail:
    
    return wereProcessed;
}


/*
//enumerate all currently running processes
-(BOOL)enumRunningProcs
{
    //flag
    BOOL wereProcessed = NO;
    
    //running processes
    NSMutableArray* runningProcesses = nil;
    
    //process path
    NSString* processPath = nil;
    
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
    
    //init entry for running apps
    self.bins2Process[KEY_RUNNING_BINARY] = [NSMutableSet set];
    
    //iterate over all running processes
    // ->get path and save into list of binaries to process
    for(NSNumber* processID in runningProcesses)
    {
        //get process path from pid
        processPath = getProcessPath(processID.unsignedIntValue);
        if(nil == processPath)
        {
            //skip
            continue;
        }
    
        //save into list for binares to process
        [self.bins2Process[KEY_RUNNING_BINARY] addObject:processPath];
    }
    
    //happy
    wereProcessed = YES;
    
//bail
bail:
    
    return wereProcessed;
}

*/
 
@end
