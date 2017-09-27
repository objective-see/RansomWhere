//
//  main.h
//  Daemon
//
//  Created by Patrick Wardle on 4/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import "Whitelist.h"
#import "ProcMonitor.h"

#import <Foundation/Foundation.h>

/* GLOBALS */

//global current user
extern CFStringRef consoleUserName;

//global white list
extern Whitelist* whitelist;

//global process monitor
extern ProcMonitor* processMonitor;

/* FUNCTIONS */

//delete list of installed/approved apps, etc
BOOL reset(void);

//init paths
// ->this logic will only be needed if daemon is executed from non-standard location
BOOL initPaths(void);

//get current user
// ->then, setup callback for changes
BOOL initUserName(void);

//check for update
// ->query website for json file w/ version info
void* checkForUpdate(void *threadParam);

#endif /* main_h */
