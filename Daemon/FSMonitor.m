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

#import <Foundation/Foundation.h>

//directories to watch
// ->for now, anything under a user directory...
NSString* const BASE_WATCH_PATHS[] = {@"~", @"/Users/Shared"};

@implementation FSMonitor

@synthesize eventQueue;
@synthesize pidPathMappings;
@synthesize watchDirectories;

//init function
// ->load watch paths, alloc queue, etc
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init watch directories
        // ->expands, saves into iVar, etc
        [self initWatchDirectories];
        
        //alloc/init event queue
        eventQueue = [[Queue alloc] init];
        
        //alloc/init pid -> path mappings
        pidPathMappings = [NSMutableDictionary dictionary];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"watching %@, for encrypted files", self.watchDirectories]);
        #endif
        
    }
    
    return self;
}

//initialize paths to watch
// ->expands '~'s in paths, as needed
-(void)initWatchDirectories
{
    //all user home directories
    NSMutableArray* homeDirectories = nil;
    
    //init array
    watchDirectories = [NSMutableSet set];
    
    //get all user home directories
    homeDirectories = getUserHomeDirs();
    
    //add each watch path
    // ->note: extra logic is needed to expand each `~` into current user
    for(NSUInteger i=0; i<sizeof(BASE_WATCH_PATHS)/sizeof(BASE_WATCH_PATHS[0]); i++)
    {
        //non '~' paths
        // ->just add
        if(NSNotFound == [BASE_WATCH_PATHS[i] rangeOfString:@"~"].location)
        {
            //add
            [self.watchDirectories addObject:BASE_WATCH_PATHS[i]];
        }
        //otherwise
        // ->expand path (replacing '~' with each user's home directory)
        else
        {
            //add each user home directory
            for(NSString* homeDirectory in homeDirectories)
            {
                //add
                [self.watchDirectories addObject:[BASE_WATCH_PATHS[i] stringByReplacingOccurrencesOfString:@"~" withString:homeDirectory]];
            }
        }
    
    }//all paths
    
    return;
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
                #ifdef DEBUG
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"skipping event, as its same as last (%@)", path]);
                #endif
                
                //skip
                continue;
            }
            
            //update
            lastPath = path;
            
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new file system event: %@ (type: %x/ pid: %d)", path, fse->type, fse->pid]);
            
            //skip any non-watched paths
            if(YES != [self isWatched:path])
            {
                //skip
                continue;
            }
            
            //check process
            // ->make new process object if needed
            binary = [self getBinaryObject:fse->pid];
            if(nil == binary)
            {
                //skip
                continue;
            }
            
            //don't process if there is no logged in user
            // ->could have this check earlier, but want binary objects to be gen'd
            if(NULL == consoleUserName)
            {
                //skip
                continue;
            }

            //create event object
            event = [[Event alloc] init:path binary:binary fsEvent:fse];
            if(nil == event)
            {
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
    
    return;
}

//try find existing binary obj
// ->makes new one if that's needed
-(Binary*)getBinaryObject:(pid_t)pid
{
    //binary object
    Binary* binary = nil;
    
    //pid->path mapping dictionary
    NSMutableDictionary* pidProcMapping = nil;
    
    //process path
    NSString* processPath = nil;
    
    //check if there is a valid ('cached') pid->path mapping
    // ->will be for recent existing procs (for now, 60 seconds)
    pidProcMapping = [self.pidPathMappings objectForKey:[NSNumber numberWithUnsignedInt:pid]];
    if( (nil != pidProcMapping) &&
        ([pidProcMapping[@"timestamp"] timeIntervalSinceNow] < 60) )
    {
        //extract path
        processPath = pidProcMapping[@"path"];
    }
    //otherwise, new binary, or time interval too long
    // ->lookup process path & save it into pid->path mapping
    else
    {
        //get path from pid
        processPath = getProcessPath(pid);
        if(nil == processPath)
        {
            //ignore
            goto bail;
        }
        
        //save ('cache') pid->path mapping
        [self.pidPathMappings setObject:@{@"timestamp": [NSDate date], @"path": processPath} forKey:[NSNumber numberWithUnsignedInt:pid]];
    }
    
    //see if there's an existing process object
    // ->if so, all set, so can bail to return binary to caller
    binary = binaryList[processPath];
    if(nil != binary)
    {
        //all set
        goto bail;
    }

    /*
    //new process
    // ->suspend it so have time to create binary object
    if(-1 == kill(pid, SIGSTOP))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to suspend (%d) %@, with %d", pid, processPath, errno]);
        
        //don't bail though
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"suspended %@, now creating binary object for it", processPath]);
    #endif
    */
     
    //create binary object
    binary = [[Binary alloc] init:processPath attributes:nil];
    
    //sync to add
    @synchronized(binaryList)
    {
        //add
        binaryList[binary.path] = binary;
    }
    
    /*
    //resume process
    if(-1 == kill(pid, SIGCONT))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to resume (%d) %@, with %d", pid, processPath, errno]);
        
        //don't bail though
    }
    */
    
//bail
bail:
    
    return binary;
}

//determine if a path is, or is under a watched path
-(BOOL)isWatched:(NSString*)path
{
    //flag
    BOOL watched = NO;
    
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
            goto bail;
        }
    }
        
    //then check all watch paths
    for(NSString* watchDirectory in self.watchDirectories)
    {
        //check if path is being watched
        if(YES == [path hasPrefix:watchDirectory])
        {
            //yups
            watched = YES;
            
            //bail
            break;
        }
    }
    
//bail
bail:
    
    return watched;
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
        
        if(*argType == FSE_ARG_DONE)
        {
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
