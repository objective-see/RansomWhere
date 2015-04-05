//
//  Logging.c
//  BlockBlock
//
//  Created by Patrick Wardle on 12/21/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//


#import "Logging.h"
#import "Consts.h"


//log a msg
// ->default to syslog, and if an err msg, to disk
void logMsg(int level, NSString* msg)
{
    //TODO: disable debug logging for release build
    //if(releaseBUILD)
    
    
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
    
    //TOOD: only do this in debug build
    //hack!!
    // -> OS X only shows LOG_NOTICE and above~
    if(LOG_DEBUG == level)
    {
        level = LOG_NOTICE;
    }
    
    //log to syslog
    syslog(level, "%s: %s", [logPrefix UTF8String], [msg UTF8String]);
    
    return;
}
