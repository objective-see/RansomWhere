//
//  Queue.m
//  RansomWhere
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Event.h"
#import "Queue.h"
#import "Consts.h"
#import "Binary.h"
#import "Logging.h"
#import "Utilities.h"


@implementation Queue

@synthesize icon;
@synthesize eventQueue;
@synthesize queueCondition;


//init
// ->alloc & queue thead
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init queue
        eventQueue = [NSMutableArray array];
 
        //init empty condition
        queueCondition = [[NSCondition alloc] init];
 
        //init path to icon
        icon = [NSURL URLWithString:[DAEMON_DEST_FOLDER stringByAppendingPathComponent:ALERT_ICON]];
    
        //kick off thread to watch/process items placed in queue
        [NSThread detachNewThreadSelector:@selector(dequeue:) toTarget:self withObject:nil];
    }
    
    return self;
}

//add an object to the queue
-(void)enqueue:(id)anObject
{
    //lock
    [self.queueCondition lock];
    
    //add to queue
    [self.eventQueue enqueue:anObject];
    
    //signal
    [self.queueCondition signal];
    
    //unlock
    [self.queueCondition unlock];
    
    return;
}

//dequeue
// ->forever, process events from queue
-(void)dequeue:(id)threadParam
{
    //watch event
    Event* event = nil;

    //for ever
    while(YES)
    {
        //pool
        @autoreleasepool {
            
        //lock queue
        [self.queueCondition lock];
        
        //wait while queue is empty
        while(YES == [self.eventQueue empty])
        {
            //wait
            [self.queueCondition wait];
        }
        
        //item is in queue!
        // ->grab it, then process
        event = [eventQueue dequeue];
            
        //unlock
        [self.queueCondition unlock];
            
        //dispatch to process event async'd
        //TODO: was high!
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            [self processEvent:event];
        });
        
        }//pool
        
    }//loop: foreverz process queue
        
    return;
}

//thread method
// ->process event off queue
-(void)processEvent:(Event*)event
{
    //response
    CFOptionFlags response = 0;
    
    //hit encrypted file limit
    BOOL hitLimit = NO;
    
    //ancestor hit encryted file limit
    BOOL ancestorHitLimit = NO;
    
    //flag, who killing
    // ->child/(untrusted) ancestor
    BOOL killAncestor = NO;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processing queued event: %@", event]);
    #endif
    
    //SKIP
    // ->if user has logged out, ignore
    if(NULL == consoleUserName)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: not user logged in, sorry!");
        #endif
        
        //skip
        goto bail;
    }
    
    //SKIP
    // ->always skip whitelisted 3rd-party apps
    if(YES == event.process.binary.isWhiteListed)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is whitelist'd 3rd-party binary");
        #endif
        
        //bail
        goto bail;

    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"0) is not whitelisted binary");
    #endif
    
    //SKIP
    // ->events generated by OS X apps
    //   ...unless gray-listed (which only applies to Apple apps)
    //      or has untrusted parent (i.e. zip being exec'd by malware)
    if( (YES == event.process.binary.isApple) &&
        (YES != event.process.binary.isGrayListed) &&
        (nil == event.process.untrustedAncestor) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is Apple binary (that's also not graylisted/doesn't have untrusted ancestor)");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"1) is not Apple binary (or is, but is graylisted/untrusted ancestor)");
    #endif
    
    //SKIP events generated by apps from the App Store
    if(YES == event.process.binary.isAppStore)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is App Store binary");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"2) is not App Store binary");
    #endif
    
    //SKIP
    // ->events generated by apps baselined/prev installed apps
    //   unless they are graylisted or have untrusted ancestor
    if( (YES == event.process.binary.isBaseline) &&
        (YES != event.process.binary.isGrayListed) &&
        (nil == event.process.untrustedAncestor) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is installed/baselined app (that's also not graylisted/doesn't have untrusted ancestor)");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"3) is not installed/baselined app (or is, but is graylisted/untrusted ancestor)");
    #endif
    
    //SKIP
    // ->events generated by 'user-allowed' binaries
    if(YES == event.process.binary.isApproved)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is user approved/allowed binary");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"4) is from non-allowed binary");
    #endif
    
    //SKIP
    // ->events generated by disallowed processes
    //   since a disallowed process is only set once user has killed (meaning such events are 'stale' and the proc is dead)
    if(YES == event.process.wasDisallowed)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is disallowed process");
        #endif
        
        //bail
        goto bail;
    }
        
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"5) is from non-disallowed process");
    #endif
    
    //SKIP
    // ->files under 1024, as entropy calculations don't do well on smaller files
    if([[[NSFileManager defaultManager] attributesOfItemAtPath:event.filePath error:nil] fileSize] < 1024)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"ignoring: small file (%llu bytes)", [[[NSFileManager defaultManager] attributesOfItemAtPath:event.filePath error:nil] fileSize]]);
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"6) is large enough");
    #endif
    
    //SKIP
    // ->any non-encrypted files (also ignores image files, etc)
    if(YES != isEncrypted(event.filePath))
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: is not encrypted");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"7) is encrypted");
    #endif
    
    //add encrypted file
    event.process.encryptedFiles[event.filePath] = [NSDate date];
    
    //hit limit?
    hitLimit = [event.process hitEncryptedTheshold];
    
    //untrusted ancestor?
    // ->also add into its list and check limit
    if(nil != event.process.untrustedAncestor)
    {
        //save
        event.process.untrustedAncestor.encryptedFiles[event.filePath] = [NSDate date];
        
        //hit limit?
        ancestorHitLimit = [event.process.untrustedAncestor hitEncryptedTheshold];
    }
    
    //SKIP
    // ->process that haven't hit encryption theshold
    //   and also don't have an ancestor that is untrusted
    if( (YES != hitLimit) &&
        (YES != ancestorHitLimit) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring: process (and any untrusted ancestor) hasn't encrypted enough files (quick enough)");
        #endif
        
        //ignore
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"8) was encrypted by process that's quickly encrypting a bunch of files");
    #endif
    
    //suspend process it hit the limit
    // ->will be terminated, or resumed depending on user's response
    if(YES == hitLimit)
    {
        //try kill
        // ->only bail though if an untrusted ancestor didn't hit the limit also
        if( (-1 == kill(event.process.pid, SIGSTOP)) &&
            (YES != ancestorHitLimit) )
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to suspend %d (%@), with %d", event.process.pid, event.process.binary.path, errno]);
            
            //bail
            goto bail;
        }
        
        //dbg msg(s)
        // ->always show
        syslog(LOG_ERR, "%s", [NSString stringWithFormat:@"OBJECTIVE-SEE RANSOMWHERE?: %@ is quickly creating encrypted files", event.process.binary.path].UTF8String);
        syslog(LOG_ERR, "OBJECTIVE-SEE RANSOMWHERE?: suspended and alerting user");
        
    }
    //if it's an ancestor that hit the limit, suspend that
    // ->will be terminated, or resumed depending on user's response
    else if(YES == ancestorHitLimit)
    {
        //set flag
        killAncestor = YES;
        
        //try kill
        if(-1 == kill(event.process.pid, SIGSTOP))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to suspend ancestor %d (%@), with %d", event.process.untrustedAncestor.pid, event.process.untrustedAncestor.binary.path, errno]);
            
            //bail
            goto bail;
        }
        
        //dbg msg(s)
        // ->always show
        syslog(LOG_ERR, "%s", [NSString stringWithFormat:@"OBJECTIVE-SEE RANSOMWHERE?: %@ (ancestor of %@) has childen quickly creating encrypted files", event.process.untrustedAncestor.binary.path, event.process.binary.path].UTF8String);
        syslog(LOG_ERR, "OBJECTIVE-SEE RANSOMWHERE?: suspended and alerting user");
        
    }
    
    //ignore already reported procs
    if( ((YES != killAncestor) && (YES == event.process.wasReported)) ||
        ((YES == killAncestor) && (YES == event.process.untrustedAncestor.wasReported)) )
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"ignoring process that was already reported");
        #endif
        
        //bail
        goto bail;
    }

    //alert user
    // ->note: call will *block* until user responsed
    response = [self alertUser:event];
    
    //handle response
    // ->either resume or terminate process
    [self processResponse:event response:response];
    

//bail
bail:
    
    return;
}

//show alert to the user
// ->block until response, which is returned from this method
-(CFOptionFlags)alertUser:(Event*)event
{
    //user's response
    CFOptionFlags response = 0;
    
    //header
    NSString* title = NULL;
    
    //body
    NSMutableString* body = NULL;
    
    //signing info
    NSString* signingInfo = nil;
    
    //encrypted file
    NSArray* encryptedFiles = nil;
    
    //init title
    title = [NSString stringWithFormat:@"%@ is 🔒'ing files!", [event.process.binary.path lastPathComponent]];
    
    //format signing info
    signingInfo = [event.process.binary formatSigningInfo];
    
    //start body
    body = [NSMutableString stringWithFormat:@"proc: %@ (%d, %@)\r\n", event.process.binary.path, event.process.pid, signingInfo];
    
    //add any untrusted ancestor
    if(nil != event.process.untrustedAncestor)
    {
        //format signing info for ancestor
        signingInfo = [event.process.untrustedAncestor.binary formatSigningInfo];
        
        //add info about untrusted ancestor
        [body appendFormat:@"untrusted ancestor: %@ (%d, %@)\r\n", event.process.untrustedAncestor.binary.path, event.process.untrustedAncestor.pid, signingInfo];
    }
    
    //spacing
    [body appendFormat:@"\r\n"];
    
    //get files
    encryptedFiles = event.process.encryptedFiles.allKeys;
        
    //add first file
    [body appendFormat:@"files:\r\n ■ %@", encryptedFiles[0]];
    
    //add next if it's there
    if(encryptedFiles.count > 2)
    {
        [body appendFormat:@"\r\n ■ %@", encryptedFiles[1]];
    }
    
    //show alert
    // ->will *block* until user interaction, then response saved in 'response' variable
    CFUserNotificationDisplayAlert(0.0f, kCFUserNotificationStopAlertLevel, (CFURLRef)self.icon, NULL, NULL, (__bridge CFStringRef)title, (__bridge CFStringRef)body, (__bridge CFStringRef)@"Terminate", (__bridge CFStringRef)@"Allow", NULL, &response);
    
//bail
bail:
    
    return response;
}

//handle response
// ->either resume or terminate process
-(void)processResponse:(Event*)event response:(CFOptionFlags)response
{
    //terminate process
    if(PROCESS_TERMINATE == response)
    {
        //dbg msg
        // ->always show
        syslog(LOG_ERR, "OBJECTIVE-SEE RANSOMWHERE?: user responded with 'terminate'");
        
        //terminate
        if(-1 == kill(event.process.pid, SIGKILL))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill %d (%@), with %d", event.process.pid, event.process.binary.path, errno]);
            
            //bail
            goto bail;
        }
        
        //set disallowed flag
        // ->allows us to ignore any other queue'd events for this proc
        event.process.wasDisallowed = YES;
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"terminated process");
        #endif
    }
    
    //resume process
    // ->also add to allowed proc (unless it's an apple proc, with untrusted ancestor)
    else
    {
        //dbg msg
        // ->always show
        syslog(LOG_ERR, "OBJECTIVE-SEE RANSOMWHERE?: user responded with 'resume' (allow)");
        
        //resume process
        if(-1 == kill(event.process.pid, SIGCONT))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to resume %d (%@), with %d", event.process.pid, event.process.binary.path, errno]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"resumed process");
        #endif
        
        //update binary object for process
        event.process.binary.isApproved = YES;
        
        //don't permanently approve apple binaries with untrusted ancestors
        if( (YES == event.process.binary.isApple) &&
            (nil != event.process.untrustedAncestor) )
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"not permanently approving %d (%@), as it is an apple binary, with an untrusted ancestor (%@)", event.process.pid, event.process.binary.path, event.process.untrustedAncestor]);
            #endif
        
            
            //bail
            goto bail;
        }
        
        //update list of user-approved binaries
        [whitelist updateApproved:event.process.binary];
        
    }
    
//bail
bail:
 
    return;
}


@end
