//
//  Consts.h
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#ifndef Consts_h
#define Consts_h

//path to fsevents devices
#define DEVICE_FSEVENTS "/dev/fsevents"

//path to file command
#define FILE @"/usr/bin/file"

//path to system profiler
#define SYSTEM_PROFILER @"/usr/sbin/system_profiler"

//terminate process flag
#define PROCESS_TERMINATE 0

//resume process flag
#define PROCESS_RESUME 1

//installed apps
#define INSTALLED_APPS @"installedApps.plist"

//user approved binaries
#define USER_APPROVED_BINARIES @"approvedBinaries.plist"

//window data regex
#define WINDOW_DATA_REGEX @"\\^window_\\d\\+\\.data"

#endif /* Consts_h */
