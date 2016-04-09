//
//  Binary.m
//  RansomWhere (Daemon)
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Binary.h"
#import "FSMonitor.h"
#import "Logging.h"
#import "Utilities.h"

@implementation Binary

//@synthesize pid;
@synthesize name;
@synthesize path;
@synthesize isApple;
@synthesize isApproved;
@synthesize isBaseline;


//init w/ an info dictionary
-(id)init:(NSString*)binaryPath attributes:(NSDictionary*)attributes
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save path
        // ->note: always called with path
        self.path = binaryPath;
        
        //save 'baseline' flag
        self.isBaseline = [[attributes objectForKey:@"baselined"] boolValue];
        
        //save 'approved' flag
        self.isApproved = [[attributes objectForKey:@"approved"] boolValue];
        
        //determine if signed by Apple proper
        self.isApple = isAppleBinary(self.path);
        
    }//init self

    return self;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"path=%@ (isApple:%d / isBaseline: %d / isApproved: %d", self.path, self.isApple, self.isBaseline, self.isApproved];
}


@end
