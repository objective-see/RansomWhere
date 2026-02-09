//
//  file: Configure.h
//  project: RansomWhere? (config)
//  description: install/uninstall logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef RansomWhere_Configure_h
#define RansomWhere_Configure_h

#import "HelperComms.h"

@import OSLog;
#import <Foundation/Foundation.h>

@interface Configure : NSObject
{
    
}

/* PROPERTIES */

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

/* METHODS */

//determine if installed
-(BOOL)isInstalled;

//load/unload launch daemon
// calls into helper via XPC
-(BOOL)toggleDaemon:(BOOL)shouldLoad;

//check if daemon has FDA
-(BOOL)shouldRequestFDA;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(BOOL)full;

//remove helper (daemon)
-(BOOL)removeHelper;

@end

#endif
