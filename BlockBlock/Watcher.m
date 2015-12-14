//
//  Watcher.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Watcher.h"
#import "Logging.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "ProcessMonitor.h"
#import "Process.h"


//TODO: need [[NSNotificationCenter defaultCenter] removeObserver


@implementation Watcher

@synthesize watchItems;
@synthesize pluginMappings;
@synthesize watcherThread;
@synthesize runningApps;
@synthesize plugins;

//init function
// ->just alloc some dictionaries
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init plugin array
        plugins = [NSMutableArray array];
        
        //init mapping dictionary
        pluginMappings = [NSMutableDictionary dictionary];
        
        //init running apps dictionary
        runningApps = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//load watch list and enable watches
-(BOOL)watch
{
    //return var
    BOOL bRet = NO;
    
    //load watch list
    // ->files, plugin names etc
    if(YES != [self loadWatchList])
    {
        //err msg
        logMsg(LOG_ERR, @"loadWatchList() failed");
        
        //bail
        goto bail;
    }
    
    //init watcher thread
    self.watcherThread = [[NSThread alloc] initWithTarget:self selector:@selector(startWatch:) object:nil];
    
    //start it
    [self.watcherThread start];
    
    //TODO wait a bit until thread sets OK!?
    
    //no errors
    bRet = YES;

//bail
bail:

    return bRet;
}

//load the files/plugin from the config plist
-(BOOL)loadWatchList
{
    //return var
    BOOL bRet = NO;
    
    //path to watch list
    // ->plist w/ all plugins/info
    NSString* watchListPath = nil;
    
    //plugin obj
    PluginBase* plugin = nil;
    
    //get path to watch list
    watchListPath = [[NSBundle mainBundle] pathForResource:@"watchList" ofType:@"plist"];
    if(nil == watchListPath)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to load watch list path");
        
        //bail
        goto bail;
    }
    
    //load watch list
    self.watchItems = [[NSMutableArray alloc] initWithContentsOfFile:watchListPath];
    if(nil == self.watchItems)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to load watch list");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"watchlist: %@", self.watchItems]);
    
    //iterate over all watch items from plist
    // ->instantiate a plugin for each
    for(NSDictionary* watchItem in self.watchItems)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"watch item: %@/%@", watchItem, NSClassFromString(watchItem[@"class"])]);
        
        //init plugin
        // ->will also init paths
        plugin = [(PluginBase*)([NSClassFromString(watchItem[@"class"]) alloc]) initWithParams:watchItem];
        
        //save plugin
        [self.plugins addObject:plugin];
        
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added plugin: %@/%@", plugin, plugin.watchPaths]);
        
        //save plugin and files it can handle
        // ->note path's with '~' are skipped here as they are expanded at time of agent registration
        for(NSString* path in plugin.watchPaths)
        {
            //skip '~' path
            if(NSNotFound != [path rangeOfString:@"~/"].location)
            {
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"skipping plugin path: %@", path]);
                
                //skip
                continue;
            }
            
            //save mapping
            // ->key is path, value is plugin
            pluginMappings[path] = plugin;
        }
    }
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"registered plugins: %@", self.plugins]);

    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"plugin mappings: %@", self.pluginMappings]);
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;

}

//update the path to watch
// ->basically expands all '~'s into valid (registered) users
-(void)updateWatchedPaths:(NSMutableDictionary*)registeredAgents
{
    //expanded path
    NSString* expandedPath = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"updating watch paths");
    
    //update plugin mappings
    for(PluginBase* plugin in self.plugins)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"plugin: %@/%@", plugin, plugin.watchPaths]);
        
        //add all plugin's watch paths
        // -> paths with ~s are expanded into all registered users
        for(NSString* path in plugin.watchPaths)
        {
            //expand '~/' path
            if(NSNotFound != [path rangeOfString:@"~/"].location)
            {
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"expanding plugin path: %@", path]);
                
                //expand all
                for(NSNumber* key in registeredAgents)
                {
                    //init expanded path
                    expandedPath = [path stringByReplacingOccurrencesOfString:@"~" withString:registeredAgents[key][KEY_USER_HOME_DIR]];
                    
                    //save
                    pluginMappings[expandedPath] = plugin;
                }
            }
            
            //expand ~ at end
            // ->special case (cron jobs), replace w/ user name
            else if(YES == [path hasSuffix:@"~"])
            {
                //dbg msg
                logMsg(LOG_DEBUG, [NSString stringWithFormat:@"expanding plugin path: %@", path]);
                
                //expand all
                for(NSNumber* key in registeredAgents)
                {
                    //init expanded path
                    expandedPath = [path stringByReplacingCharactersInRange:NSMakeRange(path.length-1, 1) withString:registeredAgents[key][KEY_USER_NAME]];
                    
                    //save
                    pluginMappings[expandedPath] = plugin;
                }
            }
            
            //just save mapping
            // ->key is path, value is plugin
            else
            {
                //save
                pluginMappings[path] = plugin;
            }
        }
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updated watch list/plugin mappings: %@", pluginMappings]);
    
    return;
}


//TODO: close/kill thread on exit/disable?!?
//have to use fsevents directly since the FSEvents Framework doesn't give us the pID of the creator :/
//note: http://www.opensource.apple.com/source/xnu/xnu-2782.1.97/bsd/vfs/vfs_fsevents.c "Using /dev/fsevents directly is unsupported." - can ignore this warning
-(void)startWatch:(id)threadParam
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
    
    //path to file/dir
    NSString* path = nil;

    //watch event
    WatchEvent* watchEvent = nil;
    
    //plugin
    PluginBase* handlerPlugin = nil;
    
    //matched path
    NSMutableString* matchedPath = nil;
    
    //alloc buffer
    fsEvents = malloc(BUFSIZE);

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"file watcher thread off and running"]);
    
    //init matched path
    matchedPath = [NSMutableString string];
    
    //open the device
    if((fsed = open(DEVICE_FSEVENTS, O_RDONLY)) < 0)
    {
        //error msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to open %s", DEVICE_FSEVENTS]);
        
        //bail
        goto bail;
    }
    
    //explicity init all to FSE_IGNORE
    memset(events, FSE_IGNORE, FSE_MAX_EVENTS);
    
    //manualy report FSE_CREATE_FILE
    events[FSE_CREATE_FILE] = FSE_REPORT;
    
    //manualy report FSE_CREATE_DIR
    events[FSE_CREATE_DIR] = FSE_REPORT;
    
    //manualy report FSE_CONTENT_MODIFIED
    events[FSE_CONTENT_MODIFIED] = FSE_REPORT;
    
    //manualy report on renames
    events[FSE_RENAME] = FSE_REPORT;
    
    //manualy report on modifications
    events[FSE_CONTENT_MODIFIED] = FSE_REPORT;
    
    //clear out struct
    memset(&clonedArgs, 0x0, sizeof(clonedArgs));
    
    //set fs to the clone
    clonedArgs.fd = &cloned_fsed;
    
    //set depth
    // ->bumped this since events were being dropped
    clonedArgs.event_queue_depth = 512;
    
    //set list
    clonedArgs.event_list = events;
    
    //set size of list
    clonedArgs.num_events = FSE_MAX_EVENTS;
    
    //clone description
    if(ioctl(fsed, FSEVENTS_CLONE, &clonedArgs) < 0)
    {
        //err msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to clone fs descrption (via ioctl)"]);
        
        //bail
        goto bail;
    }
    
    //We no longer need original..
    close(fsed);
    
    //monitor forever
    while((bytesRead = read(cloned_fsed, fsEvents, BUFSIZE)) > 0)
    {
        //pool
        @autoreleasepool
        {

            
        //offset into buffer
        int bufferOffset = 0;
        
        //parse fs events
        while(bufferOffset < bytesRead)
        {
            //get pointer
            struct kfs_event_a *fse = (struct kfs_event_a *)(fsEvents + bufferOffset);
            
            //go to next event
            // ->returns path (from event data)
            path = [self advance2Next:fsEvents currentOffsetPtr:&bufferOffset];
            
            //skip blank paths
            if(nil == path)
            {
                //skip
                continue;
            }
            
            //skip if event was caused by self
            // ->e.g. blocking an item by editing a watched file
            if(getpid() == fse->pid)
            {
                //ignore
                continue;
            }
            
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got path: %@ (%x)", path, fse->type]);
            
            //find plugin that cares about the path/file that was just created
            handlerPlugin = [self findPlugin:path matchedPath:matchedPath];
            if(nil != handlerPlugin)
            {
                //create watch event
                // ->most logic deals with creating/mapping the process object
                watchEvent = [self createWatchEvent:path fsEvent:fse];
                
                //save handler plugin
                watchEvent.plugin = handlerPlugin;
                
                //save matched path
                // ->make a copy since matchedPath var is re-used
                watchEvent.match = [NSString stringWithString:matchedPath];
                
                //save item's binary
                // ->needed to match 'remembered' items
                watchEvent.itemObject = [watchEvent.plugin startupItemBinary:watchEvent];
                
                //allow the plugin to closely examine the event
                // ->it will know more about the details so can determine if it should be ignored
                if(YES != [handlerPlugin shouldIgnore:watchEvent])
                {
                    //dbg msg
                    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"NON-ignored watch event: %@", watchEvent]);
                    
                    //add to global queue
                    // ->this will trigger alert, and handling of event, etc
                    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).eventQueue enqueue:watchEvent];
                }
                //ignore
                else
                {
                    //dbg msg
                    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"plugin: %@, decided to ignore event", handlerPlugin]);
                }
                
            }//found plugin
        
        }//while parsing data
            
        //pool
        }
        
    }//while read events
    
//bail
bail:
    
    //free fs events buffer
    if(NULL != fsEvents)
    {
        //free
        free(fsEvents);
        fsEvents = NULL;
    }
    
    //should never exit
    // ->so log error here
    logMsg(LOG_ERR, @"fs event watcher thread is returning...not good!");
    
    return;
}

//create a watch event
// ->most of the logic is creating/finding the process object
-(WatchEvent*)createWatchEvent:(NSString*)path fsEvent:(kfs_event_a *)fsEvent
{
    //watch event
    WatchEvent* watchEvent = nil;
    
    //count var for loop
    NSUInteger count = 0;
    
    //buffer for call to proc_pidpath()
    char pidPath[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //info dictionary
    // ->passed to process init
    NSMutableDictionary* processInfo = nil;
    
    //global process list
    OrderedDictionary* processList = nil;
    
    //parent ID
    pid_t parentID = -1;
    
    //process (from dtrace or app callback)
    Process* processFromList = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"creating watch event for %@ (%d)", path, fsEvent->pid]);
    
    //init object for watch event
    watchEvent = [[WatchEvent alloc] init];
    
    //add path
    watchEvent.path = path;
    
    //add flags
    watchEvent.flags = fsEvent->type;
    
    //try get parent
    parentID = getParentID(fsEvent->pid);
    
    //grab global process list
    processList = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList;
    
    //get process path
    // ->will fail if process exited (this is handled in 'else' clause below)
    if(0 != proc_pidpath(fsEvent->pid, pidPath, PROC_PIDPATHINFO_MAXSIZE))
    {
        //alloc process info dictionary
        processInfo = [[NSMutableDictionary alloc] init];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got path from pid: %s", pidPath]);
        
        //set path
        processInfo[@"path"] = [NSString stringWithUTF8String:pidPath];
        
        //set parent
        processInfo[@"ppid"] = [NSNumber numberWithInt:parentID];
        
        //try see if process monitor(s) grabbed it too
        // ->they have more info, so preferred to use that
        do
        {
            //always sync
            @synchronized(processList)
            {
                //try lookup/set process object from process monitor's list
                processFromList = [processList objectForKey:[NSNumber numberWithUnsignedInteger:fsEvent->pid]];
                    
                //check if we got one
                if(nil != processFromList)
                {
                    //bail
                    break;
                }
            }
            
            //nap for 1/10th of a second
            [NSThread sleepForTimeInterval:WAIT_INTERVAL];
            
        //try up to a 1.1 second
        } while(count++ < 1.1/WAIT_INTERVAL);
        
        //hopefully (now) found one in process monitor list...
        if(nil != processFromList)
        {
            //dbg msg
            //logMsg(LOG_DEBUG, @"using process from process monitor(s)");
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"proc from list %@", processFromList]);
            
            //just use that one
            watchEvent.process = processFromList;
        }
        
        //create one just with pid/path
        else
        {
            //dbg msg
            //logMsg(LOG_DEBUG, @"not found in process list, so creating just with pid/path");
            
            //create process object
            watchEvent.process = [[Process alloc] initWithPid:fsEvent->pid infoDictionary:processInfo];
        }
        
    }//got pid from path
    
    //couldn't get path (process likely already exit'ed)
    // ->try lookup from process list (contains process objects from dtrace, etc)
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to get path from pid %d...will lookup from process monitor", fsEvent->pid]);
        
        //try get process for one of the process monitor
        // ->do in loop since they might be buffering/processing
        do
        {
            //always sync
            @synchronized(processList)
            {
                //try lookup/set process object from process monitor's list
                watchEvent.process = [processList objectForKey:[NSNumber numberWithUnsignedInteger:fsEvent->pid]];
            }
            
            //check if we got one
            if(nil != watchEvent.process)
            {
                //bail
                break;
            }
        
            //nap for 1/10th of a second
            [NSThread sleepForTimeInterval:WAIT_INTERVAL];
            
        //try up to 1 second
        } while(count++ < 1.1f/WAIT_INTERVAL);
        
        //if lookup (still) failed
        // ->just create a process object with only a pid/ppid :/
        if(nil == watchEvent.process)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to find process (%d) in %@", fsEvent->pid, [processList description]]);
            
            //create process object
            watchEvent.process = [[Process alloc] initWithPid:fsEvent->pid infoDictionary:@{@"ppid": [NSNumber numberWithInt:parentID]}];
        }
    }
    
    return watchEvent;
}

//skip over args to get to next event struct
-(NSString*)advance2Next:(unsigned char*)ptrBuffer currentOffsetPtr:(int*)ptrCurrentOffset
{
    //path
    NSString* path = nil;
    
    struct kfs_event_a *fse = (struct kfs_event_a *)(unsigned char*)((unsigned char*)ptrBuffer + *ptrCurrentOffset);
    
    
    struct kfs_event_arg *fse_arg;
    
    //handle dropped events
    if(fse->type == FSE_EVENTS_DROPPED)
    {
        //err msg
        logMsg(LOG_ERR, @"file-system events dropped by kernel");
        
        //advance to next
        *ptrCurrentOffset += sizeof(kfs_event_a) + sizeof(fse->type);
        
        //exit early
        return nil;
    }
    
    *ptrCurrentOffset += sizeof(struct kfs_event_a);
    
    fse_arg = (struct kfs_event_arg *)&ptrBuffer[*ptrCurrentOffset];
    
    //save path
    path = [NSString stringWithUTF8String:fse_arg->data];
    
    //skip over path
    *ptrCurrentOffset += sizeof(kfs_event_arg) + fse_arg->pathlen ;
    
    unsigned short *argType = (unsigned short *)(unsigned char*)((unsigned char*)ptrBuffer + *ptrCurrentOffset);
    unsigned short *argLen   = (unsigned short *) (ptrBuffer + *ptrCurrentOffset + 2);
    
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
    while (arg_len > 2)
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
                //dbg msg
                //logMsg(LOG_DEBUG, @"RENAME/FSE_ARG_STRING");
                
                //save as path
                path = [NSString stringWithUTF8String:(const char*)(ptrBuffer + *ptrCurrentOffset + 4)];
            }
               
            
            arg_len = (4 + *argLen);
        }
        
        //go to next arg
        *ptrCurrentOffset += arg_len;
    }
    
    
    return path;
}

//given a path, scan the plugin mappings dictionary for match
// ->after full path is checked, path's directories are checked...
-(PluginBase*)findPlugin:(NSString*)path matchedPath:(NSMutableString*)matchedPath
{
    //plugin that can handle path
    PluginBase* handlerPlugin = nil;
    
    //stripped path
    NSString* strippedPath = nil;

    //directory flag
    BOOL isDirectory = NO;
    
    //init stripped path
    strippedPath = [NSMutableString stringWithString:path];
    
    //attempt to find path match
    // ->starts with full path and goes up until '/' searching for match
    //   note: if the plugin doesn't want non-recusive matches, stripped path might be ignored
    do
    {
        //sanity check(s)
        // ->blank/non-existing paths should bail out of loop
        if( (nil == strippedPath) ||
            (YES == [strippedPath isEqualToString:@""]))
        {
            //bail
            break;
        }
        
        //check for match
        // ->key is path
        if(nil != [self.pluginMappings objectForKey:strippedPath])
        {
            /* FOUND MATCH */
            
            //if match is a file
            // ->no need to check anything else (e.g. ignore kids etc)
            if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:strippedPath isDirectory:&isDirectory]) &&
                (YES != isDirectory) )
            {
                //dbg msg
                //logMsg(LOG_DEBUG, @"plugin doesn't need exact match (sub match is ok)");
                
                //extract plugin
                handlerPlugin = self.pluginMappings[strippedPath];
                
                //save matched path
                [matchedPath setString:strippedPath];
                
                //all set
                // ->so exit loop
                break;
                
            }
            
            //dbg msg
            //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"matched: %@ (%@)", strippedPath, path]);
            
            //if plugin doesn't care about sub files/dir
            // ->need a top-level match
            if(YES == ((PluginBase*)self.pluginMappings[strippedPath]).ignoreKids)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"plugin only cares about top-level matches");
                
                //check if original path, minus last directory, is what we just matched
                // ->if so, this means we have a top level match
                if(YES == [[path stringByDeletingLastPathComponent] isEqualToString:strippedPath])
                {
                    //dbg msg
                    logMsg(LOG_DEBUG, @"got exact match");
                    
                    //extract plugin
                    handlerPlugin = self.pluginMappings[strippedPath];
                    
                    //save matched path
                    [matchedPath setString:strippedPath];
                    
                    //bail
                    break;
                }
            }
            //got a match
            // ->don't care if its on a sub file or directory
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"plugin doesn't need exact match (sub match is ok)");

                //extract plugin
                handlerPlugin = self.pluginMappings[strippedPath];
                
                //save matched path
                [matchedPath setString:strippedPath];
            
                //bail
                break;
            }
        }
    
        //strip off last dir
        // ->allows to try again
        strippedPath = [strippedPath stringByDeletingLastPathComponent];
    
    //scan until path has been fully stripped (e.g. its just '/')
    } while(YES != [strippedPath isEqualToString:@"/"]);
    
    return handlerPlugin;
}

@end
