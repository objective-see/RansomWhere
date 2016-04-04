//
//  Process.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Process : NSObject
{

}

/* PROPERTIES */

//process id
//@property (nonatomic, retain)NSNumber* pid;

//process path
@property (nonatomic, retain)NSString* path;

//process name
@property (nonatomic, retain)NSString* name;

//process bundle
// ->only for apps
@property (nonatomic, retain)NSBundle* bundle;

//flag indicating binary belongs to Apple OS
@property BOOL isApple;

/* METHODS */

//init function
-(id)initWithPid:(pid_t)processID infoDictionary:(NSDictionary*)infoDictionary;

@end
