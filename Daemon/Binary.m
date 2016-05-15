//
//  Binary.m
//  RansomWhere (Daemon)
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Binary.h"
#import "FSMonitor.h"
#import "Logging.h"
#import "Utilities.h"

@implementation Binary

@synthesize name;
@synthesize path;
@synthesize isApple;
@synthesize isApproved;
@synthesize isAppStore;
@synthesize isBaseline;
@synthesize signingInfo;
@synthesize isGrayListed;
@synthesize isWhiteListed;

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
        
        //extract signing info (do this first!)
        // ->from Apple, App Store, signing authorities, etc
        self.signingInfo = extractSigningInfo(self.path);
        
        //set flag for signed by Apple proper
        self.isApple = [self.signingInfo[KEY_SIGNING_IS_APPLE] boolValue];
        
        //set flag for from official App Store
        self.isAppStore = [self.signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue];
        
        //check lists (white & gray)
        // ->gotta be happily signed for checks
        if(0 == [self.signingInfo[KEY_SIGNATURE_STATUS] intValue])
        {
            //set flag if its whitelisted (via signing auths)
            self.isWhiteListed = isInWhiteList(self.signingInfo[KEY_SIGNING_AUTHORITIES]);
            
            //only can be gray, if not white!
            if(YES != self.isWhiteListed)
            {
                //set flag if its graylisted
                self.isGrayListed = isInGrayList(self.signingInfo[KEY_SIGNATURE_IDENTIFIER]);
            }
        }
        
    }//init self

    return self;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"path=%@ (isApple: %d / isAppStore: %d / isBaseline: %d / isApproved: %d / isWhiteListed: %d / isGrayListed: %d)", self.path, self.isApple, self.isAppStore, self.isBaseline, self.isApproved, self.isWhiteListed, self.isGrayListed];
}

@end
