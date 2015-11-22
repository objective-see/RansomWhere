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

//list of installed launch agents
// ->during upgrade, want to upgrade all
@property NSMutableArray* installedLaunchAgents;

//flag indicating core (daemon) should be started
@property BOOL shouldStartDaemon;

/* METHODS */

//main install method
-(BOOL)install;

//check if any component is installed
-(NSUInteger)installState;

//get list of all users its installed for 
-(NSMutableArray*)allInstalledUsers;

//install launch agent
-(BOOL)installLaunchAgent:(NSMutableArray*)installedUsers isUpgrade:(BOOL)isAnUpgrade;

//install launch daemon
-(BOOL)installLaunchDaemon;

//install kext
// ->copy kext (bundle) to /Library/Extensions and set permissions
-(BOOL)installKext;

//check if install is to a newer version
-(BOOL)isUpgrade;

//load the template launch item plist
-(NSMutableDictionary*)loadLaunchItemPlist;

@end

#endif
