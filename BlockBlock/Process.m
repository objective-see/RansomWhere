//
//  Process.m
//  BlockBlock
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Process.h"
#import "Watcher.h"
#import "Utilities.h"
#import "Logging.h"
#import "AppDelegate.h"
#import "ProcessMonitor.h"


#import <libproc.h>


@implementation Process

@synthesize pid;
@synthesize uid;
@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize ppid;
@synthesize bundle;

//init w/ a pid
// note: icons are dynamically determined only when process is shown in alert
-(id)initWithPid:(pid_t)processID infoDictionary:(NSDictionary*)infoDictionary
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"INIT'ING process: %d/%@", processID, infoDictionary]);
        
        //since root UID is zero
        // ->init UID to -1
        self.uid = -1;
        
        //save pid
        self.pid = processID;
        
        //init parent id
        self.ppid = -1;
        
        //process uid
        if(nil != infoDictionary[@"uid"])
        {
            //save uid
            self.uid = [infoDictionary[@"uid"] intValue];
        }
        
        //process (binary) path
        if(nil != infoDictionary[@"path"])
        {
            //save path
            self.path = infoDictionary[@"path"];
        }
        
        //parent id
        if(nil != infoDictionary[@"ppid"])
        {
            //save ppid
            self.ppid = [infoDictionary[@"ppid"] intValue];
        }

        //process bundle
        // ->indirect load via binary path
        if(nil != self.path)
        {
            //try to get app's bundle from binary path
            // ->of course, will only succeed for apps
            self.bundle = findAppBundle(self.path);
        }
    
        //get a meaningful name
        // ->via non-nil bundles, path, etc.
        if(nil == self.name)
        {
            //resolve name
            [self determineName];
        }
        
        //when path still blank
        // ->try to determine it via non-nil bundles, name (via 'which'), etc
        if(nil == self.path)
        {
            //resolve path
            [self determinePath];
        }
        
        //uid still unknown?
        // ->try figure it out via syscall
        if(-1 == self.uid)
        {
            //resolve UID
            [self determineUID];
        }
    
    }//init self

    return self;
}

//try to determine name
// ->either from bundle or path's last component
-(void)determineName
{
    //try to get name from bundle
    // ->key 'CFBundleName'
    if(nil != self.bundle)
    {
        //extract name
        self.name = [self.bundle infoDictionary][@"CFBundleName"];
    }
    
    //no bundle/that failed
    // ->try from path, by grabbing last component
    if( (nil == self.name) &&
        (nil != self.path) )
    {
        //extract name
        self.name = [self.path lastPathComponent];
    }
    
    return;
}

//try to determine name
// ->either from bundle or via 'which'
-(void)determinePath
{
    logMsg(LOG_DEBUG, @"determining path");
    
    //try to get path from bundle
    if(nil != self.bundle)
    {
        logMsg(LOG_DEBUG, @"determining path from bundle");
        
        //extract path
        self.path = self.bundle.executablePath;
    }
    
    //try to get path from name
    // ->use 'which' helper function
    else if(nil != self.name)
    {
        logMsg(LOG_DEBUG, @"determining path from name");
        
        //resolve
        self.path = which(self.name);
    }

    return;
}


//get a process's UID
// ->save into 'uid' iVar
-(void)determineUID
{
    //kinfo_proc struct
    struct kinfo_proc processStruct = {0};
    
    //size
    size_t procBufferSize = sizeof(processStruct);
    
    //mib
    const u_int mibLength = 4;
    
    //syscall result
    int sysctlResult = -1;
    
    //global process list
    OrderedDictionary* processList = nil;
    
    //process (from dtrace or app callback)
    Process* processFromList = nil;
    
    //count var for loop
    NSUInteger count = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"looking up UID for %@/%d", self.name, self.pid]);
    
    //init mib
    int mib[mibLength] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, self.pid};
    
    //make syscall
    sysctlResult = sysctl(mib, mibLength, &processStruct, &procBufferSize, NULL, 0);
    
    //check if got uid
    if( (STATUS_SUCCESS == sysctlResult) &&
        (0 != procBufferSize) )
    {
        //save uid
        self.uid = processStruct.kp_eproc.e_ucred.cr_uid;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extracted UID for process: %d", self.uid]);
    }
    else
    {
        //dbg msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to extract UID for process: %d (%d/%zu)", self.pid, sysctlResult, procBufferSize]);
        
        //try (again) via global process list
        // ->really need UID to tell what session alert is for!
        
        //grab global process list
        processList = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList;
        
        //try see if process monitor(s) grabbed it too
        // ->they have more info, so preferred
        do
        {
            //always sync
            @synchronized(processList)
            {
                //try lookup/set process object from process monitor's list
                processFromList = [processList objectForKey:[NSNumber numberWithUnsignedInteger:self.pid]];
                
                //check if we got one
                if(nil != processFromList)
                {
                    //bail
                    break;
                }
            }
            
            //nap for 1/10th of a second
            [NSThread sleepForTimeInterval:WAIT_INTERVAL];
            
        //try up to a two seconds
        } while(count++ < 2.0/WAIT_INTERVAL);
        
        //try grab UID now
        if( (nil != processFromList) &&
            (-1 != processFromList.uid) )
        {
            //yay got a UID
            self.uid = processFromList.uid;
        }

    }//didn't find UID for syscall

    return;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"pid:%d ppid=%d name=%@ path=%@, bundle=%@", self.pid, self.ppid, self.name, self.path, self.bundle];
}

//get an icon for a process
// ->for apps, this will be app's icon, otherwise just a standard system one
-(NSImage*)getIconForProcess
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //system's document icon
    static NSData* documentIcon = nil;
    
    //for app's
    // ->extract their icon
    if(nil != self.bundle)
    {
        //get file
        iconFile = self.bundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [self.bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        self.icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //process is not an app or couldn't get icon
    // ->try to get it via shared workspace
    if( (nil == self.bundle) ||
        (nil == self.icon) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"getting icon for shared workspace: %@", self.path]);
        
        //extract icon
        self.icon = [[NSWorkspace sharedWorkspace] iconForFile:self.path];
        
        //load system document icon
        // ->static var, so only load once
        if(nil == documentIcon)
        {
            //load
            documentIcon = [[[NSWorkspace sharedWorkspace] iconForFileType:
                             NSFileTypeForHFSTypeCode(kGenericDocumentIcon)] TIFFRepresentation];
        }
        
        //if 'iconForFile' method doesn't find and icon, it returns the system 'document' icon
        // ->the system 'applicaiton' icon seems more applicable, so use that here...
        if(YES == [[self.icon TIFFRepresentation] isEqual:documentIcon])
        {
            //set icon to system 'applicaiton' icon
            self.icon = [[NSWorkspace sharedWorkspace]
                      iconForFileType: NSFileTypeForHFSTypeCode(kGenericApplicationIcon)];
        }
        
        //'iconForFileType' returns small icons
        // ->so set size to 128
        [self.icon setSize:NSMakeSize(128, 128)];
    }
    
    return self.icon;
}


@end
