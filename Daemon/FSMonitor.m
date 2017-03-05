//
//  Watcher.m
//  RansomWhere
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Event.h"
#import "Consts.h"
#import "Logging.h"
#import "Binary.h"
#import "Utilities.h"
#import "FSMonitor.h"

#import <Cocoa/Cocoa.h> //TODO: remove?


#import <Foundation/Foundation.h>


@implementation FSMonitor

@synthesize eventQueue;

//init function
// ->load watch paths, alloc queue, etc
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc/init event queue
        eventQueue = [[Queue alloc] init];
    }
    
    return self;
}

//monitor file-system events
// ->new events are checked for path match, then added to queue for more intense processing/alerting
-(void)monitor
{
    //file handle
    int fsed = -1;
    
    //cloned handle
    int cloned_fsed = -1;

    //bytes read
    ssize_t bytesRead = 0;
    
    //cloned args
    fsevent_clone_args clonedArgs = {0};
    
    //buffer for events
    unsigned char* fsEvents = NULL;
    
    //list of events to watch
    int8_t events[FSE_MAX_EVENTS] = {0};
    
    //last path
    // ->sometimes get two FS events for the same file?
    NSString* lastPath = nil;
    
    //path to file/dir
    NSString* path = nil;

    //event object
    Event* event = nil;
    
    //binary object
    Binary* binary = nil;
    
    //pool
    @autoreleasepool
    {

    //alloc buffer
    fsEvents = malloc(BUFSIZE);
    
    //open the device
    if((fsed = open(DEVICE_FSEVENTS, O_RDONLY)) < 0)
    {
        //bail
        goto bail;
    }
    
    //explicitly init all to FSE_IGNORE
    memset(events, FSE_IGNORE, FSE_MAX_EVENTS);
    
    //report close w/ modifications
    events[FSE_CONTENT_MODIFIED] = FSE_REPORT;
    
    //report on renames
    events[FSE_RENAME] = FSE_REPORT;
    
    //clear out struct
    memset(&clonedArgs, 0x0, sizeof(clonedArgs));
    
    //set fs to the clone
    clonedArgs.fd = &cloned_fsed;
    
    //set depth
    // ->bump this for dropped events
    clonedArgs.event_queue_depth = 1024;
    
    //set list
    clonedArgs.event_list = events;
    
    //set size of list
    clonedArgs.num_events = FSE_MAX_EVENTS;
    
    //clone description
    if(ioctl(fsed, FSEVENTS_CLONE, &clonedArgs) < 0)
    {
        //bail
        goto bail;
    }
    
    //no longer need orig
    close(fsed);
    
    //monitor forever
    while(YES)
    {
        //pool
        @autoreleasepool
        {
            
        //offset into buffer
        int bufferOffset = 0;
        
        //read file-system events
        // ->if this fails, just nap and continue
        bytesRead = read(cloned_fsed, fsEvents, BUFSIZE);
        if(bytesRead <= 0)
        {
            //try again
            continue;
        }
        
        //parse fs events
        while(bufferOffset < bytesRead)
        {
            //get pointer
            struct kfs_event_a *fse = (struct kfs_event_a *)(fsEvents + bufferOffset);
            
            //go to next event
            // ->returns path (from event data)
            path = [self advance2Next:fsEvents currentOffsetPtr:&bufferOffset];
            
            //skip blank pids or pids
            if( (0 == fse->pid) ||
                (nil == path) )
            {
                //skip
                continue;
            }
            
            //skip same path
            if(YES == [path isEqualToString:lastPath])
            {
                //dbg msg
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"skipping event, as its same as last (%@)", path]);
                #endif
                
                //skip
                continue;
            }
            
            //update
            lastPath = path;
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new file system event: %@ (type: %x/ pid: %d)", path, fse->type, fse->pid]);
            #endif
            
            //skip any non-watched paths
            //->e.g. window_<digits>.data files
            if(YES == [self shouldIgnore:path])
            {
                //TODO: remove
                logMsg(LOG_DEBUG, @"ignoring A");
                
                //skip
                continue;
            }
            
            //check process
            // ->make new process object if needed
            binary = [self getBinaryObject:fse->pid];
            if(nil == binary)
            {
                //did it die?
                if(YES != isProcessAlive(fse->pid))
                {
                    //TODO: remove
                    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process %d is dead (parent is/was: %d)", fse->pid, getParentID(fse->pid)]);
                }
                
                //TODO: remove
                logMsg(LOG_DEBUG, @"ignoring B");
                
                //err creating obj
                // ->so skip/ignore
                continue;
            }
            
            //don't process if there is no logged in user
            // ->could have this check earlier, but want binary objects to be gen'd
            if(NULL == consoleUserName)
            {
                //TODO: remove
                logMsg(LOG_DEBUG, @"ignoring C");
                
                //skip
                continue;
            }

            //create event object
            event = [[Event alloc] init:path binary:binary fsEvent:fse];
            if(nil == event)
            {
                //TODO: remove
                logMsg(LOG_DEBUG, @"ignoring D");
                
                //skip
                continue;
            }
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added event to queue: %@", event]);
            #endif
            
            //add to global queue
            // ->this will trigger handling of event, alerts, etc
            [self.eventQueue enqueue:event];
            
        }//loop: data loop
            
        }//pool
        
    }//loop: read events
    
//bail
bail:
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"watch() looped exited due to %d\n", errno]);
    
    //free fs events buffer
    if(NULL != fsEvents)
    {
        //free
        free(fsEvents);
        
        //unset
        fsEvents = NULL;
    }
        
    }//pool
    
    
    return;
}

//try find existing binary obj
// ->makes new one if that's needed
-(Binary*)getBinaryObject:(pid_t)pid
{
    //binary object
    Binary* binary = nil;
    
    //pid->path mapping dictionary
    //NSMutableDictionary* pidProcMapping = nil;
    
    //process path
    NSString* processPath = nil;
    
    ////TODO: grab from process monitor
    
    //get path from pid
    processPath = getProcessPath(pid);
    if(nil == processPath)
    {
        //TODO: grab from process monitor
        
        //ignore
        goto bail;
    }
    
    //sync to check
    @synchronized(enumerator.binaryList)
    {
        //see if there's an existing binary object
        // ->if so, all set, so can bail to return binary to caller
        binary = enumerator.binaryList[processPath];
        if(nil != binary)
        {
            //all set
            goto bail;
        }
    }

    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ (%d) is new binary, will create", processPath, pid]);
    #endif
    
    //create binary object
    // ->this is kinda slow so don't do in a @sync
    binary = [[Binary alloc] init:processPath attributes:nil];
    
    //sync to add
    @synchronized(enumerator.binaryList)
    {
        //still nil?
        if(nil == enumerator.binaryList[processPath])
        {
            //add
            enumerator.binaryList[processPath] = binary;
        }
    }
    
    
//bail
bail:
    
    return binary;
}


//determine if a path should be ignored
// ->for now, just window_<digits>.data files
-(BOOL)shouldIgnore:(NSString*)path
{
    //flag
    BOOL ignore = NO;
    
    //path bytes
    const char* utf8String = NULL;
    
    //init bytes
    utf8String = path.UTF8String;
    
    //dot
    char* dot = NULL;
    
    //slash
    char* slash = NULL;
    
    //ignore any window_<digits>.data files
    // ->start by seeing if file ends in '.data'
    dot = strrchr(utf8String, '.');
    if( (NULL != dot) &&
        (0 == strcmp(dot, ".data")) )
    {
        //now check if the file name starts with '/window_'
        slash = strrchr(utf8String, '/');
        if( (NULL != slash) &&
            (0 == strncmp(slash, "/window_", strlen("/window_"))) )
        {
            //got a window_xxx.data
            // ->good enough match for now, so ignore
            ignore = YES;
            
            //TODO: add bail if more checks are added below
        }
    }
    
    return ignore;
}

//skip over args to get to next event file-system struct
-(NSString*)advance2Next:(unsigned char*)ptrBuffer currentOffsetPtr:(int*)ptrCurrentOffset
{
    //path
    NSString* path = nil;
    
    //event
    struct kfs_event_a *fse = NULL;
    
    //args
    struct kfs_event_arg *fse_arg = NULL;
    
    //arg type
    unsigned short *argType = NULL;
    
    //arg length
    unsigned short *argLen = NULL;
    
    //init event
    fse = (struct kfs_event_a *)(unsigned char*)((unsigned char*)ptrBuffer + *ptrCurrentOffset);
    
    //handle dropped events
    if(fse->type == FSE_EVENTS_DROPPED)
    {
        //advance to next
        *ptrCurrentOffset += sizeof(kfs_event_a) + sizeof(fse->type);
        
        //bail
        goto bail;
    }
    
    //init pointer
    *ptrCurrentOffset += sizeof(struct kfs_event_a);
    
    //init args
    fse_arg = (struct kfs_event_arg *)&ptrBuffer[*ptrCurrentOffset];
    
    //save path
    path = [NSString stringWithUTF8String:fse_arg->data];
    
    //skip over path
    *ptrCurrentOffset += sizeof(kfs_event_arg) + fse_arg->pathlen ;
    
    //init arg type
    argType = (unsigned short *)(unsigned char*)((unsigned char*)ptrBuffer + *ptrCurrentOffset);
    
    //init arg length
    argLen  = (unsigned short *)(ptrBuffer + *ptrCurrentOffset + 2);
    
    int arg_len = 0;
    if(*argType ==  FSE_ARG_DONE)
    {
        arg_len = 0x2;
    }
    else
    {
        arg_len = (4 + *argLen);
    }
    
    
    *ptrCurrentOffset += arg_len;
    
    //skip over rest of args
    while(arg_len > 2)
    {
        argType = (unsigned short*)(char*)(ptrBuffer + *ptrCurrentOffset);
        argLen  = (unsigned short*)(char*)(ptrBuffer + *ptrCurrentOffset + 2);
        
        //done length is 0x2
        if(*argType == FSE_ARG_DONE)
        {
            //set length
            arg_len = 0x2;
        }
        else
        {
            //for rename
            // ->only care about destination path (e.g. an OS atomic update/copy)
            //   so save *that* into 'path' var that's returned
            if( (FSE_RENAME == fse->type) &&
                (FSE_ARG_STRING == *argType) )
            {
                //save as path
                path = [NSString stringWithUTF8String:(const char*)(ptrBuffer + *ptrCurrentOffset + 4)];
            }
               
            //advance
            arg_len = (4 + *argLen);
        }
        
        //go to next arg
        *ptrCurrentOffset += arg_len;
    }
    
//bail
bail:
    
    return path;
}


@end
