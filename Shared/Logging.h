//
//  Logging.h
//  RansomWhere (Shared)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef __RansomWhere__Logging__
#define __RansomWhere__Logging__

#import <syslog.h>
#import <Foundation/Foundation.h>

//log a msg to syslog
// ->also disk, if error
void logMsg(int level, NSString* msg);

#endif
