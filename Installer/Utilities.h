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
BOOL isInstalled();

//start an NSTask
NSUInteger execTask(NSString* path, NSArray* arguments);

//get current version
NSString* getVersion();

//is current OS version supported?
// ->for now, just OS X 10.11.* (El Capitan)
BOOL isSupportedOS();

//get OS version
NSDictionary* getOSVersion();

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion();

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

#endif
