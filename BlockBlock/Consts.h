//
//  Consts.h
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef BlockBlock_Consts_h
#define BlockBlock_Consts_h

//product url
#define PRODUCT_URL @"https://objective-see.com/products/blockblock.html"

//product verison url
#define PRODUCT_VERSION_URL @"https://objective-see.com/products/blockblockVersion.json"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.com/errors.html"

//wait interval
#define WAIT_INTERVAL 0.1f

//user's defaults
#define NSUSER_DEFAULTS @"Library/Preferences/com.objectivesee.BlockBlock.plist"

//kext bundle name
#define KEXT_NAME @"BlockBlock.kext"

//kext label
#define KEXT_LABEL @"com.objective-see.kext.BlockBlock"

//path to kextload
#define KEXT_LOAD @"/sbin/kextload"

//path to kextunload
#define KEXT_UNLOAD @"/sbin/kextunload"

//path to launchctl
#define LAUNCHCTL @"/bin/launchctl"

//file name for launch items' plist
#define LAUNCH_ITEM_PLIST @"com.objectiveSee.blockblock.plist"

//label for launch daemon
#define LAUNCH_DAEMON_LABEL @"com.objectiveSee.blockblock.daemon"

//label for launch daemon
#define LAUNCH_AGENT_LABEL @"com.objectiveSee.blockblock.agent"

//app path
#define APPLICATION_PATH @"/Applications/BlockBlock.app"

//app name
#define APPLICATION_NAME @"BlockBlock.app"

//binary (sub)path
#define BINARY_SUB_PATH @"Contents/MacOS/BlockBlock"

//action to run as daemon
#define ACTION_RUN_DAEMON @"daemon"

//action to run as agent
#define ACTION_RUN_AGENT @"agent"

//action to install
// ->also button title
#define ACTION_INSTALL @"Install"

//action to reinstall
// ->also button title
#define ACTION_REINSTALL @"(re)Install"

//action to upgrade
// ->also button title
#define ACTION_UPGRADE @"Upgrade"

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

/* User selections */

//block watch event
#define BLOCK_WATCH_EVENT 0

//allow watch event
#define ALLOW_WATCH_EVENT 1

//frame shift
// ->for status msg to avoid activity indicator
#define FRAME_SHIFT 45

/* IPC notification names */

//display alert (from Daemon)
#define SHOULD_DISPLAY_ALERT_NOTIFICATION @"shouldDisplayAlertNotification"

//display error (from daemon)
#define SHOULD_DISPLAY_ERROR_NOTIFICATION @"shouldDisplayErrorNotification"

//perform action in UI session
#define SHOULD_DO_USER_ACTION_NOTIFICATION @"shouldDoUserActionNotification"

//handle alert response (from Agent)
#define SHOULD_HANDLE_ALERT_NOTIFICATION @"shouldHandleAlertNotification"

//handle agent registrations (from Agent)
#define SHOULD_HANDLE_AGENT_REGISTRATION_NOTIFICATION @"shouldRegisterAgentNotification"

//launch daemon
#define RUN_INSTANCE_DAEMON 0

//launch agent
#define RUN_INSTANCE_AGENT 1

#define LAUNCH_ITEM_DAEMON 0
#define LAUNCH_ITEM_AGENT  1

//UI (agent) status
#define UI_STATUS_DISABLED 0
#define UI_STATUS_ENABLED  1

//installed state

//not installed
#define INSTALL_STATE_NONE    0

//partially (for other users)
#define INSTALL_STATE_PARTIAL 1

//fully installed (for current user)
#define INSTALL_STATE_FULL    2

//max watch events
#define MAX_WATCH_EVENTS     64

//status OK
#define STATUS_SUCCESS 0

//current (self) version instance
#define VERSION_INSTANCE_SELF 0

//installed version instance
#define VERSION_INSTANCE_INSTALLED 1

//path to fsevents devices
#define DEVICE_FSEVENTS "/dev/fsevents"

//dictionary keys

//watch event uuid
#define KEY_WATCH_EVENT_UUID @"watchEventUUID"

//alert window
#define KEY_ALERT_WINDOW @"alertWindow"

//action
#define KEY_ACTION @"action"

//remember action
#define KEY_REMEMBER @"remember"

//error msg
#define KEY_ERROR_MSG @"errorMsg"

//sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//target UUID
#define KEY_TARGET_UID @"targetUID"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"

//action param
#define KEY_ACTION_PARAM_ONE @"paramOne"

//user's id
#define KEY_USER_ID @"userID"

//user's home directory
#define KEY_USER_HOME_DIR @"userHomeDirectory"

//user's name
#define KEY_USER_NAME @"userName"

//flag for all sessions
#define UID_ALL_SESSIONS -1

//actions (for user session)

//delete login item
#define ACTION_DELETE_LOGIN_ITEM 1

//plugin types

//kext
#define PLUGIN_TYPE_KEXT 1

//launchd
#define PLUGIN_TYPE_LAUNCHD 2

//login item
#define PLUGIN_TYPE_LOGIN_ITEM 3

//cron jobs
#define PLUGIN_TYPE_CRON_JOB 4

//TODO: remove!?
//ellipis
// ->for long paths...
#define ELLIPIS @"..."

//vendor id string
#define OBJECTIVE_SEE_VENDOR "com.objective-see"

//process started
#define PROCESS_BEGAN_EVENT	0x1

//max number of items in process list
#define PROCESS_LIST_MAX_SIZE 64

//prefs
// ->first time
#define PREF_SHOW_POPOVER @"showPopover"

//prefs
// ->enable logging
#define PREF_ENABLE_LOGGING @"enableLogging"

//prefs
// ->run in passive mode
#define PREF_PASSIVE_MODE @"passiveMode"

//prefs
// ->disable update check
#define PREF_DISABLE_UPDATE_CHECK @"disableUpdateCheck"

//log file name
#define LOG_FILE_NAME @"BlockBlock.log"

//log to file flag
#define LOG_TO_FILE 0x10

#endif
