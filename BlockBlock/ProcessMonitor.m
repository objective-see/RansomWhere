//
//  ProcessMonitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Process.h"
#import "Utilities.h"
#import "ProcessMonitor.h"
#import "OrderedDictionary.h"
#import "Logging.h"

#import <sys/ioctl.h>
#import <sys/socket.h>
#import <sys/kern_event.h>

#include <stdio.h>
#include <stdlib.h>
#include <arpa/inet.h>

@implementation ProcessMonitor

@synthesize processList;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init process list
        processList = [[OrderedDictionary alloc] init];
    }
    
    return self;
}

//kick off threads to monitor
// ->dtrace/audit pipe/app callback
-(BOOL)monitor
{
    //return var
    BOOL bRet = NO;
    
    //start thread to get process creation notifications from kext
    [NSThread detachNewThreadSelector:@selector(recvProcNotifications) toTarget:self withObject:nil];
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//thread function
// ->recv() process creation notification events
-(void)recvProcNotifications
{
    //status var
    int status = -1;
    
    //system socket
    int systemSocket = -1;
    
    //struct for vendor code
    // ->set via call to ioctl/SIOCGKEVVENDOR
    struct kev_vendor_code vendorCode = {0};
    
    //struct for kernel request
    // ->set filtering options
    struct kev_request kevRequest = {0};
    
    //struct for broadcast data from the kext
    struct kern_event_msg *kernEventMsg = {0};
    
    //message from kext
    // ->size is cumulation of header, struct, and max length of a proc path
    char kextMsg[KEV_MSG_HEADER_SIZE + sizeof(struct processStartEvent) + PATH_MAX] = {0};
    
    //bytes received from system socket
    ssize_t bytesReceived = -1;
    
    //custom struct
    // ->process data from kext
    struct processStartEvent* procStartEvent = NULL;
    
    //process info
    NSMutableDictionary* procInfo = nil;
    
    //process object
    Process* processObj = nil;
    
    //create system socket
    systemSocket = socket(PF_SYSTEM, SOCK_RAW, SYSPROTO_EVENT);
    if(-1 == systemSocket)
    {
        //set status var
        status = errno;
        
        //err msg
        printf("ERROR: socket() failed with %d\n\n", status);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    printf(" created system socket\n");
    
    //set vendor name string
    strncpy(vendorCode.vendor_string, OBJECTIVE_SEE_VENDOR, KEV_VENDOR_CODE_MAX_STR_LEN);
    
    //get vendor name -> vendor code mapping
    status = ioctl(systemSocket, SIOCGKEVVENDOR, &vendorCode);
    if(0 != status)
    {
        //err msg
        printf("ERROR: ioctl(...,SIOCGKEVVENDOR,...) failed with %d\n\n", status);
        
        //goto bail;
        goto bail;
    }
    
    //dbg msg
    printf(" got vendor name code %d, for %s\n", vendorCode.vendor_code, OBJECTIVE_SEE_VENDOR);
    
    //init filtering options
    // ->only interested in objective-see's events
    kevRequest.vendor_code = vendorCode.vendor_code;
    
    //...any class
    kevRequest.kev_class = KEV_ANY_CLASS;
    
    //...any subclass
    kevRequest.kev_subclass = KEV_ANY_SUBCLASS;
    
    //tell kernel what we want to filter on
    status = ioctl(systemSocket, SIOCSKEVFILT, &kevRequest);
    if(0 != status)
    {
        //err msg
        printf("ERROR: ioctl(...,SIOCSKEVFILT,...) failed with %d\n\n", status);
        
        //goto bail;
        goto bail;
    }
    
    //dbg msg
    printf(" set kernel event filtering options\n");
    
    //dbg msg
    //printf(" entering recv() loop\n\n");
    
    //foreverz
    // ->listen/parse process creation events from kext
    while(YES)
    {
        //ask the kext for process began events
        // ->will block until event is ready
        bytesReceived = recv(systemSocket, kextMsg, sizeof(kextMsg), 0);
        if(bytesReceived < (KEV_MSG_HEADER_SIZE + sizeof(struct processStartEvent)))
        {
            //error or short read
            // ->ignore
            continue;
        }
        
        //type cast
        // ->to access kev_event_msg header
        kernEventMsg = (struct kern_event_msg*)kextMsg;
        
        //only care about 'process began' events
        if(PROCESS_BEGAN_EVENT != kernEventMsg->event_code)
        {
            //skip
            continue;
        }
        
        //typecast custom data
        // ->begins right after header
        procStartEvent = (struct processStartEvent*)&kernEventMsg->event_data[0];
        
        //dbg msg(s)
        //printf("  process: %s \n", procStartEvent->path);
        //printf("  pid: %d ppid: %d uid: %d\n\n", procStartEvent->pid, procStartEvent->ppid, procStartEvent->uid);
    
        //init proc info dictionary
        procInfo = [NSMutableDictionary dictionary];
        
        //save pid
        procInfo[@"pid"] = [NSNumber numberWithInt:procStartEvent->pid];
        
        //save uid
        procInfo[@"uid"] = [NSNumber numberWithInt:procStartEvent->uid];
        
        //save ppid
        procInfo[@"ppid"] = [NSNumber numberWithInt:procStartEvent->ppid];
        
        //save path
        procInfo[@"path"] = [NSString stringWithUTF8String:procStartEvent->path];
        
        //create process object
        processObj = [[Process alloc] initWithPid:procStartEvent->pid infoDictionary:procInfo];
    
        //sync
        @synchronized(self.processList)
        {
            //trim list if needed
            if(self.processList.count >= PROCESS_LIST_MAX_SIZE)
            {
                //toss first (oldest) item
                [self.processList removeObjectForKey:[self.processList keyAtIndex:0]];
            }
        
            //insert process at end
            [self.processList insertObject:processObj forKey:procInfo[@"pid"] atIndex:self.processList.count];
        
        }//sync
        
    }//while(YES)
    
//bail
bail:
    
    //close socket
    if(-1 != systemSocket)
    {
        //close
        close(systemSocket);
    }

    return;

}

@end
