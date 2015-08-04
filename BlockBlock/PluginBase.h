//
//  PluginBase.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "fsEvents.h"

@class WatchEvent;

@interface PluginBase : NSObject
{

    //iVars
    
    //paths to watch
    NSMutableArray* watchPaths;

    //msg to display
    NSString* alertMsg;
    
    //description
    NSString* description;
    
    //type
    // ->file, command, browser ext
    NSUInteger type;
    
    //flag to ignore things under top level dir
    BOOL ignoreKids;

}

@property BOOL ignoreKids;
@property NSUInteger type;
@property(retain, nonatomic)NSString* description;
@property(retain, nonatomic)NSString* alertMsg;
@property(nonatomic, retain)NSMutableArray* watchPaths;



//METHODS

//init method
-(id)initWithParams:(NSDictionary*)watchItemInfo;

//process an event
// ->extra processing to decide if an alert should be shown
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent;

//block an event
// ->delete binary, files (plist), etc
-(BOOL)block:(WatchEvent*)watchEvent;

//allow an event
// ->maybe update the original (saved) file?
-(void)allow:(WatchEvent*)watchEvent;

//extract name of startup item
// ->e.g. name of kext, launch item, etc.
-(NSString*)startupItemName:(WatchEvent*)watchEvent;

//extract binary for of startup item
// ->e.g. name of kext's binary, launch item binary, etc.
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent;

//new agent
// ->refresh internal list, etc if needed
-(void)newAgent:(NSDictionary*)registeredUsers;




@end
