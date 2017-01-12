//
//  CustomNSButton.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "CustomNSButton.h"

@implementation CustomNSButton

//ignore simulated mouse events
-(void)mouseDown:(NSEvent *)event
{
    //pid
    int64_t processID = 0;
    
    //uid
    int64_t processUID = 0;
    
    //get pid
    processID = CGEventGetIntegerValueField(event.CGEvent, kCGEventSourceUnixProcessID);
    
    //get uid
    processUID = CGEventGetIntegerValueField(event.CGEvent, kCGEventSourceUserID);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking mouse event (%lld/%lld)", processID, processUID]);
    
    //allow if root, or uid (root) or _hidd (261)
    if( (0 != processID) &&
        (0 != processUID) &&
        (HID_UID != processUID) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ignoring mouse event that appears simulated (%lld/%lld)", processID, processUID]);
        
        //bail
        goto bail;
    }
    
    //allow
    [super mouseDown:event];
    
    //mostRecentProc(((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList
    //process = processList[processID];
    
//bail
bail:

    return;
    
}


@end
