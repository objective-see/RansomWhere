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
#import "Utilities.h"
#import "ProcessMonitor.h"
#import "FileSystemMonitor.h"
#import "3rdParty/ent/ent.h"


//sudo chown -R root:wheel  /Users/patrick/objective-see/tbd/DerivedData/tbd/Build/Products/Debug/tbd
//sudo chmod 4755 /Users/patrick/objective-see/tbd/DerivedData/tbd/Build/Products/Debug/tbd

//global process list
NSMutableDictionary* processList = nil;

//TODO: don't need entropy? (pi is enough?)
//TODO: make 'save'd' files persistent!
//TODO: allow all existing installed apps?
//TODO: don't need pid?

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
        
        //priority++
        setpriority(PRIO_PROCESS, getpid(), PRIO_MIN+1);
        
        //io policy++
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        
        //init proc list
        initProcessList();
        
        //start file system monitoring
        [NSThread detachNewThreadSelector:@selector(monitor) toTarget:[[FileSystemMonitor alloc] init] withObject:nil];
        
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
