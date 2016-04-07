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
void reset();

//create binary objects for all baselined app
// ->first time; generate list from OS (this might take a while)
void processBaselinedApps();

//create binary objects for all (persistent) user-approved binaries
void processApprovedBins();

//load list of installed apps
// ->first time; generate them (this might take a while)
void initInstalledApps();

//create binary objects for all currently running processes
void processRunningProcs();

#endif /* main_h */
