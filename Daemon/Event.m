//
//  Event.m
//  RansomWhere?
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

@import OSLog;

#import "consts.h"
#import "utilities.h"

#import "Process.h"
#import "Event.h"

//#import "FileMonitor.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

@implementation Event

@synthesize item;
@synthesize uuid;
@synthesize action;
@synthesize process;
@synthesize timestamp;

//init
-(id)init:(Process*)process
{
    self = [super init];
    if(self)
    {
        //create timestamp
        timestamp = [NSDate date];
        
        //save process
        self.process = process;
    }
    
    return self;
}

//create an (deliverable) dictionary object
-(NSMutableDictionary*)toAlert
{
    //event for alert
    NSMutableDictionary* alert = nil;
    
    //signing info
    NSMutableDictionary* signingInfo = nil;
    
    //alloc
    alert = [NSMutableDictionary dictionary];
    
    //alloc
    signingInfo = [NSMutableDictionary dictionary];
    
    //meta data
    alert[ALERT_UUID] = [[NSUUID UUID] UUIDString];
    alert[ALERT_PROCESS_PID_VERSION] = self.process.pidVersion;
    
    // for top of alert window
    
    //add process name
    alert[ALERT_PROCESS_NAME] = valueForStringItem(self.process.name);
    
    //add alert msg
    alert[ALERT_MESSAGE] = @"is rapidly creating encrypted files";
    
    //add pid
    alert[ALERT_PROCESS_ID] = [NSNumber numberWithUnsignedInt:self.process.pid];
    
    //add path
    alert[ALERT_PROCESS_PATH] = valueForStringItem(self.process.path);

    //add cs flags
    signingInfo[CS_FLAGS] = self.process.csFlags;
    
    //add platform binary
    signingInfo[PLATFORM_BINARY] = @(self.process.isPlatformBinary);
    
    //add team id
    if(nil != self.process.teamID)
    {
        //add
        signingInfo[TEAM_ID] = self.process.teamID;
    }
    
    //add signing id
    if(nil != self.process.signingID)
    {
        //add
        signingInfo[SIGNING_ID] = self.process.signingID;
    }
    
    //now add signing info
    alert[ALERT_PROCESS_SIGNING_INFO] = signingInfo;
    
    //add args
    if(self.process.arguments.count) {
        alert[ALERT_PROCESS_ARGS] = self.process.arguments;
    }
    
    //init/add process ancestors
    // pid:name mapping for alert window
    alert[ALERT_PROCESS_ANCESTORS] = [self buildProcessHierarchy:self.process];
    
    //encrypted files
    alert[ALERT_ENCRYPTED_FILES] = [self.process.encryptedFiles allKeys];
    
    //dbg msg
    os_log_debug(logHandle, "sending alert to user (client): %{public}@", alert);
    
    return alert;
}


//build an array of processes ancestry
// this is used to populate the 'ancesty' popup
-(NSMutableArray*)buildProcessHierarchy:(Process*)process
{
    //process hierarchy
    NSMutableArray* processHierarchy = nil;
    
    //ancestor
    NSNumber* ancestor = nil;
    
    //alloc
    processHierarchy = [NSMutableArray array];
    
    //add current process (leaf)
    // parent(s) will then be added at front...
    [processHierarchy addObject:[@{@"pid":[NSNumber numberWithInt:process.pid], @"name":valueForStringItem(process.name)} mutableCopy]];
    
    //get name and add each ancestor
    for(NSUInteger i=0; i<process.ancestors.count; i++)
    {
        //skip first one (self)
        // already have it (with pid/path!)
        if(0 == i) continue;
        
        //extact ancestor
        ancestor = process.ancestors[i];
        
        //add
        [processHierarchy addObject:[@{@"pid":ancestor, @"name":valueForStringItem(getProcessPath(ancestor.intValue))} mutableCopy]];
    }
        
    //add the index value
    // used to populate outline/table
    for(NSUInteger i = 0; i < processHierarchy.count; i++)
    {
        //set index
        processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
    }
    
    //dbg msg
    os_log_debug(logHandle, "process hierarchy: %{public}@", processHierarchy);

    return processHierarchy;
}


/*
//for pretty print
-(NSString *)description {
    return [NSString stringWithFormat: @"process=%@, file paths=%@, timestamp=%@, item binary=%@", self.process, self.process.enc, self.timestamp, self.item];
}
*/

@end
