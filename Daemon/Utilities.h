//
//  Utilities.h
//  RansomWhere
//
//  Created by Patrick Wardle on 10/31/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef __RansomWhere__Utilities__
#define __RansomWhere__Utilities__

#import <Foundation/Foundation.h>

//TODO: cleanup unneeded function declarations

//query interwebz to get latest version
NSString* getLatestVersion();

//enumerate all running processes
NSMutableArray* enumerateProcesses();

//get all user home directories
NSMutableArray* getUserHomeDirs();

//return path to launch daemon's plist
NSString* launchDaemonPlist();

//return path to app support directory
// ->~/Library/Application Support/<app bundle id>
NSString* supportDirectory();

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//given a path to an application
// ->gets app's info dictionary
NSDictionary* getAppInfo(NSString* appPath);

//determine if a file is from the app store
// ->gotta be signed w/ Apple Dev ID & have valid app receipt
BOOL fromAppStore(NSString* path);

//wait for a a plist
// ->then extract a value for a key
id getValueFromPlist(NSString* plistFile, NSString* key, float maxWait);

//given a pid and process name, try to find full path
NSString* getFullPath(NSNumber* processID, NSString* processName, BOOL tryWhich);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//bring an app to foreground (to get an icon in the dock) or background
void transformProcess(ProcessApplicationTransformState location);

//get info about current logged in/active user
NSDictionary* getCurrentConsoleUser();

//generate list of all installed applications
// ->done via system_profiler, w/ 'SPApplicationsDataType' flag
NSMutableArray* enumerateInstalledApps();

//get all users
NSMutableArray* getUsers();

//get version of self
NSString* getDaemonVersion();

//determine if there is a new version
BOOL isNewVersion(NSMutableString* versionString);

//get GUID (really just computer's MAC address)
// ->from Apple's 'Get the GUID in OS X' (see: 'Validating Receipts Locally')
NSData* getGUID();

//check if current OS version is supported
// ->for now, just...?
BOOL isSupportedOS();

//get OS version
NSDictionary* getOSVersion();

//get path to app's (self) 'Info.plist' file
NSString* infoPlistFile();

//given a pid, get its parent (ppid)
pid_t getParentID(int pid);

//load or unload the launch daemon via '/bin/launchctl'
void controlLaunchItem(NSUInteger action, NSString* plist);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//determine if a file is encrypted via entropy
BOOL isEncrypted(NSString* path);

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
