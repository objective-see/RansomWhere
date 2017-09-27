//
//  Exception.h
//  RansomWhere (Shared)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <syslog.h>
#import <signal.h>

//install exception/signal handlers
void installExceptionHandlers(void);

//exception handler for Obj-C exceptions
void exceptionHandler(NSException *exception);

//signal handler for *nix style exceptions
void signalHandler(int signal, siginfo_t *info, void *context);




