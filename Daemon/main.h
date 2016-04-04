//
//  main.h
//  Daemon
//
//  Created by Patrick Wardle on 4/2/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import <Foundation/Foundation.h>

//global process list
extern NSMutableDictionary* processList;

/* FUNCTIONS */

//init process list
// ->make process objects of all currently running processes
void initProcessList();

#endif /* main_h */
