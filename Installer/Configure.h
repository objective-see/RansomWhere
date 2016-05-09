//
//  Configure.h
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef __RansomWhere_Configure_h
#define __RansomWhere_Configure_h

@interface Configure : NSObject
{
    
}


/* METHODS */

//determine if installed
// ->looks for daemon's plist or destination folder
-(BOOL)isInstalled;

//performs install || uninstall logic
-(BOOL)configure:(NSUInteger)parameter;

//control a launch item
// ->either load/unload the launch daemon via '/bin/launchctl'
-(BOOL)controlLaunchItem:(NSUInteger)action plist:(NSString*)plist;

//uninstall daemon
-(BOOL)uninstall:(NSUInteger)type;

@end

#endif
