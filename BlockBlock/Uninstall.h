//
//  Install.h
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef BlockBlock_Uninstall_h
#define BlockBlock_Uninstall_h

#import "Control.h"

@interface Uninstall : NSObject
{
   
}

/* PROPERTIES */

@property (nonatomic, retain) Control* controlObj;


/* METHODS */

//uninstall
-(BOOL)uninstall:(BOOL)viaInstaller;

//stop and remove launch agent
-(BOOL)uninstallLaunchAgent:(NSArray*)installedUsers;

//stop and remove launch daemon
-(BOOL)uninstallLaunchDaemon;

//unload and remove kext
-(BOOL)uninstallKext;

//uninstall app
// ->checks location of both old and new
-(BOOL)uninstallApp;


@end

#endif
