//
//  file: main.m
//  project: RansomWhere
//  description: main interface, for installer
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

#import "consts.h"
#import "utilities.h"
#import "Configure.h"


/* To build:
 
 1. Comment out Installer's 'Run Script' (no need to copy in app/helper)
 2. Build Installer in 'Release Mode'
 3. Copy Installer to Application 'Uninstaller' folder
 4. Comment in Installer's 'Run Script'
 5. Build Installer in 'Archive Mode'
 
*/

/* GLOBALS */

//log handle
os_log_t logHandle = nil;

//main interface
int main(int argc, char *argv[]) {
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "config");
    
    return NSApplicationMain(argc, (const char **)argv);
}
