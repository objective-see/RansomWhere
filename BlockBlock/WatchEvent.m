//
//  WatchEvent.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "PluginBase.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "ProcessMonitor.h"
#import "OrderedDictionary.h"
#import "Process.h"
#import "Utilities.h"




@implementation WatchEvent

@synthesize path;
@synthesize uuid;
@synthesize flags;
@synthesize match;
@synthesize plugin;
@synthesize process;
@synthesize timestamp;
@synthesize itemBinary;
@synthesize wasBlocked;
@synthesize reportedUID;
@synthesize shouldRemember;



//init
-(id)init
{
    self = [super init];
    if(self)
    {
        //create a uuid
        uuid = [NSUUID UUID];
        
        //create timestamp
        timestamp = [NSDate date];
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created watch ID with %@", self.uuid]);
    }
    
    return self;
}

//determines if a (new) watch event is related
// ->checks things like process ids, plugins, paths, etc
-(BOOL)isRelated:(WatchEvent*)newWatchEvent
{
    //case 1:
    // ->different processes mean unrelated watch events
    if(self.process.pid != newWatchEvent.process.pid)
    {
        //nope!
        return NO;
    }
    
    //case 2:
    // ->different plugins mean unrelated watch events
    if(self.plugin != newWatchEvent.plugin)
    {
        //nope!
        return NO;
    }
    
    //case 3:
    // ->10s between now and last watch event means unrelated watch events
    if(10 <= [[NSDate date] timeIntervalSinceDate:self.timestamp])
    {
        //nope!
        return NO;
    }

    
    //case 4:
    // ->watch items paths aren't related means unrelated watch events
    // TODO: use 'in directory' code - google this!
    // check both paths to make sure a isn't in b and b isn't in a
    
    
    
    //events appear to be related
    return YES;
}

//determines if a new watch event matches a prev. 'remembered' event
// ->checks path and item
//   TODO: cron jobs don't have an item binary? or wait, maybe that's what's overloaded to hold ext?
-(BOOL)matchesRemembered:(WatchEvent*)rememberedEvent
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is remembered", rememberedEvent]);
    
    //check 1:
    // ->different startup item path
    if(YES != [self.path isEqualToString:rememberedEvent.path])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"path %@ != %@", self.path, rememberedEvent.path]);
        
        //nope!
        return NO;
    }
    
    //check 2:
    // ->different startup item binary
    if(YES != [self.itemBinary isEqualToString: rememberedEvent.itemBinary])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"binary %@ != %@", self.itemBinary, rememberedEvent.itemBinary]);
        
        //nope!
        return NO;
    }
    
    //appears to match
    return YES;
}

//takes a watch event and creates an alert dictionary that's serializable into a plist
// ->needed since notification framework can only handle dictionaries of this kind
-(NSMutableDictionary*)createAlertDictionary
{
    //watch event as dictionary
    NSMutableDictionary* alertInfo = nil;
    
    //alloc dictionary
    alertInfo = [NSMutableDictionary dictionary];
    
    //save watch item ID
    alertInfo[KEY_WATCH_EVENT_UUID] = [self.uuid UUIDString];
    
    //add plugin type
    // ->allows for alert info customization
    alertInfo[@"pluginType"] = [NSNumber numberWithUnsignedInteger:self.plugin.type];
    
    /* for top of alert window */
    
    //add process label
    alertInfo[@"processLabel"]  = [self valueForStringItem:self.process.name];
    
    //add alert msg
    alertInfo[@"alertMsg"] = [self valueForStringItem:self.plugin.alertMsg];
    
    /* for bottom of alert window */
    
    //add process name
    alertInfo[@"processName"] = [self valueForStringItem:self.process.name];
    
    //add process pid
    alertInfo[@"processID"] = [NSString stringWithFormat:@"%d", self.process.pid];
    
    //add full path to process
    alertInfo[@"processPath"] = [self valueForStringItem:self.process.path];
    
    //set name of startup item
    alertInfo[@"itemName"] = [self valueForStringItem:[self.plugin startupItemName:self]];
        
    //set file of startup item
    alertInfo[@"itemFile"] = [self valueForStringItem:self.path];
    
    //set binary (path) of startup item
    // ->when already set, can just use that
    if(nil != self.itemBinary)
    {
        //set
        alertInfo[@"itemBinary"] = self.itemBinary;
    }
    //when still nil
    // ->lookup
    else
    {
        //lookup
        alertInfo[@"itemBinary"] = [self valueForStringItem:[self.plugin startupItemBinary:self]];
    }
    
    //add process pid
    alertInfo[@"parentID"] = [NSString stringWithFormat:@"%d", self.process.ppid];
    
    //init/add process hierarchy
    alertInfo[@"processHierarchy"] = [self buildProcessHierarchy];
    
    //dbg msg
    // ->here since don't want to print out icon!
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"ALERT INFO dictionary: %@", alertInfo]);
    
    //finally add icon
    // note: don't try to log this!
    alertInfo[@"processIcon"] = [[self.process getIconForProcess] TIFFRepresentation];
    
    return alertInfo;
}

//get parent process
// ->return dictionary with pid and name
-(NSMutableDictionary*)getParentProcess:(pid_t)processID
{
    //dictionary for process hierarchy
    NSMutableDictionary* parentProcess = nil;
    
    //child process object
    Process* childProcessObj = nil;
    
    //process
    Process* parentProcessObj = nil;
    
    //parent pid
    pid_t parentID = -1;
    
    //buffer for call to proc_pidpath()
    char parentPath[PROC_PIDPATHINFO_MAXSIZE+1] = {0};
    
    //init dictionary
    parentProcess = [NSMutableDictionary dictionary];
    
    //first try existing process from process list
    childProcessObj = [((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList objectForKey:[NSNumber numberWithInt:processID]];
    
    //extract ppid from child in process list
    if(nil != childProcessObj)
    {
        //extract
        parentID = childProcessObj.ppid;
    }
    //look it up manually
    else
    {
        //try find parent pid
        parentID = getParentID(processID);
    }
    
    //sanity check
    // ->make sure a parent was found
    if(-1 == parentID)
    {
        //bail
        goto bail;
    }
    
    //save parent pid
    parentProcess[@"pid"] = [NSNumber numberWithInt:parentID];
    
    //try find parent in existing process list
    // ->need name/path
    parentProcessObj = [((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList objectForKey:[NSNumber numberWithInt:parentID]];
    
    //extract ppid/name from process obj
    if(nil != parentProcessObj)
    {
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got parent process from list: %@", parentProcessObj]);
        
        //name
        parentProcess[@"name"] = parentProcessObj.name;
        
    }
    //look it up manually
    else
    {
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"didn't find %d, looking up manually", processID]);
        
        //get path from pid
        if(0 != proc_pidpath(parentID, parentPath, PROC_PIDPATHINFO_MAXSIZE))
        {
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"pidPath %s", parentPath]);
            
            //save name
            // ->since 'proc_pidpath()' returns full path strip to get name
            parentProcess[@"name"] = [[NSString stringWithUTF8String:parentPath] lastPathComponent];
        }
        //failed to get path
        else
        {
            //pid 0 is special case
            // ->just set it to 'kernel_task'
            if(0 == parentID)
            {
                //dunno
                parentProcess[@"name"]  = @"kernel_task";
            }
            //couldn't find
            // ->just set to 'unknown'
            else
            {
                //dunno
                parentProcess[@"name"]  = @"unknown";
            }
        }
                              
    }//manual lookup
    
//bail
bail:
    
    return parentProcess;
}

                            
-(NSMutableArray*)buildProcessHierarchy
{
    //process hierarchy
    NSMutableArray* processHierarchy = nil;
    
    //dictionary for process hierarchy
    NSMutableDictionary* parentProcessInfo = nil;
    
    //current process id
    pid_t processID = -1;
    
    //alloc list for process hierarchy
    processHierarchy = [NSMutableArray array];
    
    //start with leaf process
    processID = self.process.pid;
    
    //add current (leaf) process
    // ->always at front
    [processHierarchy insertObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:self.process.pid], @"pid", self.process.name, @"name", nil] atIndex:0];
  
    //add until we get to to root (kernel_task)
    // ->or error out
    while(YES)
    {
        //get parent process
        parentProcessInfo = [self getParentProcess:processID];
        
        //bail if parent process is nil
        // ->or if process pid matches parent
        if( (nil == parentProcessInfo) ||
            (processID == [parentProcessInfo[@"pid"] intValue]) )
        {
            //bail
            break;
        }
        
        //add info
        // ->always at front
        [processHierarchy insertObject:parentProcessInfo atIndex:0];
        
        //get parent's process id
        processID = [parentProcessInfo[@"pid"] intValue];
    }
    
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"FINAL processHierarchy %@", processHierarchy]);
    
    //add the index value to each process in the hierarchy
    // ->used to populate outline/table
    for(NSUInteger i = 0; i<processHierarchy.count; i++)
    {
        //set index
        processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
    }
    
    return processHierarchy;
}


//check if something is nil
// ->if so, return a default ('unknown') value
-(NSString*)valueForStringItem:(NSString*)item
{
    //return value
    NSString* value = nil;
    
    //check if item is nil
    if(nil != item)
    {
        //just set to item
        value = item;
    }
    else
    {
        //set to default
        value = @"unknown";
    }
    
    return value;
}

//for pretty print
-(NSString *)description {
    return [NSString stringWithFormat: @"process=%@, item file path=%@, flags=%lx, timestamp=%@, item binary=%@", self.process, self.path, (unsigned long)self.flags, self.timestamp, self.itemBinary];
}


@end
