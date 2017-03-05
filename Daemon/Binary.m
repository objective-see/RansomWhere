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
@synthesize sha256Hash;
@synthesize signingInfo;
@synthesize isGrayListed;
@synthesize isWhiteListed;

//init w/ an info dictionary
//TODO: don't need attributes?
//TODO: isApproved/isBaseline logic should call into whitelist logic/method
//TODO: not signed, generate a hash
-(id)init:(NSString*)binaryPath attributes:(NSDictionary*)attributes
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save path
        // ->note: always called with path
        self.path = binaryPath;
        
        //TODO: remove this check!
        
        //binaries from FS monitor have nil attributes
        // ->but process might be baselined/approved, just not processed yet
        if( (nil == attributes) &&
            (YES != enumerator.processingComplete) )
        {
            //TODO: only base line first time (i.e. on install!!!)
            //      but make sure to also save hash! or check if they have changed
            
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
                //TODO: move isInWhiteList into WhiteList.m!
                self.isWhiteListed = isInWhiteList(self.signingInfo[KEY_SIGNING_AUTHORITIES]);
            }
        
            //only can be gray, if not white!
            if(YES != self.isWhiteListed)
            {
                //set flag if its graylisted
                self.isGrayListed = isInGrayList(self.signingInfo[KEY_SIGNATURE_IDENTIFIER]);
            }
        }
        
        //generate sha256 hash unsigned, etc binaries
        else
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"binary %@ isn't signed, so hashing", self.path]);
            #endif
            
            //hash
            self.sha256Hash = hashFile(self.path);
        }
        
    }//init self

    return self;
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
            [csSummary appendFormat:@" is validly signed"];
            
            //item signed by apple
            if(YES == [self.signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
            {
                //append to summary
                [csSummary appendFormat:@" (Apple)"];
            }
            //item signed, third party/ad hoc, etc
            else
            {
                //from app store?
                if(YES == [self.signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue])
                {
                    //append to summary
                    [csSummary appendFormat:@" (Mac App Store)"];
                }
                //something else
                // ->dev id/ad hoc? 3rd-party?
                else
                {
                    //append to summary
                    [csSummary appendFormat:@" (Apple Dev-ID/3rd-party)"];
                }
            }
            
            break;
            
        //unsigned
        case errSecCSUnsigned:
            
            //append to summary
            [csSummary appendFormat:@" is not signed"];
    
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
