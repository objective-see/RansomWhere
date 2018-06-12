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

//errors url
#define ERRORS_URL @"https://objective-see.com/errors.html"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//patreon url
#define PATREON_URL @"https://www.patreon.com/objective_see"

//old daemon destination folder
#define DAEMON_DEST_FOLDER_OLD @"/Library/RansomWhere"

//daemon destination folder
#define DAEMON_DEST_FOLDER @"/Library/Objective-See/RansomWhere"

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

//daemon source white list
#define DAEMON_SRC_WHITE_LIST @"srcWhiteList"

//daemon destination white list
#define DAEMON_DEST_WHITE_LIST @"destWhiteList"

//daemon source gray list
#define DAEMON_SRC_GRAY_LIST @"srcGrayList"

//daemon destination gray list
#define DAEMON_DEST_GRAY_LIST @"destGrayList"

//icon name
#define ALERT_ICON @"alertIcon.png"

//delete user pref
#define FULL_UNINSTALL 0

//keep user prefs
#define PARTIAL_UNINSTALL 1

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

//installed apps
#define BASELINED_FILE @"installedApps.plist"

//path to launchctl
#define LAUNCHCTL @"/bin/launchctl"

//action to install
// ->also button title
#define ACTION_INSTALL @"Install"

//action to uninstall
// ->also button title
#define ACTION_UNINSTALL @"Uninstall"

//button title
// ->Close
#define ACTION_CLOSE @"Close"

//button title
// ->next
#define ACTION_NEXT @"Next »"

//button title
// ->no
#define ACTION_NO @"No"

//button title
// ->yes
#define ACTION_YES @"Yes!"

//action to kick off UI installer
#define ACTION_UNINSTALL_UI @"Uninstall_UI"

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

//whitelist
#define WHITE_LIST_FILE @"whiteList.plist"

//graylist
#define GRAY_LIST_FILE @"grayList.plist"

//install flag
#define INSTALL_FLAG "-install"

//uninstall flag
#define UNINSTALL_FLAG "-uninstall"

//OS version x
#define OS_MAJOR_VERSION_X 10

//OS version lion
#define OS_MINOR_VERSION_LION 8


#endif
