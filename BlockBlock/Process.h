//
//  Process.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Process : NSObject
{
    //pid
    pid_t pid;
    
    //uid
    uid_t uid;
    
    //app bundle
    // ->only for apps of course...
    NSBundle* bundle;
        
    //process's full path
    // ->e.g. /Applications/Calculator.app/Contents/MacOS/Calculator
    NSString* path;
    
    //process's name
    // ->e.g Calculator
    NSString* name;
    
    //icon
    NSImage* icon;
    
}

@property pid_t pid;
@property uid_t uid;
@property (nonatomic, retain)NSImage* icon;
@property (nonatomic, retain)NSString* path;
@property (nonatomic, retain)NSString* name;
@property (nonatomic, retain)NSBundle* bundle;

//init function
-(id)initWithPid:(pid_t)processID infoDictionary:(NSDictionary*)infoDictionary;

//gets an icon path for an app
//-(NSString*)getIconPath;

//get an icon for a process
-(NSImage*)getIconForProcess;

//get UID for process (by pid)
-(void)determineUID;

@end
