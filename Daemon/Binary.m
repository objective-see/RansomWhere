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

@implementation Binary

@synthesize name;
@synthesize path;
@synthesize isApple;
@synthesize identifier;
@synthesize isApproved;
@synthesize isAppStore;
@synthesize isBaseline;
@synthesize signingInfo;
@synthesize isGrayListed;
@synthesize isWhiteListed;

//init binary object
// ->generates signing info, classifies binary, etc
-(id)init:(NSString*)binaryPath
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //not a full path?
        if(YES != [binaryPath hasPrefix:@"/"])
        {
            //try find via 'which'
            self.path = which(binaryPath);
            if(nil == self.path)
            {
                //stuck with short path
                self.path = binaryPath;
            }
        }
        //full path
        // use as is
        else
        {
            //save path
            // ->note: always called with path
            self.path = binaryPath;
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
            }
        }
        
        //generate id
        // ->either (validated) signing id, or sha256 hash
        [self generateIdentifier];
        
        //call into whitelisting logic
        // ->will set flags such as 'isBaselined', 'isAllowed', 'isWhitelisted', etc
        [whitelist classify:self];
        
    }//init self

    return self;
}

//generate id
// ->either (validated) signing id, or sha256 hash
-(void)generateIdentifier
{
    //if binary signed, use signing id
    if( (noErr == [self.signingInfo[KEY_SIGNATURE_STATUS] intValue]) &&
        (0 != [self.signingInfo[KEY_SIGNING_AUTHORITIES] count]) &&
        (nil != self.signingInfo[KEY_SIGNATURE_IDENTIFIER]) )
    {
        //user signing id
        self.identifier  = self.signingInfo[KEY_SIGNATURE_IDENTIFIER];
    }
    //generate sha256 hash unsigned, etc binaries
    else
    {
        //hash
        self.identifier = hashFile(self.path);
    }

    return;
}

//format signing info
-(NSString*)formatSigningInfo
{
    //signing info
    NSMutableString* csSummary = nil;
    
    //init
    csSummary = [NSMutableString string];
    
    //process
    switch([self.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //happily signed
        case noErr:
            
            //append to summary
            [csSummary appendFormat:@" validly signed"];
            
            //item signed by apple
            if(YES == [self.signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
            {
                //append to summary
                [csSummary appendFormat:@" by Apple"];
            }
            //item signed, third party/ad hoc, etc
            else
            {
                //from app store?
                if(YES == [self.signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue])
                {
                    //append to summary
                    [csSummary appendFormat:@" from the App Store"];
                }
                //something else
                // ->dev id/ad hoc? 3rd-party?
                else
                {
                    //append to summary
                    [csSummary appendFormat:@" with a Apple Dev-ID || ad-hoc"];
                }
            }
            
            break;
            
        //unsigned
        case errSecCSUnsigned:
            
            //append to summary
            [csSummary appendFormat:@" unsigned"];
    
            break;
            
        //everything else
        // ->other signing errors
        default:
            
            //append to summary
            [csSummary appendFormat:@" has a signing issue"];
            
            break;
    }
    
    return csSummary;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"path=%@ (isApple: %d / isAppStore: %d / isBaseline: %d / isApproved: %d / isWhiteListed: %d / isGrayListed: %d / signing info:%@)", self.path, self.isApple, self.isAppStore, self.isBaseline, self.isApproved, self.isWhiteListed, self.isGrayListed, self.signingInfo];
}

@end
