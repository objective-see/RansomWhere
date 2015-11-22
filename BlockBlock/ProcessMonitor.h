//
//  ProcessMonitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//
#import <Foundation/Foundation.h>

#import "OrderedDictionary.h"

//custom struct
// format of data that's broadcast from kext
struct processStartEvent
{
    //process pid
    pid_t pid;
    
    //process uid
    uid_t uid;
    
    //process ppid
    pid_t ppid;
    
    //process path
    char path[0];
};

@interface ProcessMonitor : NSObject
{
    
}

/* PROPERTIES */

@property (nonatomic, retain)OrderedDictionary* processList;


/* METHODS */

//kicks off thread to monitor
-(BOOL)monitor;

//thread function
// ->recv() process creation notification events from kext
-(void)recvProcNotifications;

@end
