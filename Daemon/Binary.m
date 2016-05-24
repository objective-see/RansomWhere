//
//  Binary.m
//  RansomWhere (Daemon)
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"
#import "Consts.h"
#import "Binary.h"
#import "Logging.h"
#import "FSMonitor.h"
#import "Utilities.h"
#import "Enumerator.h"

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
        
        //binaries from FS monitor have nil attributes
        // ->but process might be baselined/approved, just not processed yet
        if( (nil == attributes) &&
            (YES != enumerator.processingComplete) )
        {
            //save 'baseline' flag
            self.isBaseline = [enumerator.bins2Process[KEY_BASELINED_BINARY] containsObject:binaryPath];
            
            //save 'approved' flag
            self.isApproved = [enumerator.bins2Process[KEY_APPROVED_BINARY] containsObject:binaryPath];
        }
        
        //grab values
        // ->if not specified, will just get set to 'NO'
        else
        {
            //save 'baseline' flag
            self.isBaseline = [[attributes objectForKey:KEY_BASELINED_BINARY] boolValue];
            
            //save 'approved' flag
            self.isApproved = [[attributes objectForKey:KEY_APPROVED_BINARY] boolValue];
        }
        
        //extract signing info (do this first!)
        // ->from Apple, App Store, signing authorities, etc
        self.signingInfo = extractSigningInfo(self.path);
        
        //perform more signing checks and lists
        // ->gotta be happily signed for checks though
        if(0 == [self.signingInfo[KEY_SIGNATURE_STATUS] intValue])
        {
            //set flag for signed by Apple proper
            self.isApple = [self.signingInfo[KEY_SIGNING_IS_APPLE] boolValue];
        
            //when not Apple proper
            // ->check flag for from official App Store or is whitelisted
            if(YES != isApple)
            {
                //set flag
                self.isAppStore = [self.signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue];
                
                //set flag if its whitelisted (via signing auths)
                // ->apple's bins aren't in whitelist.plist)
                self.isWhiteListed = isInWhiteList(self.signingInfo[KEY_SIGNING_AUTHORITIES]);
            }
        
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
    return [NSString stringWithFormat: @"path=%@ (isApple: %d / isAppStore: %d / isBaseline: %d / isApproved: %d / isWhiteListed: %d / isGrayListed: %d / signing info:%@)", self.path, self.isApple, self.isAppStore, self.isBaseline, self.isApproved, self.isWhiteListed, self.isGrayListed, self.signingInfo];
}

@end
