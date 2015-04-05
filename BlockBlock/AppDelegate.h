//
//  AppDelegate.h
//  BlockBlock
//
//  Created by Patrick Wardle on 8/27/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Watcher.h"
#import "Control.h"
#import "InterProcComms.h"
#import "ConfigureWindowController.h"
#import "StatusBarMenu.h"
#import "ErrorWindowController.h"

@class ProcessMonitor;
@class WatchEvent;
@class Queue;

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
//IPC object
@property (nonatomic, retain)Control* controlObj;

//Control object
@property (nonatomic, retain)InterProcComms* interProcComms;

//status bar menu
@property(strong, nonatomic)StatusBarMenu* statusBarMenuController;

//watcher instance
@property (strong, nonatomic)Watcher* watcher;

//process monitor instance
@property (strong, nonatomic)ProcessMonitor* processMonitor;

//event queue
@property (nonatomic, retain)Queue* eventQueue;

//dictionary of watch events sent to UI
// ->used to verify response (back from user)
@property (nonatomic, retain)NSMutableDictionary* reportedWatchEvents;

//dictionary of file path's and their original contents
@property(nonatomic,retain)NSMutableDictionary* orginals;

/* METHODS */
//TODO: update

//display configuration window to w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(NSString*)windowTitle action:(NSUInteger)action;

//make the instance of the uninstall process foreground
// ->then show the 'configure' window (w/ 'uninstall' button)
-(BOOL)initUninstall;



@end
