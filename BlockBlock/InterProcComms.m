//
//  InterProcComms.m
//  BlockBlock
//
//  Created by Patrick Wardle on 12/2/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "LoginItem.h"
#import "Utilities.h"
#import "WatchEvent.h"
#import "PluginBase.h"
#import "AppDelegate.h"
#import "InterProcComms.h"
#import "Process.h"
#import "Watcher.h"


#import <Security/Security.h>
#import <Security/AuthSession.h>
#import <Foundation/Foundation.h>


@implementation InterProcComms

@synthesize registeredAgents;
@synthesize errorWindowController;

-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //set UI state
        // ->this only is used in instances of object in UI context
        self.uiState = UI_STATUS_ENABLED;
        
        //alloc dictionary for registered agents
        registeredAgents = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//enable (add) a notification listener
// ->either for daemon or agent (ui)
-(void)enableNotification:(NSUInteger)type
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"enabling notification for %lu", (unsigned long)type]);
    
    //launch daemon
    // ->alert processor and uninstall listeners
    if(type == RUN_INSTANCE_DAEMON)
    {
        //register listener to handle user's alert selection
        // ->will be invoked from UI (launch agent) instance...
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAlertViaIPC:)
          name:SHOULD_HANDLE_ALERT_NOTIFICATION object:nil];
        
        //register listener to handle agent registration
        // ->will be invoked from launch agent (ui) instance...
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRegistrationViaIPC:) name:SHOULD_HANDLE_AGENT_REGISTRATION_NOTIFICATION object:nil];

    }
    
    //launch agent
    // ->add alert display listener and apple script exec
    else if(type == RUN_INSTANCE_AGENT)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"ADDING OBSERVER: %@", self]);
        
        //register listener for to show alerts (in UI)
        // ->will be invoked from background (launch daemon) instance...
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
          selector:@selector(displayAlertViaIPC:) name:SHOULD_DISPLAY_ALERT_NOTIFICATION object:nil];
        
        //register listener for to show errors (in UI)
        // ->will be invoked from background (launch daemon) instance...
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
          selector:@selector(displayErrorViaIPC:) name:SHOULD_DISPLAY_ERROR_NOTIFICATION object:nil];
        
        //register listener for to show alerts (in UI)
        // ->will be invoked from background (launch daemon) instance...
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
          selector:@selector(doUserActionViaIPC:) name:SHOULD_DO_USER_ACTION_NOTIFICATION object:nil];
    }
    
    return;
}

//DAEMON METHOD
// ->send an action to the UI session
-(void)sendActionToAgent:(NSMutableDictionary*)actionInfo watchEvent:(WatchEvent*)watchEvent
{
    //console (active) user
    NSDictionary* activeUser = nil;
 
    //action
    NSUInteger action = 0;
    
    //get action
    action = [actionInfo[KEY_ACTION] intValue];
    
    //get active user
    activeUser = getCurrentConsoleUser();
    
    //dbg msg
    logMsg(LOG_DEBUG, @"will broadcast login item delete msg");
    
    //sanity check
    // ->make sure there is a target uid
    if(nil == actionInfo[KEY_TARGET_UID])
    {
        //set target uid to current one
        actionInfo[KEY_TARGET_UID] = activeUser[@"uid"];
    }
    
    //handle action-specific logic
    // ->for now, only action is ACTION_DELETE_LOGIN_ITEM...
    switch(action)
    {
        case ACTION_DELETE_LOGIN_ITEM:
            ;
            break;
            
        default:
            break;
    }
    
    //send notification to background (daemon) instance
    // ->tell it to register client
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SHOULD_DO_USER_ACTION_NOTIFICATION object:nil userInfo:actionInfo options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
    
    return;
}

//DAEMON method
//IPC callback for notification from ui (agent) to register itself
-(void)handleRegistrationViaIPC:(NSNotification *)notification
{
    //new user
    NSDictionary* newUser = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"got msg from UI (agent) to register agent");
    
    //assign
    newUser = notification.userInfo;
    
    //save
    // ->key is uid
    self.registeredAgents[newUser[KEY_USER_ID]] = newUser;
        
    //update all watch paths
    // ->plugin's with watch paths containing '~' will have to be updated for new agent (user)
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).watcher updateWatchedPaths:self.registeredAgents];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"alerting all plugins of new agent");
    
    //alert all plugins of new agent
    // ->allow them to plugin-specific logic
    for(PluginBase* plugin in ((AppDelegate*)[[NSApplication sharedApplication] delegate]).watcher.plugins)
    {
        //alert
        // ->pass in all new agents
        [plugin newAgent:newUser];
    }
    
    return;
}

//AGENT METHOD
//the UI (agent) can be disabled/enabled by the user
// ->save this state (so know for example not to show the alert popup, etc)
-(void)setAgentStatus:(NSUInteger)state
{
    //save into iVar
    self.uiState = state;
    
    return;
}

//AGENT METHOD
//allow a agent (might be multiple in diff user sessions) to register w/ the daemon
// ->allows daemon to add watch for user (~) specific path
-(void)registerAgent
{
    //user info dictionary
    NSMutableDictionary* userInfo = nil;
    
    //alloc dictionary
    userInfo = [NSMutableDictionary dictionary];
    
    //save user id
    userInfo[KEY_USER_ID] = [NSNumber numberWithInt:getuid()];
        
    //save user home directory
    userInfo[KEY_USER_HOME_DIR] = NSHomeDirectory();
    
    //save user name
    userInfo[KEY_USER_NAME] = NSUserName();
        
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending %@ to register with daemon", userInfo]);
        
    //send notification to background (daemon) instance
    // ->tell it to register client
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SHOULD_HANDLE_AGENT_REGISTRATION_NOTIFICATION object:nil userInfo:userInfo options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
    
    return;
}

//AGENT METHOD
//notify background (daemon) instance what user selected
// ->notification will contain dictionary w/ watch event UUID and action (block | allow | disabled)
-(void)sendActionToDaemon:(NSDictionary*)actionInfo
{
    //user selection
    //NSDictionary* userSelection = nil;
    
    //init dictionary
    // ->contains watch event UUID and action (block | allow)
    //userSelection = @{KEY_WATCH_EVENT_UUID:watchEventUUID, KEY_ACTION:[NSNumber numberWithInteger:action]};
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending %@ to daemon", actionInfo]);
    
    //send notification to background (daemon) instance
    // ->tell it to block/allow event
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SHOULD_HANDLE_ALERT_NOTIFICATION
      object:nil userInfo:actionInfo options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
    
    return;
}

/* DAEMON CODE */

//find UID for the alert
// ->since msg to generate UI alert is sent to all sessions, this will identify which one should display
-(uid_t)uidForAlert:(WatchEvent*)watchEvent
{
    //target UID
    uid_t targetUID = -1;
    
    //console (active) user
    NSDictionary* activeUser = nil;
    
    //init to process user id that triggered watch event
    targetUID = watchEvent.process.uid;
    
    //handle root session events
    // ->do some extra logic/set to active session
    if(0 == watchEvent.process.uid)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"watch event is associated with r00t");
        
        //handle Login Item case
        // ->this is special, since always r00t, but need to find correct session (might not be active)
        if(PLUGIN_TYPE_LOGIN_ITEM == watchEvent.plugin.type)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"login item session lookup");
            
            //check all users
            // ->do any have the launch agent installed?
            for(NSNumber* userID in self.registeredAgents)
            {
                //check for match
                if(YES == [watchEvent.path hasPrefix:self.registeredAgents[userID][KEY_USER_HOME_DIR]])
                {
                    //save uid
                    targetUID = [userID intValue];
                    
                    //dbg msg
                    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting uid to %u", targetUID]);
                    
                    //found match
                    // ->can bail
                    break;
                }
            }
        }
        
        //all other plugins
        // ->just use active user as session
        else if( (PLUGIN_TYPE_LOGIN_ITEM != watchEvent.plugin.type) ||
                 (0 == targetUID) )
    
        {
            //get active user
            activeUser = getCurrentConsoleUser();
            
            //sanity check
            if(nil == activeUser[@"uid"])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to get current users info:/");
                
                //bail
                goto bail;
            }
            
            //set session id to current one
            targetUID = [activeUser[@"uid"] intValue];
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting uid to active one: %u", targetUID]);
        }
        
    }//watchevent is associated with r00t session
    
//bail
bail:
    
    return targetUID;
}


//DAEMON method
// ->send the alert request to agent
-(void)sendAlertToAgent:(WatchEvent*)watchEvent userInfo:(NSMutableDictionary*)userInfo
{
    //add session id to dictionary that is sent to agents
    // ->allows correct one to display alert
    userInfo[KEY_TARGET_UID] = [NSNumber numberWithInt:[self uidForAlert:watchEvent]];
    
    //save reported session/uid
    watchEvent.reportedUID = [userInfo[KEY_TARGET_UID] intValue];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"broadcasting request to UI agent(s) to display alert");
    
    //send notification to UI (agent) to display alert to user
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SHOULD_DISPLAY_ALERT_NOTIFICATION
      object:nil userInfo:userInfo options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];

//bail
bail:
    
    return;
}

//DAEMON method
// ->send request to agent to dispaly error popup
-(void)sendErrorToAgent:(NSDictionary*)errorInfo
{
    //dbg msg
    logMsg(LOG_DEBUG, @"broadcasting request to UI agent(s) to display error");
    
    //send notification to UI (agent) to display alert to user
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SHOULD_DISPLAY_ERROR_NOTIFICATION
      object:nil userInfo:errorInfo options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
    
    return;
}


//AGENT METHOD
//display alert in UI
// ->invoked from daemon to/on UI (agent)
-(void)displayAlertViaIPC:(NSNotification *)notification
{
    //watch event ID
    NSString* watchEventUUID = nil;
    
    //target session uid
    uid_t targetUID = -1;
    
    //alert window controller
    // ->used to show alert window to user
    AlertWindowController* alertWindowController = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got request from daemon to show alert (ui) :%d/%@", getpid(), getCurrentConsoleUser()]);
    
    //extract target UID
    targetUID = [notification.userInfo[KEY_TARGET_UID] intValue];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking alert is for this session: %d matches %d?", targetUID, getuid()]);
    
    //check if target UID matches UI of this session
    // ->or also, is for all sessions
    if( (targetUID != getuid()) &&
        (targetUID != UID_ALL_SESSIONS) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"alert is *NOT* for this session! (ignoring)");
        
        //bail
        goto bail;
    }
    
    //handle case where user has disabled UI
    if(UI_STATUS_DISABLED == self.uiState)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"UI is disabled, so not showing alert");
        
        //extract watch event uuid (from daemon)
        watchEventUUID = notification.userInfo[KEY_WATCH_EVENT_UUID];
        
        //make sure it's not nil
        // ->since passing it back, and can't have nil in a dictioanary
        if(nil == watchEventUUID)
        {
            //just set blank string
            watchEventUUID = @"";
        }
        
        //send off to daemon
        // ->for now, just say it was allowed
        [self sendActionToDaemon:@{KEY_WATCH_EVENT_UUID:watchEventUUID, KEY_ACTION:[NSNumber numberWithInteger:ALLOW_WATCH_EVENT]}];
    }
    
    //handle case where passive mode is enabled
    // ->just log
    else if(YES == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController.passiveMode)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"passive mode enable, so not showing alert");
        
        //dbg msg
        // ->and log to file (if logging is enabled)
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"%@ %@ (%@ -> %@)", notification.userInfo[@"processPath"], notification.userInfo[@"alertMsg"],notification.userInfo[@"itemFile"], notification.userInfo[@"itemBinary"]]);
    }
    
    //UI is enabled, and passive move is not enabled
    // ->show alert, which will provide buttons to user
    //   on click, will send action back to daemon
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"showing alert to user");
        
        //dbg msg
        // ->and log to file (if logging is enabled)
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"%@ %@ (%@ -> %@)", notification.userInfo[@"processPath"], notification.userInfo[@"alertMsg"],notification.userInfo[@"itemFile"], notification.userInfo[@"itemBinary"]]);

        //alloc/init
        alertWindowController = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindowController"];
        
        //configure alert window with data from daemon
        [alertWindowController configure:notification.userInfo];
    
        //show (now configured), alert
        [alertWindowController showWindow:self];
    }
    
//bail
bail:

    return;
}

//AGENT METHOD
// ->display an error popup
-(void)displayErrorViaIPC:(NSNotification *)notification
{
    //user info dictionary
    NSDictionary* userInfo = nil;
    
    //target uid
    uid_t targetUID = 0;
    
    //extract user info
    userInfo = notification.userInfo;
    
    //sanity check
    // ->make sure received dictionary is valid
    if( (nil == userInfo[KEY_ERROR_MSG]) ||
        (nil == userInfo[KEY_ERROR_SUB_MSG]) ||
        (nil == userInfo[KEY_TARGET_UID]) )
    {
        //bail
        goto bail;
    }
    
    //extract target UID
    targetUID = [userInfo[KEY_TARGET_UID] intValue];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking error msg is for this session: %d matches %d?", targetUID, getuid()]);
    
    //check if target UID matches UI of this session
    // ->or also, is for all sessions
    if( (targetUID != getuid()) &&
        (targetUID != UID_ALL_SESSIONS) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"error msg is *NOT* for this session! (ignoring)");
        
        //bail
        goto bail;
    }
    
    //alloc error window
    errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];
    
    //main thread
    // ->just show UI alert
    if(YES == [NSThread isMainThread])
    {
        //display it
        // ->call this first to so that outlets are connected (not nil)
        [self.errorWindowController display];
        
        //configure it
        [self.errorWindowController configure:userInfo];
    }
    //background thread
    // ->have to show it on main thread
    else
    {
        //show alert
        // ->in main UI thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //display it
            // ->call this first to so that outlets are connected (not nil)
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:userInfo];
            
        });
    }
    
    
    
//bail
bail:
    
    return;
}

//AGENT METHOD
// ->perform some action in user's session
-(void)doUserActionViaIPC:(NSNotification *)notification
{
    //info about action
    NSDictionary* actionInfo = nil;
    
    //target session uid
    uid_t targetUID = -1;
    
    //error info
    NSMutableDictionary* errorInfo = nil;
    
    //grab script info
    actionInfo = notification.userInfo;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got apple script request from daemon: %@", actionInfo]);
    
    //sanity check
    if( (nil == actionInfo[KEY_ACTION]) ||
        (nil == actionInfo[KEY_TARGET_UID]) )
    {
        //err msg
        logMsg(LOG_ERR, @"action request from daemon is malformed");
        
        //bail
        goto bail;
    }
    
    //extract target UID
    targetUID = [notification.userInfo[KEY_TARGET_UID] intValue];

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking action is for this session: %d matches %d?", targetUID, getuid()]);
    
    //check if target UID matches UI of this session
    if(targetUID != getuid())
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"action is *NOT* for this session! (ignoring)");
        
        //bail
        goto bail;
    }
    
    //handle action
    switch([actionInfo[KEY_ACTION] intValue])
    {
        //delete a login item
        // ->accomplished by executing apple script cmd in user's session
        case ACTION_DELETE_LOGIN_ITEM:
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"blocking/deleting login item");
            
            //delete login item
            // ->display error if it fails
            if(YES != [LoginItem deleteLoginItem:actionInfo[KEY_ACTION_PARAM_ONE]])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to delete login item");
                
                //alloc error info
                errorInfo = [NSMutableDictionary dictionary];
             
                //set error msg
                errorInfo[KEY_ERROR_MSG] = @"ERROR: failed to block item";
                
                //set error sub msg
                errorInfo[KEY_ERROR_SUB_MSG] = [NSString stringWithFormat:@"item: %@", actionInfo[KEY_ACTION_PARAM_ONE]];
                
                //save exit
                errorInfo[KEY_ERROR_SHOULD_EXIT] = [NSNumber numberWithBool:NO];
                
                //alloc error window
                errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];
                
                //display it
                // ->call this first to so that outlets are connected (not nil)
                [self.errorWindowController display];
                
                //configure it
                [self.errorWindowController configure:errorInfo];
                
                //bail
                goto bail;
            }
            
            //deleted item ok
            // ->just log dbg msg
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"deleted login item!");
            }
        
            break;
        }
            
        default:
            break;
    }
    
//bail
bail:
    
    return;
}


//DAEMON CODE
// ->handle user selection
//   invoked from UI (agent) on daemon
-(void)handleAlertViaIPC:(NSNotification *)notification
{
    //reported watch event
    WatchEvent* reportedWatchEvent = nil;
    
    //alert selection
    NSDictionary* alertSelection = nil;
    
    //error info dictionary
    NSMutableDictionary* errorInfo = nil;
    
    //reported watch events from app delegate
    // ->this var is just for convience/shorthand
    NSMutableDictionary* reportedWatchEvents = nil;
    
    //grab alert selection
    alertSelection = notification.userInfo;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got alert response from user: %@", notification.userInfo]);
    
    //sanity check
    if( (nil == alertSelection[KEY_WATCH_EVENT_UUID]) ||
        (nil == alertSelection[KEY_ACTION]) )
    {
        //err msg
        logMsg(LOG_ERR, @"alert dictionary from UI is malformed");
        
        //bail
        goto bail;
    }
    
    //grab reported watch events
    reportedWatchEvents = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).reportedWatchEvents;
    
    //any access events needs to be locked
    @synchronized(reportedWatchEvents)
    {
        //attempt to find reported watch event
        // ->UUID is in dictionary from notification
        reportedWatchEvent = [reportedWatchEvents objectForKey:alertSelection[KEY_WATCH_EVENT_UUID]];
    }
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"registered WATCH EVENTS %@", ((AppDelegate*)[[NSApplication sharedApplication] delegate]).reportedWatchEvents]);
    
    //handle matched watch events
    // ->save 'remember' state and process 'block' requests
    if(nil != reportedWatchEvent)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found watch event for %@", alertSelection[KEY_WATCH_EVENT_UUID]]);
        
        //save it if user selected 'remember'
        if( (nil != alertSelection[KEY_REMEMBER]) &&
            (YES == [alertSelection[KEY_REMEMBER] boolValue]) )
        {
            //save
            [((NSMutableArray*)((AppDelegate*)[[NSApplication sharedApplication] delegate]).rememberedWatchEvents) addObject:reportedWatchEvent];
        }
        
        //invoke plugin to block
        if(BLOCK_WATCH_EVENT == [alertSelection[@"action"] integerValue])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"blocking %@'s attempt to create %@", reportedWatchEvent.process.path, reportedWatchEvent.path]);
            
            //invoke plugin's block method
            // ->send error msg if blocking fails
            if(YES != [reportedWatchEvent.plugin block:reportedWatchEvent])
            {
                //alloc
                errorInfo = [NSMutableDictionary dictionary];
                
                //add main error msg
                errorInfo[KEY_ERROR_MSG] = @"ERROR: failed to block item";
                
                //add sub msg
                errorInfo[KEY_ERROR_SUB_MSG] = [NSString stringWithFormat:@"item: %@", [reportedWatchEvent.plugin startupItemName:reportedWatchEvent]];
                
                //add session id to dictionary that is sent to agents
                // ->allows correct one to display alert
                errorInfo[KEY_TARGET_UID] = [NSNumber numberWithInt:reportedWatchEvent.reportedUID];
                
                //agent shouldn't exit
                // ->not fatal error
                errorInfo[KEY_ERROR_SHOULD_EXIT] = [NSNumber numberWithBool:NO];
                
                //send error to agent
                // ->it will display the alert
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendErrorToAgent:errorInfo];
                
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to block, will alert agent %@", reportedWatchEvent]);
                
                //send error to agent
                // ->it will display the alert
                [self sendErrorToAgent:errorInfo];
            }
            //success
            // ->for msg/logging logic only
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"successfully blocked");
            }
            
            //indicate it was blocked
            // ->needed for subsequent (automated) processing
            reportedWatchEvent.wasBlocked = YES;
        }
        //invoke plugin to allow
        else if(ALLOW_WATCH_EVENT == [alertSelection[@"action"] integerValue])
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowing %@'s attempt to create %@", reportedWatchEvent.process.path, reportedWatchEvent.path]);
            
            //invoke plugin's block method
            [reportedWatchEvent.plugin allow:reportedWatchEvent];
        }
        
        //any access events needs to be locked
        @synchronized(reportedWatchEvents)
        {
            //always remove watch event
            [reportedWatchEvents removeObjectForKey:alertSelection[KEY_WATCH_EVENT_UUID]];
        }
        
    }
    //wtf, should never happen
    else
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"could not find watch event matching %@", alertSelection[KEY_WATCH_EVENT_UUID]]);
    }
    
//bail
bail:
    
    return;
}

@end

