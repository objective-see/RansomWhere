//
//  Install.h
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#ifndef BlockBlock_Uninstall_h
#define BlockBlock_Uninstall_h

#import "Control.h"

@interface Uninstall : NSObject
{
    /* IVARS */
    Control* controlObj;
}

/* METHODS */
-(BOOL)uninstall;

//stop and remove launch agent
-(BOOL)uninstallLaunchAgent:(NSArray*)installedUsers;

//stop and remove launch daemon
-(BOOL)uninstallLaunchDaemon;



@property (nonatomic, retain) Control* controlObj;

@end

#endif
