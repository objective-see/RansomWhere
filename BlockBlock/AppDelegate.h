//
//  AppDelegate.h
//  BlockBlock
//
//  Created by Patrick Wardle on 8/27/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//
#import <Cocoa/Cocoa.h>

#import "Control.h"
#import "StatusBarMenu.h"
#import "InterProcComms.h"
#import "InfoWindowController.h"
#import "ErrorWindowController.h"
#import "PrefsWindowController.h"
#import "ConfigureWindowController.h"

@class ProcessMonitor;
@class WatchEvent;
@class Queue;
@class Watcher;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate>
{
    //watcher class
    Watcher* watcher;
    
    //process monitor class
    ProcessMonitor* processMonitor;
    
    //the status bar item
    NSStatusItem* statusBarItem;
  
    //queue object
    // ->contains watch items that should be processed
    Queue* eventQueue;

    //IPC object
    InterProcComms* interProcComms;
    
    //Control object
    Control* controlObj;
    
}

//for testing
//@property(nonatomic, retain)AlertWindowController* alertWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

//error window
@property(nonatomic, retain)ErrorWindowController* errorWindowController;

//info window
@property(nonatomic, retain)InfoWindowController* infoWindowController;

//IPC object
@property (nonatomic, retain)Control* controlObj;

//Control object
@property (nonatomic, retain)InterProcComms* interProcComms;

//status bar menu
@property(nonatomic, retain)StatusBarMenu* statusBarMenuController;

//watcher instance
@property (strong, nonatomic)Watcher* watcher;

//process monitor instance
@property (strong, nonatomic)ProcessMonitor* processMonitor;

//event queue
@property (nonatomic, retain)Queue* eventQueue;

//dictionary of watch events sent to UI
// ->used to verify response (back from user)
@property (nonatomic, retain)NSMutableDictionary* reportedWatchEvents;

//list of persistently white-listed items
// ->used to automatically allow subsequent events
@property (nonatomic, retain)NSMutableArray* whiteList;

//list of 'remembered' watch events
// ->used to automatically allow/block subsequent events
@property (nonatomic, retain)NSMutableArray* rememberedWatchEvents;

//dictionary of file path's and their original contents
@property(nonatomic,retain)NSMutableDictionary* orginals;


/* METHODS */

//make the instance of the uninstall process foreground
// ->then show the 'configure' window (w/ 'uninstall' button)
-(BOOL)initUninstall;

//exec daemon logic
// ->init watchers/queue/etc and enable IPC
-(void)startBlockBlocking_Daemon;

//exec agent logic
// ->init status bar and enable IPC
-(void)startBlockBlocking_Agent;

//display configuration window
-(void)displayConfigureWindow;

//initialize status menu bar
-(void)loadStatusBar;

//AGENT METHOD
// ->check for update
-(void)checkForUpdate;

@end
