//
//  Install.h
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//


#ifndef BlockBlock_Install_h
#define BlockBlock_Install_h

@interface Install : NSObject
{
    
}

/* PROPERTIES */


/* METHODS */

//class method
// ->check if already installed (launch agent)
+(BOOL)isInstalled;

//main install method
-(BOOL)install;

//install launch daemon
-(BOOL)installLaunchDaemon;

//install kext
// ->copy kext (bundle) to /Library/Extensions and set permissions
-(BOOL)installKext;

//install launch agent
-(BOOL)installLaunchAgent:(NSMutableArray*)installedUsers;

//create install dir
// -> /Library/BlockBlock
-(BOOL)createInstallDirectory:(NSString*)directory;

//copy binary into install directory
-(BOOL)installBinary:(NSString*)path;

//launch agent can be installed for other users
// ->so iterate over all users and save any existing launch agent paths
-(NSMutableArray*)existingLaunchAgents;

//load the template launch item plist
-(NSMutableDictionary*)loadLaunchItemPlist;

@end

#endif
