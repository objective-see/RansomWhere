//
//  Exception.m
//  RansomWhere (Shared)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Exception.h"
#import "Utilities.h"

#ifdef IS_APP
 #import "AppDelegate.h"
#endif

//global
// ->only report an fatal exception once
BOOL wasReported = NO;

//install exception/signal handlers
void installExceptionHandlers()
{
    //sigaction struct
    struct sigaction sa = {0};
    
    //init signal struct
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sa.sa_sigaction = signalHandler;
    
    //objective-C exception handler
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
    //error msg
    NSString* errorMessage = nil;
    
    //version
    NSString* version = nil;
    
    //ignore if exception was already reported
    if(YES == wasReported)
    {
        //bail
        return;
    }
    
    //get app version
    #ifdef IS_APP
    version = getAppVersion();
    
    //get daemon version
    #else
    version = getDaemonVersion();
    
    #endif
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: OS version: %@ /App version: %@", [[NSProcessInfo processInfo] operatingSystemVersionString], version]);

    //create error msg
    errorMessage = [NSString stringWithFormat:@"unhandled obj-c exception caught [name: %@ / reason: %@]", [exception name], [exception reason]];
    
	//err msg
	logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", errorMessage]);
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", [[NSThread callStackSymbols] description]]);
    
    //set flag
    wasReported = YES;
    
    //start app-specific code
    #ifdef IS_APP
    
    //error info dictionary
    NSMutableDictionary* errorInfo = nil;

    //alloc
    errorInfo = [NSMutableDictionary dictionary];
    
    //add main error msg
    errorInfo[KEY_ERROR_MSG] = @"ERROR: unrecoverable fault";
    
    //add sub msg
    errorInfo[KEY_ERROR_SUB_MSG] = [exception name];
    
    //set error URL
    errorInfo[KEY_ERROR_URL] = FATAL_ERROR_URL;
    
    //fatal error
    // ->agent should exit
    errorInfo[KEY_ERROR_SHOULD_EXIT] = [NSNumber numberWithBool:YES];
    
    //display error msg
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) displayErrorWindow:errorInfo];
    
    //need to sleep, otherwise returning from this function will cause OS to kill agent
    //  ->instead, we want error popup to be displayed (which will exit agent when closed)
    if(YES != [NSThread isMainThread])
    {
        //nap
        while(YES)
        {
            //nap
            [NSThread sleepForTimeInterval:1.0f];
        }
    }
    
    //end app-specific code
    #endif
    
	return;
}

//handler for signals
// will be invoked for BSD/*nix signals
void signalHandler(int signal, siginfo_t *info, void *context)
{
    //version
    NSString* version = nil;
    
    //error msg
    NSString* errorMessage = nil;
    
    //context
    ucontext_t *uContext = NULL;

    //ignore if exception was already reported
    if(YES == wasReported)
    {
        //bail
        return;
    }
    
    //get app version
    #ifdef IS_APP
    version = getAppVersion();
    
    //get daemon version
    #else
    version = getDaemonVersion();
    
    #endif
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: OS version: %@ /App version: %@", [[NSProcessInfo processInfo] operatingSystemVersionString], version]);
    
    //typecast context
	uContext = (ucontext_t *)context;

    //create error msg

#if TARGET_CPU_ARM64
  // Code meant for the arm64 architecture here.
    errorMessage = [NSString stringWithFormat:@"unhandled exception caught, si_signo: %d  /si_code: %s  /si_addr: %p /rip: %p",
                    info->si_signo, (info->si_code == SEGV_MAPERR) ? "SEGV_MAPERR" : "SEGV_ACCERR", info->si_addr, (unsigned long*)uContext->uc_mcontext->__ss.__pc];
#elif TARGET_CPU_X86_64
  // Code meant for the x86_64 architecture here.
    errorMessage = [NSString stringWithFormat:@"unhandled exception caught, si_signo: %d  /si_code: %s  /si_addr: %p /rip: %p",
    info->si_signo, (info->si_code == SEGV_MAPERR) ? "SEGV_MAPERR" : "SEGV_ACCERR", info->si_addr, (unsigned long*)uContext->uc_mcontext->__ss.__rip];
#endif

    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", errorMessage]);
    
    //err msg
    logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: %@", [[NSThread callStackSymbols] description]]);
    
    //set flag
    wasReported = YES;
    
    //start app-specific code
    #ifdef IS_APP
    
    //error info dictionary
    NSMutableDictionary* errorInfo = nil;
    
    //alloc
    errorInfo = [NSMutableDictionary dictionary];
    
    //add main error msg
    errorInfo[KEY_ERROR_MSG] = @"ERROR: unrecoverable fault";
    
    //add sub msg
#if TARGET_CPU_ARM64
  // Code meant for the arm64 architecture here.
    errorInfo[KEY_ERROR_SUB_MSG] = [NSString stringWithFormat:@"si_signo: %d / rip: %p", info->si_signo, (unsigned long*)uContext->uc_mcontext->__ss.__pc];
#elif TARGET_CPU_X86_64
  // Code meant for the x86_64 architecture here.
    errorInfo[KEY_ERROR_SUB_MSG] = [NSString stringWithFormat:@"si_signo: %d / rip: %p", info->si_signo, (unsigned long*)uContext->uc_mcontext->__ss.__rip];
#endif

    
    //set error URL
    errorInfo[KEY_ERROR_URL] = FATAL_ERROR_URL;
    
    //fatal error
    // ->agent should exit
    errorInfo[KEY_ERROR_SHOULD_EXIT] = [NSNumber numberWithBool:YES];
    
    //display error msg
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]) displayErrorWindow:errorInfo];
    
    //end app-specific code
    #endif
    
    return;
}
