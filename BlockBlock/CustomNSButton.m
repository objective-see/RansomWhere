//
//  CustomNSButton.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Signing.h"
#import "CustomNSButton.h"



@implementation CustomNSButton

//ignore simulated mouse events
-(void)mouseDown:(NSEvent *)event
{
    //pid
    int64_t processID = 0;
    
    //uid
    int64_t processUID = 0;
    
    //signing info
    NSDictionary* signingInfo = nil;
    
    //buffer for proc_pidpath()
    char processPath[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //get pid
    processID = CGEventGetIntegerValueField(event.CGEvent, kCGEventSourceUnixProcessID);
    
    //get uid
    processUID = CGEventGetIntegerValueField(event.CGEvent, kCGEventSourceUserID);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking mouse event (%lld/%lld", processID, processUID]);
    #endif
    
    //get process path from pid
    // ->then get it's signing info
    if( (0 != processID) &&
        (0 != proc_pidpath((int)processID, processPath, PROC_PIDPATHINFO_MAXSIZE)))
    {
        //grab signing info
        //TODO: check for nil path!!
        signingInfo = extractSigningInfo([NSString stringWithUTF8String:processPath]);
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process path/signing info: %s/%@", processPath, signingInfo]);
        #endif
    }

    //allow if root, or uid (root) or _hidd (261)
    // ...or if process is validly signed (apple or dev id)
    if( (0 != processID) &&
        (0 != processUID) && (HID_UID != processUID) &&
        (noErr != [signingInfo[KEY_SIGNATURE_STATUS] intValue]))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ignoring mouse event that appears simulated (%lld/%lld)", processID, processUID]);
        
        //more err msg
        if( (0 != strlen(processPath)) &&
            (nil != signingInfo) )
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"process: %s / signing info: %@", processPath, signingInfo]);
        }
    
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"allowing mouse event");
    #endif
    
    //allow
    [super mouseDown:event];
    
//bail
bail:

    return;
    
}


@end
