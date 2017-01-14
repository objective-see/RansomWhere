//
//  main.m
//  BlockBlock
//
//  Created by Patrick Wardle on 8/27/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

int main(int argc, const char * argv[])
{
    //process ID
    pid_t processid = 0;
    
    //for auth'd installer/uninstaller instances
    // ->immediately (before any other output), write pid to stdout so that the parent can grab it
    if( (0x2 == argc) &&
        ( (0 == strcmp(argv[1], ACTION_INSTALL.UTF8String)) || (0 == strcmp(argv[1], ACTION_UNINSTALL.UTF8String)) ) )
    {
        //get pid
        processid = getpid();
        
        //write it out to stdout
        // ->parent will be reading it from here
        fwrite(&processid, sizeof(processid), 1, stdout);
        
        //flush
        fflush(stdout);
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"launched, in main()");
    
    //debug mode logic
    #ifdef DEBUG
    
    //log args
    for(int i = 0; i < argc; i++)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"arg[%d]: %s", i, argv[i]]);
    }
    
    #endif
    
    //for daemon
    // ->wait until there is user/login to prevent error msgs in syslog
    if( (0x2 == argc) &&
        (0 == strcmp(argv[1], ACTION_RUN_DAEMON.UTF8String)) )
    {
        //wait till user logs in
        // ->otherwise bad things happen when trying to connect to the window server/status bar
        do
        {
            //wait till a user is logged in
            if(nil != getCurrentConsoleUser())
            {
                //got user
                break;
            }
            
            //nap
            [NSThread sleepForTimeInterval:1.0f];
            
        } while(YES);
        
        //dbg msg
        logMsg(LOG_DEBUG, @"daemon continuing, as user logged in/UI session ok!");
    }
    
    //rest of logic is performed in app delegate
    // ->method, applicationDidFinishLaunching:
    return NSApplicationMain(argc, argv);
}
