//
//  InterProcComms.h
//  BlockBlock
//
//  Created by Patrick Wardle on 12/2/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#ifndef BlockBlock_InterProcComms_h
#define BlockBlock_InterProcComms_h

#import "ErrorWindowController.h"
#import "AlertWindowController.h"

@interface InterProcComms : NSObject
{
   
}

/* PROPERTIES */

//UI (agent) status
@property NSUInteger uiState;

//list of registered UI agents
@property (nonatomic, retain)NSMutableDictionary* registeredAgents;

//error popup
@property(nonatomic, retain)ErrorWindowController* errorWindowController;


/* METHODS */

/* DAEMON CODE */

//DAEMON METHOD
// ->send an action to the UI session
-(void)sendActionToAgent:(NSMutableDictionary*)actionInfo watchEvent:(WatchEvent*)watchEvent;

//broadcast alert
-(void)sendAlertToAgent:(WatchEvent*) watchEvent userInfo:(NSMutableDictionary*)userInfo;

//find UID for the alert
// ->since msg to generate UI alert is sent to all sessions, this will identify which one should display
-(uid_t)uidForAlert:(WatchEvent*) watchEvent;

//enable a notification
// ->either for daemon or agent (ui)
-(void)enableNotification:(NSUInteger)type;

//disable a notification
// ->either for daemon or agent (ui)
//-(void)disableNotification:(NSUInteger)type;

//DAEMON METHOD
//handle user selection in daemon
// ->invoked from agent (ui) on daemon
-(void)handleAlertViaIPC:(NSNotification *)notification;

//AGENT METHOD
//display alert in agent (ui)
// ->invoked from daemon on agent (ui)
-(void)displayAlertViaIPC:(NSNotification *)notification;

//AGENT METHOD
//notify background (daemon) instance what user selected
// ->notification will contain dictionary w/ watch event UUID and action (block | allow | disabled)
-(void)sendActionToDaemon:(NSString*) watchEventUUID action:(NSUInteger)action;

//AGENT METHOD
//allow a agent (might be multiple in diff user sessions) to register w/ the daemon
// ->allows daemon to add watch for user (~) specific path
-(void)registerAgent;

//AGENT METHOD
//the UI (agent) can be disabled/enabled by the user
// ->save this state (so know for example not to show the alert popup, etc)
-(void)setAgentStatus:(NSUInteger)state;

@end


#endif
