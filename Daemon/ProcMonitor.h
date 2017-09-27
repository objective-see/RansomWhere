//
//  ProcMonitor.h
//  RansomWhere
//
//  Created by Patrick Wardle on 2/22/17.
//  Copyright (c) Objective-See. All rights reserved.
//

#import "Process.h"
#import <Foundation/Foundation.h>

//audit pipe
#define AUDIT_PIPE "/dev/auditpipe"

//audit class for proc events
#define AUDIT_CLASS_PROCESS 0x00000080

//audit class for exec events
#define AUDIT_CLASS_EXEC 0x40000000

@interface ProcMonitor : NSObject
{
    
}

/* iVARS / PROPERTIES */

//dictionary of processes
@property(nonatomic, retain)NSMutableDictionary* processes;

//dictioanary of binary objects
@property(nonatomic, retain)NSMutableDictionary* binaries;

/* METHODS */

//create threads to:
// a) invoke method to enumerate procs
// b) invoke method to monitor for new procs
-(void)start;

//check if event is one we care about
-(BOOL)shouldProcessRecord:(u_int16_t)eventType;

//create binary object
// ->enum/process ancestors, etc
-(void)handleNewProcess:(Process*)newProcess;

//remove any processes that dead & old
-(void)refreshProcessList;

@end
