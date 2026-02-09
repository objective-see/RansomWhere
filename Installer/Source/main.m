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

#import "main.h"
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
    
    //status
    int status = -1;
    
    //init log
    logHandle = os_log_create(BUNDLE_ID, "installer");
    
    //dbg msg
    os_log_debug(logHandle, "RansomWhere (in/unin)staller launched with %{public}@", NSProcessInfo.processInfo.arguments);
    
    //cmdline install?
    if([NSProcessInfo.processInfo.arguments containsObject:CMD_INSTALL]) {
        
        //dbg msg
        os_log_debug(logHandle, "performing commandline install");
        
        //install
        if(YES != cmdlineInterface(ACTION_INSTALL_FLAG))
        {
            //err msg
            printf("\nRANSOMWHERE ERROR: install failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("RANSOMWHERE: install ok!\n\n");
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //cmdline uninstall?
    else if([NSProcessInfo.processInfo.arguments containsObject:CMD_UNINSTALL]){
        
        //dbg msg
        os_log_debug(logHandle, "performing commandline uninstall");
        
        //install
        if(YES != cmdlineInterface(ACTION_UNINSTALL_FLAG))
        {
            //err msg
            printf("\nRANSOMWHERE ERROR: uninstall failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("RANSOMWHERE: uninstall ok!\n\n");
        
        //happy
        status = 0;
        
        //done
        goto bail;
    }
    
    //default run mode
    // just kick off main app logic
    status = NSApplicationMain(argc, (const char **)argv);
    
bail:
    
    return status;
}

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action) {
    
    //flag
    BOOL wasConfigured = NO;
    
    //configure obj
    Configure* configure = nil;
    
    //ignore SIGPIPE
    signal(SIGPIPE, SIG_IGN);
    
    //alloc/init
    configure = [[Configure alloc] init];
    
    //first check root
    if(0 != geteuid()) {
        printf("\nRANSOMWHERE ERROR: cmdline interface actions require root!\n\n");
        goto bail;
    }
    
    //configure
    wasConfigured = [configure configure:action];
    
    //cleanup
    [configure removeHelper];
    
bail:

    return wasConfigured;
}
