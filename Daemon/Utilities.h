//
//  Utilities.h
//  RansomWhere?
//
//  Created by Patrick Wardle on 10/31/14.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#ifndef __RansomWhere__Utilities__
#define __RansomWhere__Utilities__

#import <Foundation/Foundation.h>

//#import "OrderedDictionary.h"

//enumerate all running processes
NSMutableArray* enumerateProcesses();

//get all user home directories
NSMutableArray* getUserHomeDirs();

//return path to launch daemon's plist
NSString* launchDaemonPlist();

//return path to launch agent's plist
NSString* launchAgentPlist(NSString* userHomeDirectory);

//return path to kext
NSString* kextPath();

//return path to app support directory
// ->~/Library/Application Support/<app bundle id>
NSString* supportDirectory();

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
NSString* getFullPath(NSNumber* processID, NSString* processName, BOOL tryWhich);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//bring an app to foreground (to get an icon in the dock) or background
void transformProcess(ProcessApplicationTransformState location);

//get info about current logged in/active user
NSDictionary* getCurrentConsoleUser();

//generate list of all installed applications
NSMutableArray* enumerateInstalledApps();

//get all users
NSMutableArray* getUsers();

//get curent version
NSString* getVersion(NSUInteger instance);

//query interwebz to get latest version
NSString* getLatestVersion();

//determine if there is a new version
NSInteger isNewVersion(NSMutableString* errMsg);

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

//determine if a file is encrypted via entropy
BOOL isEncrypted(NSString* path);

//set permissions for file
//void setFilePermissions(NSString* file, int permissions);

//get process's path
NSString* getProcessPath(pid_t pid);

//determine if a file is signed by Apple proper
BOOL isAppleBinary(NSString* path);

//write an NSSet to file
BOOL writeSetToFile(NSSet* set, NSString* file);

//read an NSSet from file
NSMutableSet* readSetFromFile(NSString* file);

//examines header for image signatures (e.g. 'GIF87a')
BOOL isAnImage(NSData* header);


#endif /* defined(__BlockBlock__Utilities__) */
