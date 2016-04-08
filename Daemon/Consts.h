//
//  Consts.h
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#ifndef Consts_h
#define Consts_h

//version
#define DAEMON_VERSION @"1.0.0"

//reset flag
#define RESET_FLAG "-reset"

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

//icon for user alert
#define ALERT_ICON @"icon.png"

//daemon destination folder
#define DAEMON_DEST_FOLDER @"/Library/RansomWhere"

//window data regex
//  ^window_ : must start w/ 'window_
//  \d+ : then match any # of digits
//  .data$ : end in .data
#define WINDOW_DATA_REGEX @"^window_\\d+.data$"

//header size
// ->just # of bytes to grab from start of file for image detections, etc
#define HEADER_SIZE 0x10

//gif ('GIF8')
// ->note: covers 'GIF87a' and 'GIF89a'
#define MAGIC_GIF 0x38464947

//png ('.PNG')
#define MAGIC_PNG 0x474E5089

//icns ('icns')
#define MAGIC_ICNS 0x736E6369

//jpg
#define MAGIC_JPG  0xE0FFD8FF

//tiff
#define MAGIC_TIFF 0x2A004D4D


#endif /* Consts_h */
