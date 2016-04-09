//
//  Logging.m
//  RansomWhere (Shared)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

//log a msg
void logMsg(int level, NSString* msg)
{
    //log prefix
    NSMutableString* logPrefix = nil;
    
    //date formatter
    NSDateFormatter *formatter = nil;
    
    //alloc
    formatter = [[NSDateFormatter alloc] init];

    //set date
    [formatter setDateFormat:@"HH:mm:ss.SSSS"];
    
    //alloc/init
    // ->always start w/ 'RANSOMWHERE?' + pid/tid
    logPrefix = [NSMutableString stringWithFormat:@"%@: OBJECTIVE-SEE RANSOMWHERE? (%d/%ld)", [formatter stringFromDate:[NSDate date]], getpid(), [[[NSThread currentThread] valueForKeyPath:@"private.seqNum"] integerValue]];
    
    //if its error, add error to prefix
    if(LOG_ERR == level)
    {
        //add
        [logPrefix appendString:@" ERROR: "];
    }
    
    //debug mode logic
    #ifdef DEBUG
    
    //in debug mode promote debug msgs to LOG_NOTICE
    // ->OS X only shows LOG_NOTICE and above
    if(LOG_DEBUG == level)
    {
        //promote
        level = LOG_NOTICE;
    }
    
    #endif
    
    //log to syslog
    syslog(level, "%s: %s\n", [logPrefix UTF8String], [msg UTF8String]);
    
    return;
}
