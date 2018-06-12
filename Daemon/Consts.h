//
//  Consts.h
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef Consts_h
#define Consts_h

//version
// TODO: update with each new release!
#define DAEMON_VERSION @"1.2.5"

//OS version x
#define OS_MAJOR_VERSION_X 10

//OS version lion
#define OS_MINOR_VERSION_LION 8

//OS version sierra
#define OS_MINOR_VERSION_SIERRA 12

//product url
#define PRODUCT_URL @"https://objective-see.com/products/ransomwhere.html"

//product version url
#define PRODUCT_VERSIONS_URL @"https://objective-see.com/products.json"

//install update flag
#define UPDATE_INSTALL 0

//ignore update flag
#define UPDATE_IGNORE 1

//reset flag
#define RESET_FLAG "-reset"

//path to fsevents devices
#define DEVICE_FSEVENTS "/dev/fsevents"

//path to file command
#define FILE_CMD @"/usr/bin/file"

//path to system profiler
#define SYSTEM_PROFILER @"/usr/sbin/system_profiler"

//terminate process flag
#define PROCESS_TERMINATE 0

//resume process flag
#define PROCESS_RESUME 1

//installed apps
#define BASELINED_FILE @"installedApps.plist"

//user approved binaries
#define USER_APPROVED_FILE @"approvedBinaries.plist"

//whitelist
#define WHITE_LISTED_FILE @"whiteList.plist"

//graylist
#define GRAY_LIST_FILE @"grayList.plist"

//icon for user alert
#define ALERT_ICON @"alertIcon.png"

//old daemon destination folder
#define DAEMON_DEST_FOLDER_OLD @"/Library/RansomWhere"

//daemon destination folder
#define DAEMON_DEST_FOLDER @"/Library/Objective-See/RansomWhere"

//uninstall flag
#define DAEMON_UNLOAD 0

//install flag
#define DAEMON_LOAD 1

//daemon plist name
#define DAEMON_PLIST @"com.objective-see.ransomwhere.plist"

//path to launchctl
#define LAUNCHCTL @"/bin/launchctl"

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

//jpeg
#define MAGIC_JPEG 0xDBFFD8FF

//tiff
#define MAGIC_TIFF 0x2A004D4D

//zip identifier
#define ZIP_IDENTIFIER @"com.apple.zip"

//openssl identifier
#define OPENSSL_IDENTIFIER @"com.apple.openssl"

//signing status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//code signing id
#define KEY_SIGNATURE_IDENTIFIER @"signingIdentifier"

//signing authorities
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

//signed by apple
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//from app store
#define KEY_SIGNING_IS_APP_STORE @"fromAppStore"

//key for baselined binaries
#define KEY_BASELINED_BINARY @"baselined"

//key for user-approved binaries
#define KEY_APPROVED_BINARY @"approved"

//key for running binaries
#define KEY_RUNNING_BINARY @"running"

#endif /* Consts_h */
