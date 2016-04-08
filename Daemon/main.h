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

//global list of binary objects
extern NSMutableDictionary* binaryList;

/* FUNCTIONS */

//delete list of installed/approved apps, etc
BOOL reset();

//init paths
// ->this logic will only be needed if daemon is executed from non-standard location
BOOL initPaths();

//create binary objects for all baselined app
// ->first time; generate list from OS (this might take a while)
BOOL processBaselinedApps();

//create binary objects for all (persistent) user-approved binaries
BOOL processApprovedBins();

//create binary objects for all currently running processes
BOOL processRunningProcs();

#endif /* main_h */
