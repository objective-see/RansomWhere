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
    
    //log args
    for(int i = 0; i < argc; i++)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"arg[%d]: %s", i, argv[i]]);
    }
    
    //rest of logic is performed in app delegate
    // ->method, applicationDidFinishLaunching:
    return NSApplicationMain(argc, argv);
}
