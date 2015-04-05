//
//  PluginBase.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "PluginBase.h"
#import "WatchEvent.h"

#define kErrFormat @"%@ not implemented in subclass %@"
#define kExceptName @"BB Plugin"



@implementation PluginBase

@synthesize type;
@synthesize alertMsg;
@synthesize ignoreKids;
@synthesize watchPaths;
@synthesize description;


//init
-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //super
    self = [super init];
    
    if(nil != self)
    {
        //init paths
        watchPaths = [NSMutableArray array];
        
        //iterate over all watch paths
        // ->expand if necessary and save
        for(NSString* watchPath in watchItemInfo[@"paths"])
        {
            //save path
            [self.watchPaths addObject:watchPath];
        }
        
        //save description from plugin's .plist
        self.description = watchItemInfo[@"description"];
        
        //save alert msg from plugin's .plist
        self.alertMsg = watchItemInfo[@"alert"];
        
        //save flag about match level
        self.ignoreKids = [watchItemInfo[@"ignoreKids"] boolValue];
        
    
        
    }
    
    return self;
}

/* OPTIONAL METHODS */

//stubs for inherited methods
// ->these aren't required, so will just return here if not invoked in child classes

//callback when watch event is allowed
-(void)allow:(WatchEvent *)watchEvent
{
    return;
}

//new agent
// ->refresh internal list, etc if needed
-(void)newAgent:(NSDictionary*)registeredUsers
{
    return;
}

/* REQUIRED METHODS */

//stubs for inherited methods
// ->all just throw exceptions as they should be implemented in sub-classes
-(BOOL)block:(WatchEvent*)watchEvent
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return NO;
}

-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return NO;
    
}

-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return nil;
}

-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    @throw [NSException exceptionWithName:kExceptName
                                   reason:[NSString stringWithFormat:kErrFormat, NSStringFromSelector(_cmd), [self class]]
                                 userInfo:nil];
    return nil;
}

@end
