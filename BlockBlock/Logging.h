//
//  Logging.h
//  BlockBlock
//
//  Created by Patrick Wardle on 12/21/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#ifndef __BlockBlock__Logging__
#define __BlockBlock__Logging__

#import <syslog.h>

//init logging
// ->opens file for errors
//BOOL initLogging();

//log a msg to syslog
// ->also disk, if error
void logMsg(int level, NSString* msg);

//log msg to disk
//void writeToFile(NSString* logMsg);

#endif /* defined(__BlockBlock__Logging__) */
