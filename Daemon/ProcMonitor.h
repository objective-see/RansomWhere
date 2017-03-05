//
//  ProcMonitor.h
//  RansomWhere
//
//  Created by Patrick Wardle on 2/22/17.
//  Copyright (c) Objective-See. All rights reserved.
//

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

//dictioanary of processes
@property(nonatomic, retain)NSMutableDictionary* processes;

/* METHODS */

//monitor file-system events
//-(void)monitor;

//check if event is one we care about
-(BOOL)shouldProcessRecord:(u_int16_t)eventType;


@end
