//
//  Utilities.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/31/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#ifndef __BlockBlock__Utilities__
#define __BlockBlock__Utilities__

//return path to launch daemon's plist
NSString* launchDaemonPlist();

//return path to launch agent's plist
NSString* launchAgentPlist(NSString* userHomeDirectory);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//given a path to an application
// ->gets app's info dictionary
NSDictionary* getAppInfo(NSString* appPath);

//get an app's binary from its info dictionary
//NSString* getAppBinary(NSDictionary* appInfo);

//wait for a a plist
// ->then extract a value for a key
id getValueFromPlist(NSString* plistFile, NSString* key, float maxWait);

//given a 'short' path or process name
// ->find the full path by scanning $PATH
NSString* which(NSString* processName);

//given a pid and process name, try to find full path
NSString* getFullPath(NSNumber* processID, NSString* processName);

//start an NSTask
NSUInteger execTask(NSString* path, NSArray* arguments, BOOL waitUntilExit);

//bring an app to foreground (to get an icon in the dock) or background
void transformProcess(ProcessApplicationTransformState location);

//get info about current logged in/active user
NSDictionary* getCurrentConsoleUser();

//get all users
NSMutableArray* getUsers();

//get curent version
NSString* getVersion(NSUInteger instance);

//check if process is alive
BOOL isProcessAlive(pid_t processID);

//check if current OS version is supported
// ->for now, just...?
BOOL isSupportedOS();

//get OS version
NSDictionary* getOSVersion();

//get path to app's (self) 'Info.plist' file
NSString* infoPlistFile();

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//given a pid, get its parent (ppid)
pid_t getParentID(int pid);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//set permissions for file
//void setFilePermissions(NSString* file, int permissions);

//if string is too long to fit into a the (2-lines) text field
// ->truncate and insert ellipises before /file
NSString* stringByTruncatingString(NSTextField* textField, float width);

//determine if instance is daemon (background) instance
BOOL isDaemonInstance();

//determine menu mode
BOOL isMenuDark();

//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController);


#endif /* defined(__BlockBlock__Utilities__) */
