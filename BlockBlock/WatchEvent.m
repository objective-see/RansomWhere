//
//  WatchEvent.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Signing.h"
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
@synthesize itemObject;
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
    // ->differnt paths
    //   ...i think this is ok to do, since plugins really closely check for exact match
    if(YES != [self.path isEqualToString:newWatchEvent.path])
    {
        //nope!
        return NO;
    }
    
    //events appear to be related
    return YES;
}

//determines if a new watch event matches a prev. 'remembered' event
// ->checks process (path), startup item path and item (binary or cmd)
-(BOOL)matchesRemembered:(WatchEvent*)rememberedEvent
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is remembered (%@)", self, rememberedEvent]);
    #endif
    
    //check 1:
    // ->different startup item path
    if(YES != [self.path isEqualToString:rememberedEvent.path])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"path %@ != %@", self.path, rememberedEvent.path]);
        #endif
        
        //nope!
        return NO;
    }
    
    //check 2:
    // ->different startup item binary/cmd
    if(YES != [self.itemObject isEqualToString:rememberedEvent.itemObject])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"binary %@ != %@", self.itemObject, rememberedEvent.itemObject]);
        #endif
        
        //nope!
        return NO;
    }
    
    //check 3:
    // ->different process
    if(YES != [self.process.path isEqualToString:rememberedEvent.process.path])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process path %@ != %@", self.process.path, rememberedEvent.process.path]);
        #endif
        
        //nope!
        return NO;
    }
    
    //appears to match
    return YES;
}

//matches a white-listed event
// ->checks process (path), startup item path, item (binary or cmd), and UID
-(BOOL)matchesWhiteListed:(NSDictionary*)whitelistedEvent
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking if %@ is whitelisted (%@)", self, whitelistedEvent]);
    #endif
    
    //check 1:
    // ->different startup item path
    if(YES != [self.path isEqualToString:whitelistedEvent[@"itemPath"]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"path %@ != %@", self.path, whitelistedEvent[@"itemPath"]]);
        #endif
        
        //nope!
        return NO;
    }
    
    //check 2:
    // ->different startup item binary/cmd
    if(YES != [self.itemObject isEqualToString:whitelistedEvent[@"itemObject"]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"binary %@ != %@", self.itemObject, whitelistedEvent[@"itemObject"]]);
        #endif
        
        //nope!
        return NO;
    }
    
    //check 3:
    // ->different process
    if(YES != [self.process.path isEqualToString:whitelistedEvent[@"processPath"]])
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process path %@ != %@", self.process.path, whitelistedEvent[@"processPath"]]);
        #endif
        
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
    
    //signing info
    NSDictionary* signingInfo = nil;
    
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
    
    //TODO: check for nil!!!!
    //get signing info for process
    signingInfo = extractSigningInfo(self.process.path);
    switch([signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //happily signed
        case noErr:
            
            //item signed by apple
            if(YES == [signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
            {
                //set icon
                alertInfo[@"signingIcon"] = @"signedApple";
                
                //set details
                alertInfo[@"processSigning"] = @"Apple Code Signing Cert Auth";
            }
            //signed by dev id/ad hoc, etc
            else
            {
                //set icon
                alertInfo[@"signingIcon"] = @"signed";
                
                //set signing auth
                if(0 != [signingInfo[KEY_SIGNING_AUTHORITIES] count])
                {
                    //add code-signing auth
                    alertInfo[@"processSigning"] = [signingInfo[KEY_SIGNING_AUTHORITIES] firstObject];
                }
                //no auths
                else
                {
                    //no auths
                    alertInfo[@"processSigning"] = @"no signing authorities (ad hoc?)";
                }
            }
            
            break;
            
        //unsigned
        case errSecCSUnsigned:
            
            //set icon
            alertInfo[@"signingIcon"] = @"unsigned";
            
            //set details
            alertInfo[@"processSigning"] = @"unsigned";
            
            break;
            
        default:
            
            //set icon
            alertInfo[@"signingIcon"] = @"unknown";
            
            //set details
            alertInfo[@"processSigning"] = [NSString stringWithFormat:@"unknown (status/error: %ld)", (long)[signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
    }

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
    if(nil != self.itemObject)
    {
        //set
        alertInfo[@"itemBinary"] = self.itemObject;
    }
    //when still nil
    // ->lookup
    else
    {
        //lookup
        alertInfo[@"itemBinary"] = [self valueForStringItem:[self.plugin startupItemBinary:self]];
    }
    
    //generate signing info for item binary
    // ->but only if its a file (binary), not a cmd
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:alertInfo[@"itemBinary"]])
    {
        //get signing info
        signingInfo = extractSigningInfo(alertInfo[@"itemBinary"]);
        switch([signingInfo[KEY_SIGNATURE_STATUS] intValue])
        {
            //happily signed
            // ->check if apple, or 3rd-party
            case noErr:
                
                //item signed by apple
                if(YES == [signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
                {
                    //set
                    alertInfo[@"itemSigning"] = @"Apple Code Signing Cert Auth";
                }
                //signed by dev id/ad hoc, etc
                else
                {
                    //set signing auth
                    if(0 != [signingInfo[KEY_SIGNING_AUTHORITIES] count])
                    {
                        //add code-signing auth
                        alertInfo[@"itemSigning"] = [signingInfo[KEY_SIGNING_AUTHORITIES] firstObject];
                    }
                    //no auths
                    else
                    {
                        //no auths
                        alertInfo[@"itemSigning"] = @"no signing authorities (ad hoc?)";
                    }
                }
                
                break;
                
            //unsigned
            case errSecCSUnsigned:
                
                //set
                alertInfo[@"itemSigning"] = @"unsigned";
                
                break;
                
            default:
                
                //set details
                alertInfo[@"itemSigning"] = [NSString stringWithFormat:@"unknown (status/error: %ld)", (long)[signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
        }
    }
    
    //add process pid
    alertInfo[@"parentID"] = [NSString stringWithFormat:@"%d", self.process.ppid];
    
    //init/add process hierarchy
    alertInfo[@"processHierarchy"] = [self buildProcessHierarchy];
    
    //dbg msg
    // ->here since don't want to print out icon!
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"ALERT INFO dictionary: %@", alertInfo]);
    #endif
    
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
    
    //extract name from process obj
    if(nil != parentProcessObj)
    {
        //save name
        if( (nil != parentProcessObj.name) &&
            (0 != parentProcessObj.name.length) )
        {
            //name
            parentProcess[@"name"] = parentProcessObj.name;
        }
        //not known
        // ->just set to 'unknown'
        else
        {
            //dunno
            parentProcess[@"name"]  = @"unknown";
        }
    }
    //look it up manually
    else
    {
        //get path from pid
        if(0 != proc_pidpath(parentID, parentPath, PROC_PIDPATHINFO_MAXSIZE))
        {
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
                //k-task
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

//build an array of processes ancestry
// ->start with process and go 'back' till initial ancestor (likely kernel_task or launchd)
-(NSMutableArray*)buildProcessHierarchy
{
    //process hierarchy
    NSMutableArray* processHierarchy = nil;
    
    //dictionary for process hierarchy
    NSMutableDictionary* parentProcessInfo = nil;
    
    //current process id
    pid_t processID = -1;
    
    //current process name
    NSString* processName = nil;
    
    //alloc list for process hierarchy
    processHierarchy = [NSMutableArray array];
    
    //start with current process
    // ->pid
    processID = self.process.pid;
    
    //start with current process
    // ->name
    processName = self.process.name;
    
    //sanity check
    // ->when current process doesn't have a name, init to 'unknown'
    if( (nil == processName) ||
        (0 == processName.length) )
    {
        //dunno
        processName = @"unknown";
    }
    
    //add current process (leaf)
    // ->other processes (parents) are added at front...
    [processHierarchy addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:self.process.pid], @"pid", processName, @"name", nil]];
  
    //add until we get to to root (kernel_task)
    // ->or error out
    while(YES)
    {
        //get parent process
        parentProcessInfo = [self getParentProcess:processID];
        
        //bail if parent process is nil
        // ->or if process pid matches parent
        if( (nil == parentProcessInfo) ||
            (0 == parentProcessInfo.count) ||
            (processID == [parentProcessInfo[@"pid"] intValue]) )
        {
            //bail
            break;
        }
        
        //add parent process
        // ->always at front
        [processHierarchy insertObject:parentProcessInfo atIndex:0];
        
        //now
        // ->get parent's process id as current pid
        processID = [parentProcessInfo[@"pid"] intValue];
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"processHierarchy %@", processHierarchy]);
    #endif
    
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
    return [NSString stringWithFormat: @"process=%@, item file path=%@, flags=%lx, timestamp=%@, item binary=%@", self.process, self.path, (unsigned long)self.flags, self.timestamp, self.itemObject];
}


@end
