//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.

#import "Consts.h"
#import "Logging.h"
#import "Exception.h"
#import "Utilities.h"
#import "AppDelegate.h"

//global
// ->only report an fatal exception once
BOOL wasReported = NO;

//install exception/signal handlers
void installExceptionHandlers()
{
    //sigaction struct
    struct sigaction sa = {0};
    
    //init struct
    sigemptyset (&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = signalHandler;
    
    //exception handler
    NSSetUncaughtExceptionHandler(&exceptionHandler);
    
    //install signal handlers
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS,  &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGTRAP, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL);
    
    return;
}

//exception handler
// will be invoked for Obj-C exceptions
void exceptionHandler(NSException *exception)
{
    //error info dictionary
    NSMutableDictionary* errorInfo = nil;

    //error msg
    NSString* errorMessage = nil;
    
    //ignore if exception was already reported
    if(YES == wasReported)
    {
        //bail
        goto bail;
    }
    
    //alloc
    errorInfo = [NSMutableDictionary dictionary];
        
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: OS version: %@ /App version: %@", [[NSProcessInfo processInfo] operatingSystemVersionString], getAppVersion()]);

    //create error msg
    errorMessage = [NSString stringWithFormat:@"unhandled obj-c exception caught [name: %@ / reason: %@]", [exception name], [exception reason]];
    
	//err msg
	logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", errorMessage]);
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", [exception.callStackSymbols description]]);
    
    //add main error msg
    errorInfo[KEY_ERROR_MSG] = @"ERROR: unrecoverable fault";
    
    //add sub msg
    errorInfo[KEY_ERROR_SUB_MSG] = [exception name];
    
    //set error URL
    errorInfo[KEY_ERROR_URL] = FATAL_ERROR_URL;
    
    //add global session id
    // ->any/all agents should display
    errorInfo[KEY_TARGET_UID] = [NSNumber numberWithInt:UID_ALL_SESSIONS];
    
    //fatal error
    // ->agent should exit
    errorInfo[KEY_ERROR_SHOULD_EXIT] = [NSNumber numberWithBool:YES];
    
    //send error to agent
    // ->it will display the alert
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendErrorToAgent:errorInfo];
    
    //set flag
    wasReported = YES;
    
    //daemon should exit
    // ->agent will exit when user clicks 'exit' etc in popups
    if(YES == isDaemonInstance())
    {
        //err msg
        logMsg(LOG_ERR, @"exiting due to unrecoverable fault");
        
        //bail
        exit(-1);
    }
    //agent
    // ->need to sleep, otherwise returning from this function will cause OS to kill agent
    //   instead, we want error popup to be displayed (which will exit agent when closed)
    else
    {
        //nap forevers
        while(YES)
        {
            //nap
            [NSThread sleepForTimeInterval:1.0f];
        }
    }
    
//bail
bail:
    
	return;
}

//handler for signals
// will be invoked for BSD/*nix signals
void signalHandler(int signal, siginfo_t *info, void *context)
{
    //error info dictionary
    NSMutableDictionary* errorInfo = nil;
    
    //error msg
    NSString* errorMessage = nil;
    
    //context
    ucontext_t *uContext = NULL;

    //ignore if exception was already reported
    if(YES == wasReported)
    {
        //bail
        goto bail;
    }
    
    //alloc
    errorInfo = [NSMutableDictionary dictionary];
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: OS version: %@ /App version: %@", [[NSProcessInfo processInfo] operatingSystemVersionString], getAppVersion()]);
    
    //typecast context
	uContext = (ucontext_t *)context;

    //create error msg
    errorMessage = [NSString stringWithFormat:@"unhandled exception caught, si_signo: %d  /si_code: %s  /si_addr: %p /rip: %p",
              info->si_signo, (info->si_code == SEGV_MAPERR) ? "SEGV_MAPERR" : "SEGV_ACCERR", info->si_addr, (unsigned long*)uContext->uc_mcontext->__ss.__rip];
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", errorMessage]);
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", [[NSThread callStackSymbols] description]]);
    
    //add main error msg
    errorInfo[KEY_ERROR_MSG] = @"ERROR: unrecoverable fault";
    
    //add sub msg
    errorInfo[KEY_ERROR_SUB_MSG] = [NSString stringWithFormat:@"si_signo: %d / rip: %p", info->si_signo, (unsigned long*)uContext->uc_mcontext->__ss.__rip];
    
    //set error URL
    errorInfo[KEY_ERROR_URL] = FATAL_ERROR_URL;
    
    //add global session id
    // ->any/all agents should display
    errorInfo[KEY_TARGET_UID] = [NSNumber numberWithInt:UID_ALL_SESSIONS];
    
    //fatal error
    // ->agent should exit
    errorInfo[KEY_ERROR_SHOULD_EXIT] = [NSNumber numberWithBool:YES];
    
    //send error to agent
    // ->it will display the alert
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendErrorToAgent:errorInfo];
    
    //set flag
    wasReported = YES;
    
    //daemon should exit
    // ->agent will exit when user clicks 'exit' etc in popups
    if(YES == isDaemonInstance())
    {
        //err msg
        logMsg(LOG_ERR, @"exiting due to unrecoverable fault");
        
        //bail
        exit(-1);
    }
    
//bail
bail:
    
    return;
}
