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

//query interwebz to get latest version
NSString* getLatestVersion();

//enumerate all running processes
NSMutableArray* enumerateProcesses();

//return path to launch daemon's plist
NSString* launchDaemonPlist();

//return path to app support directory
// ->~/Library/Application Support/<app bundle id>
NSString* supportDirectory();

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path);

//given a path to an application
// ->gets app's info dictionary
NSDictionary* getAppInfo(NSString* appPath);

//determine if a file is from the app store
// ->gotta be signed w/ Apple Dev ID & have valid app receipt
BOOL fromAppStore(NSString* path);

//given a pid and process name, try to find full path
NSString* getFullPath(NSNumber* processID, NSString* processName, BOOL tryWhich);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//get info about current logged in/active user
NSDictionary* getCurrentConsoleUser();

//generate list of all installed applications
// ->done via system_profiler, w/ 'SPApplicationsDataType' flag
NSMutableArray* enumerateInstalledApps();

//get all internal apps of an app
// ->login items, helper apps in frameworks, etc
NSMutableArray* enumerateInternalApps(NSString* parentApp);

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

//examines header for image signatures (e.g. 'GIF87a')
BOOL isAnImage(NSData* header);

//given a bundle
// ->find its executable
NSString* findAppBinary(NSString* appPath);

//load a file into an NSSet
NSSet* loadSet(NSString* filePath);

//check if binary has been graylisted
BOOL isInGrayList(NSString* path);

//check if binary's signing auth has been whitelisted
BOOL isInWhiteList(NSArray* signingAuths);

//given a 'BSD name' for a mounted filesystem (ex: '/dev/disk1s2')
// ->find the orginal disk image (dmg) that was mounted at this location
NSString* findDMG(char* mountFrom);

//given a parent
// ->finds (first) child that matches specified class name
io_service_t findChild(io_service_t parent, const char* name);


#endif /* defined(__BlockBlock__Utilities__) */
