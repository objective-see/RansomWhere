//
//  StatusBar.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import "StatusBar.h"
#import "Consts.h"
#import "Logging.h"

@implementation StatusBar


//initialize status/menu bar
-(void)initStatusBar
{
    //create status bar
    self.statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    //highlight when clicked
    [self.statusBarItem setHighlightMode:YES];
    
    //set icon
    self.statusBarItem.image = [NSImage imageNamed:@"StatusIcon_On"];
    
    //set menu
    [self.statusBarItem setMenu:self.statusMenu];
    
    //set menu delegate
    self.statusMenu.delegate = self;
    
    //init status
    [self setStatus:@"BlockBlock: enabled"];
    
    return;
}

//set the status
// ->top gray line in menu
-(void)setStatus:(NSString*) statusMsg
{
    //set status
    [self.statusMsg setStringValue:statusMsg];
}

//invoked by the status bar menu
//disable block block
// ->all we do is disable the alert notification since the core is running as r00t (so can't be unloaded via user menu)
//   also, don't want to stop agent, since then the user can't (re)enable it via the menu
-(void)disable
{
    //dbg msg
    logMsg(LOG_DEBUG, @"disable: disabling");
    
    //disable IPC notifcation for agent
    // ->stops it from listen for alerts from daemon (core)
    [interProcComms disableNotification:RUN_INSTANCE_AGENT];
    
    //set icon to off
    self.statusBarItem.image = [NSImage imageNamed:@"StatusIcon_Off"];
    
    //set status
    // ->top (disabled) menu item
    [self setStatus:@"BlockBlock: disabled"];
    
    //toggle menu item's title
    self.menuItemStatus.title = @"Enable";
    
    return;
}


//invoked by the status bar menu
//enable block block
-(void)enable
{
    //dbg msg
    NSLog(@"enabling BLOCKBLOCK");
    
    //start launch daemon
    // ->this is what is doing the monitoring/invoking alerts (by means of the launch agent)
    if(YES != [controlObj startDaemon])
    {
        //err msg
        NSLog(@"ERROR: starting BLOCKBLOCK (daemon) failed");
    }
    
    //set icon to on
    self.statusBarItem.image = [NSImage imageNamed:@"StatusIcon_On"];
    
    //set status
    // ->top (disabled) menu item
    [self setStatus:@"BlockBlock: enabled"];
    
    //toggle menu item's title
    self.menuItemStatus.title = @"Disable";
    
    return;
}


#pragma mark - menu actions

//enable or disable BlockBlock
-(void)toggle:(id)sender
{
    //user clicked 'Disable'
    if(YES == [ ((NSMenuItem*)sender).title isEqualToString:@"Disable"])
    {
        //disable
        [self disable];
    }
    //user clicked 'Enable'
    else if(YES == [ ((NSMenuItem*)sender).title isEqualToString:@"Enable"])
    {
        //enable
        [self enable];
    }
    
    return;
}

//handler for 'uninstall' menu item
// ->posts notification to daemon to kick off uninstaller (as r00t)
-(void)uninstallHandler:(id)sender
{
    //dbg msg
    logMsg(LOG_DEBUG, @"uninstall: user clicked uninstall");
    
    //TODO: pass current user's ID
    // ->allows auth'd unisntaller to then unload launch agent
    //e.g. sudo launchctl asuser 501 launchctl unload /Library/LaunchAgents/com.objectiveSee.blockblock.plist
    // other code will have to be updated :)
    
    //post uninstall notification
    // ->handle'd by daemon (since uninstaller instance needs to be run as root)
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:SHOULD_HANDLE_UNINSTALL_NOTIFICATION object:nil userInfo:nil options:NSNotificationDeliverImmediately | NSNotificationPostToAllSessions];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"posted uninstall notification");
    
    return;
}

-(void)about:(id)sender
{
    //dbg msg
    NSLog(@"results: %@", sender);
    
    NSURL *URL = [NSURL URLWithString:@"http://synack.com"];
    
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:URL];
    
    return;
}


@end
