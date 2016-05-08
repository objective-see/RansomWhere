//
//  Const.h
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef __RansomWhere_Consts_h
#define __RansomWhere_Consts_h

//product url
#define PRODUCT_URL @"https://objective-see.com/products/ransomwhere.html"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//daemon destination folder
#define DAEMON_DEST_FOLDER @"/Library/RansomWhere"

//daemon source path key
#define DAEMON_SRC_PATH_KEY @"srcPath"

//daemon destination path key
#define DAEMON_DEST_PATH_KEY @"destPath"

//daemon source plist key
#define DAEMON_SRC_PLIST_KEY @"srcPlist"

//daemon destination plist key
#define DAEMON_DEST_PLIST_KEY @"destPlist"

//daemon source icon key
#define DAEMON_SRC_ICON_KEY @"srcIcon"

//daemon destination icon key
#define DAEMON_DEST_ICON_KEY @"destIcon"

//icon name
#define ALERT_ICON @"alertIcon.png"

//uninstall flag
#define DAEMON_UNLOAD 0

//install flag
#define DAEMON_LOAD 1

//daemon name
#define DAEMON_NAME @"RansomWhere"

//daemon plist name
#define DAEMON_PLIST @"com.objective-see.ransomwhere.plist"

//user approved binaries
#define USER_APPROVED_BINARIES @"approvedBinaries.plist"

//path to launchctl
#define LAUNCHCTL @"/bin/launchctl"

//action to install
// ->also button title
#define ACTION_INSTALL @"Install"

//action to uninstall
// ->also button title
#define ACTION_UNINSTALL @"Uninstall"

//action to kick off UI installer
#define ACTION_UNINSTALL_UI @"Uninstall_UI"

//button title
// ->Close
#define ACTION_CLOSE @"Close"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//frame shift
// ->for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//status OK
#define STATUS_SUCCESS 0

//error msg
#define KEY_ERROR_MSG @"errorMsg"

//sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"


#endif
