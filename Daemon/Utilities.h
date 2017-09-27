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
NSString* getLatestVersion(void);

//enumerate all running processes
NSMutableArray* enumerateProcesses(void);

//return path to launch daemon's plist
NSString* launchDaemonPlist(void);

//return path to app support directory
// ->~/Library/Application Support/<app bundle id>
NSString* supportDirectory(void);

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath);

//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path);

//determine if a file is from the app store
// ->gotta be signed w/ Apple Dev ID & have valid app receipt
BOOL fromAppStore(NSString* path);

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments);

//get info about current logged in/active user
NSDictionary* getCurrentConsoleUser(void);

//generate list of all installed applications
// ->done via system_profiler, w/ 'SPApplicationsDataType' flag
NSMutableArray* enumerateInstalledApps(void);

//get all internal apps of an app
// ->login items, helper apps in frameworks, etc
NSMutableArray* enumerateInternalApps(NSString* parentApp);

//get version of self
NSString* getDaemonVersion(void);

//determine if there is a new version
BOOL isNewVersion(NSMutableString* versionString);

//get GUID (really just computer's MAC address)
// ->from Apple's 'Get the GUID in OS X' (see: 'Validating Receipts Locally')
NSData* getGUID(void);

//check if current OS version is supported
// ->for now, just...?
BOOL isSupportedOS(void);

//get OS version
NSDictionary* getOSVersion(void);

//get path to app's (self) 'Info.plist' file
NSString* infoPlistFile(void);

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
BOOL isImage(NSData* header);

//examines header for gzip signatures (e.g. '1f 8b 08')
BOOL isGzip(NSData* header);

//given a bundle
// ->find its executable
NSString* findAppBinary(NSString* appPath);

//load a file into an NSSet
NSSet* loadSet(NSString* filePath);

//given a pid, get its parent (ppid)
pid_t getParentID(int pid);

//check if process is alive
BOOL isProcessAlive(pid_t processID);

//sha256 a file
NSString* hashFile(NSString* filePath);

//given a 'short' path or process name
// ->find the full path by scanning $PATH
NSString* which(NSString* processName);

#endif /* defined(__BlockBlock__Utilities__) */
