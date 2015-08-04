//
//  Logging.c
//  BlockBlock
//
//  Created by Patrick Wardle on 12/21/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#import "Logging.h"
#import "Consts.h"


//log a msg
// ->default to syslog, and if an err msg, to disk
void logMsg(int level, NSString* msg)
{
    
    //log prefix
    NSMutableString* logPrefix = nil;
    
    //alloc/init
    // ->always start w/ 'BLOCKBLOCK' + pid
    logPrefix = [NSMutableString stringWithFormat:@"BLOCKBLOCK(%d)", getpid()];
    
    //if its error, add error to prefix
    if(LOG_ERR == level)
    {
        //add
        [logPrefix appendString:@" ERROR"];
    }
    
    //debug mode logic
    #ifdef DEBUG
    
    //in debug mode promote debug msgs to LOG_NOTICE
    // ->OS X only shows LOG_NOTICE and above~
    if(LOG_DEBUG == level)
    {
        //promote
        level = LOG_NOTICE;
    }
    
    #endif
    
    //log to syslog
    syslog(level, "%s: %s", [logPrefix UTF8String], [msg UTF8String]);
    
    return;
}
