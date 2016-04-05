//
//  main.h
//  Daemon
//
//  Created by Patrick Wardle on 4/2/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import <Foundation/Foundation.h>

/* GLOBALS */

//global list of installed apps
extern NSMutableSet* installedApps;

//global process list
extern NSMutableDictionary* processList;

//global list of user approved binaries
extern NSMutableSet* userApprovedBins;

/* FUNCTIONS */

//install handler for shutdown
// ->i.e: want to catch SIGTERM
void initShutdownHandler();

//shutdown handler
void shutdownHandler(int signum);

//init list of user approved binaries
// ->loads from disk, into global variable
void initApprovedBins();

//init list of user approved binaries
// ->loads from disk, into global variable
void initApprovedBins();

//load list of installed apps
// ->first time; generate them (this might take a while)
void initInstalledApps();

//init process list
// ->make process objects of all currently running processes
void initProcessList();

#endif /* main_h */
