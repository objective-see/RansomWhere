//
//  Utilities.h
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef __RansomWhere__Utilities__
#define __RansomWhere__Utilities__

//check if kext is installed
// ->just checks permenant location of kext
BOOL isInstalled(void);

//start an NSTask
NSUInteger execTask(NSString* path, NSArray* arguments);

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void);

//is current OS version supported?
BOOL isSupportedOS(void);

//get OS version
NSDictionary* getOSVersion(void);

//get app's version
// ->either self, or installed version
NSString* getVersion(int instanceFlag);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//set permissions on a file
BOOL setFilePermissions(NSString* path, int permissions);

#endif
