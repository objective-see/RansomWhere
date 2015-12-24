//
//  LoginItem.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "LoginItem.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "ProcessMonitor.h"
#import "OrderedDictionary.h"
#import "Process.h"



@implementation LoginItem

//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    if(nil != self)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"init'ing %@ (%p)", NSStringFromClass([self class]), self]);
        
        //set type
        self.type = PLUGIN_TYPE_LOGIN_ITEM;
    }

    return self;
}


//take a closer look to make sure watch event is really one we care about
// for login items, it's (for now) the modification/rename of login items .plist file
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    //flag
    // ->default to ignore
    BOOL shouldIgnore = YES;
    
    //rename or modification of file
    // ->OS does a rename
    if( (FSE_CREATE_FILE == watchEvent.flags) ||
        (FSE_RENAME == watchEvent.flags) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ has 'FSE_CREATE_FILE/FSE_RENAME' set (not maybe ignoring)", watchEvent.path]);
        
        //only care about new login items
        // ->(might be another file edits which are ok to ignore)
        if(nil != [self findLoginItem:watchEvent])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"found new login item, so NOT IGNORING");
            
            //don't ignore
            shouldIgnore = NO;
            
            //TODO: save this in watch event when later don't have to re-lookup (avoids race cond)
        }
    }
    //dbg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%lu is a flag the %@ plugin doesn't care about....", (unsigned long)watchEvent.flags, NSStringFromClass([self class])]);
    }
    
    //if ignoring
    // ->still update originals
    if(YES == shouldIgnore)
    {
        //update
        [self updateOriginals:watchEvent.path];
    }
    
    return shouldIgnore;
}


//invoked when user clicks 'allow'
-(void)allow:(WatchEvent *)watchEvent
{
    //just update originals
    [self updateOriginals:watchEvent.path];
    
    return;
}

//update original login items for new user
-(void)newAgent:(NSDictionary*)newUser
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"LOGIN ITEMS, handling new agent %@/%@", newUser, self.watchPaths]);
    
    //iterate over plugin's watch paths
    // ->any that are user specific (~) save original login items for new user
    for(NSString* watchPath in self.watchPaths)
    {
        //save user specific (~) originals
        if(YES == [watchPath hasPrefix:@"~"])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"LOGIN ITEMS, saving orginals for %@", watchPath]);

            //matched
            // ->save orginals
            [self updateOriginals:[watchPath stringByReplacingOccurrencesOfString:@"~" withString:newUser[KEY_USER_HOME_DIR]]];
        }
    }
    //check if its a user path
    // ->then update originals
    //if(YES == [watchPath hasPrefix:@"~"])
    //{
    //update
    //[self updateOriginals:[watchPath stringByReplacingOccurrencesOfString:@"~" withString:homeDirectory]];
    //}
    //}


    
    
    //[self updateOriginals:[watchPath stringByReplacingOccurrencesOfString:@"~" withString:homeDirectory]];
    
    //iterate over all users
    // ->save current login items
    //for(NSNumber* userID in newUser)
    //{
        //extract home directory
        //homeDirectory = //newUserregisteredUsers[userID][KEY_USER_HOME_DIR];
        
        //iterate over all watch paths to find those that belong to user
        //for(NSString* watchPath in self.watchPaths)
        //{
            //check if its a user path
            // ->then update originals
            //if(YES == [watchPath hasPrefix:@"~"])
            //{
                //update
                //[self updateOriginals:[watchPath stringByReplacingOccurrencesOfString:@"~" withString:homeDirectory]];
            //}
        //}
    //}
    
    return;
}


//update originals
// ->ensures there is always the latest version of the (pristine) login items saved
-(void)updateOriginals:(NSString*)path
{
    //user's login items
    NSDictionary* loginItems = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating orginals of user's login items at: %@", path]);
    
    //load login items
    loginItems = [NSDictionary dictionaryWithContentsOfFile:path];
    
    //save em
    if(nil != loginItems)
    {
        //load into originals
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).orginals setObject:loginItems forKey:path];
    }

    return;
}

//find's latest login item
// ->diff's original list of login items with current ones
-(NSDictionary*)findLoginItem:(WatchEvent*)watchEvent
{
    //info about latest login item
    NSMutableDictionary* newLoginItem = nil;
    
    //plist data
    NSDictionary* plistData = nil;
    
    //original login items
    NSMutableDictionary* originalLoginItems = nil;
    
    //current login items
    NSMutableDictionary* currentLoginItems = nil;
    
    //set of new login items
    // ->should only be 1!
    NSMutableSet *newLoginItems = nil;
    
    //name of new login item
    NSString* newLoginItemName = nil;
    
    //'alias' data
    NSData* aliasData = nil;
    
    //login item path
    NSString* loginItemPath = nil;
    
    //alloc
    newLoginItem = [NSMutableDictionary dictionary];
    
    //alloc
    originalLoginItems = [NSMutableDictionary dictionary];
    
    //alloc
    currentLoginItems = [NSMutableDictionary dictionary];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"ORIGINALS: %@", ((AppDelegate*)[[NSApplication sharedApplication] delegate]).orginals]);
    
    //grab original login items
    plistData = [((AppDelegate*)[[NSApplication sharedApplication] delegate]).orginals objectForKey:watchEvent.path];
    
    //parse out original login items
    for(NSDictionary* loginItem in plistData[@"SessionItems"][@"CustomListItems"])
    {
        //save
        originalLoginItems[loginItem[@"Name"]] = loginItem;
    }
    
    //load current login items
    // ->path to file is in watch event
    plistData = [NSDictionary dictionaryWithContentsOfFile:watchEvent.path];
    
    //parse out current login items
    for(NSDictionary* loginItem in plistData[@"SessionItems"][@"CustomListItems"])
    {
        //save
        currentLoginItems[loginItem[@"Name"]] = loginItem;
    }
    
    //init set of new login items with current login items
    newLoginItems = [NSMutableSet setWithArray:[currentLoginItems allKeys]];
    
    //subtract out original ones
    [newLoginItems minusSet:[NSMutableSet setWithArray:[originalLoginItems allKeys]]];
    
    //ignore empty sets
    // ->since trigger is on any file modification, this is likely just a non-new item event
    if(0x0 == newLoginItems.count)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"didn't find any new login items...");
        
        //reset
        newLoginItem = nil;
        
        //ignore
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new login items: %@", newLoginItems]);
    
    //sanity check
    if(0x1 != newLoginItems.count)
    {
        //err msg
        logMsg(LOG_ERR, @"found more than one new login item, so not sure which one is latest!");
        
        //reset
        newLoginItem = nil;
        
        //bail
        goto bail;
    }
    
    //extract name (key) of new login item
    newLoginItemName = [[newLoginItems allObjects] firstObject];
    
    //set name of new login item
    // ->key of current login items dictionary (minus path ext)
    newLoginItem[@"name"] = [newLoginItemName stringByDeletingPathExtension];
    
    //extract alias data
    aliasData = currentLoginItems[newLoginItemName][@"Alias"];
    
    //parse alias data to get path
    loginItemPath = [self getPath:aliasData];
    
    //set path
    if(nil != loginItemPath)
    {
        //set
        newLoginItem[@"path"] = loginItemPath;
    }
    //couldn't find path
    // ->just set to 'unknown'
    else
    {
        //set
        newLoginItem[@"path"] = @"unknown";
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"new login item: %@", newLoginItem]);
    
    
//bail
bail:
    
    return newLoginItem;
    
}

//given a login item's alias data
// ->scan it for the full path to the item
-(NSString*)getPath:(NSData*)aliasData
{
    //path
    NSMutableString* path = nil;
    
    //pointer to bytes
    const char *bytes = NULL;
    
    //index
    NSUInteger index = 0;
    
    //init
    bytes = [aliasData bytes];
    
    //candidate size
    NSUInteger candidateSize = 0;
    
    //candidate path
    NSMutableString* candidatePath = nil;

    //iterate over all bytes
    // ->look for size:<valid file>
    for(index = 0; index < [aliasData length]; index++)
    {
        //extract a size
        candidateSize = bytes[index];
        
        //check if what could be a size is reasonable
        // at least 2 and smaller than rest of the data
        if( (candidateSize <= 2) ||
            (candidateSize > [aliasData length] - index) )
        {
            //meh, not likely a size
            continue;
        }
        
        //init candidate path
        candidatePath = [[NSMutableString alloc] initWithBytes:(const void *)&bytes[index+1] length:candidateSize encoding:NSUTF8StringEncoding];
        
        //sanity check
        // ->make sure is a valid string and file exists
        if( (nil == candidatePath) ||
            (YES != [[NSFileManager defaultManager] fileExistsAtPath:candidatePath]) )
        {
            //keep trying
            continue;
        }
        
        //got path
        path = candidatePath;
        
        //add '/' if needed
        // ->some reason, sometimes its not there...
        if(YES != [candidatePath hasPrefix:@"/"])
        {
            //insert '/'
            [path insertString:@"/" atIndex:0];
        }
    
        //got path
        // ->exit loop
        break;
    }
    
    return path;
}


//use apple script to delete the login item
// ->manual deletion fails since a cache is used
-(BOOL)block:(WatchEvent*)watchEvent;
{
    //return var
    BOOL wasBlocked = NO;
    
    //login item
    NSDictionary* newLoginItem = nil;
    
    //login item's path
    NSString* loginItemPath = nil;
    
    //action info dictionary
    NSMutableDictionary* actionInfo = nil;
    
    //error
    NSError* error = nil;
    
    //pid
    pid_t loginItemPID = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), watchEvent.path]);
    
    //alloc dictionary
    actionInfo = [NSMutableDictionary dictionary];
    
    //get lastest login item
    newLoginItem = [self findLoginItem:watchEvent];
    
    //sanity check
    if(nil == newLoginItem)
    {
        //bail
        goto bail;
    }
    
    //add action
    actionInfo[KEY_ACTION] = [NSNumber numberWithInt:ACTION_DELETE_LOGIN_ITEM];

    //add login item name
    actionInfo[KEY_ACTION_PARAM_ONE] = newLoginItem[@"name"];
    
    //set target UID
    actionInfo[KEY_TARGET_UID] = [NSNumber numberWithInt:watchEvent.reportedUID];
    
    //tell IPC object to send action
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendActionToAgent:actionInfo watchEvent:watchEvent];
    
    //give it some time to process
    // ->allows delete to go thru, so updating list of login items below will be ok
    [NSThread sleepForTimeInterval:1.0];
    
    //extract path
    loginItemPath = newLoginItem[@"path"];
    
    //delete the file
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:loginItemPath error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete login item %@ (%@)", loginItemPath, error]);
        
        //don't bail, since still want to try kill, etc
    }
    //deleted OK
    // ->just log msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"deleted %@", loginItemPath]);
    }
    
    //get most recent process that matches path
    loginItemPID = mostRecentProc(((AppDelegate*)[[NSApplication sharedApplication] delegate]).processMonitor.processList, loginItemPath);
    
    //kill the persistent process
    if(0 != loginItemPID)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killing %@ (pid: %d)", loginItemPath, loginItemPID]);
        if(0 != kill(loginItemPID, SIGKILL))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to kill login item %@ (pid: %d)", loginItemPath, loginItemPID]);
        }
    }
    //pid not found
    // ->just log msg about this (might not have been started yet, etc)
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to find pid for %@", loginItemPath]);
    }
    
    //happy
    wasBlocked = YES;
    
//bail
bail:
    
    //always update originals
    [self updateOriginals:watchEvent.path];
    
    return wasBlocked;
}

//delete a login item via apple script
// ->class instance since invoked by daemon and/or UI instance in user session
+(BOOL)deleteLoginItem:(NSString*)name
{
    //ret var
    BOOL wasDeleted = NO;
    
    //apple script cmd
    NSString* appleScriptCmd = nil;
    
    //apple script cmd
    // ->used to delete login in
    NSAppleScript* appleScript = nil;
    
    //apple script results
    NSAppleEventDescriptor* appleScriptResult = nil;
    
    //error
    NSDictionary* errorInfo = nil;
    
    //init apple script cmd
    appleScriptCmd = [NSString stringWithFormat:@"tell application \"System Events\" to delete login item \"%@\"", name];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"exec'ing: %@", appleScriptCmd]);
    
    //init apple script
    appleScript = [[NSAppleScript alloc] initWithSource:appleScriptCmd];
    
    //sanity check
    if(nil == appleScript)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to init apple script"]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"exec'ing %@ to delete login item", appleScript]);
    
    //execute apple script
    // ->should delete login item
    appleScriptResult = [appleScript executeAndReturnError:&errorInfo];
    
    //sanity check
    if(nil == appleScriptResult)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to exec apple script: %@", errorInfo]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"launch item was blocked %@", appleScriptResult]);
    
    //happy
    wasDeleted = YES;

//bail
bail:
    
    return wasDeleted;
}


//get the name of the launch item
// ->'Label' from plist
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    //name of login item
    NSString* itemName = nil;
    
    //login item
    NSDictionary* newLoginItem = nil;
    
    //get lastest login item
    newLoginItem = [self findLoginItem:watchEvent];
    
    //sanity check
    if( (nil != newLoginItem) &&
        (nil != newLoginItem[@"name"]) )
    {
        //save name
        itemName = newLoginItem[@"name"];
    }
    
    return itemName;
}

//get the binary of the launch item
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //path to login item binary
    NSString* itemBinary = nil;

    //login item
    NSDictionary* newLoginItem = nil;
    
    //get lastest login item
    newLoginItem = [self findLoginItem:watchEvent];
    
    //sanity check
    if( (nil != newLoginItem) &&
        (nil != newLoginItem[@"path"]) )
    {
        //save name
        itemBinary = newLoginItem[@"path"];
    }
    
    return itemBinary;
}
@end
