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
@synthesize isInternet;
@synthesize signingInfo;
@synthesize isGrayListed;
@synthesize isWhiteListed;

//init w/ an info dictionary
-(id)init:(NSString*)binaryPath attributes:(NSDictionary*)attributes
{
    //flag
    BOOL wasSuspended = YES;
    
    //init super
    self = [super init];
    if(nil != self)
    {
        //save path
        // ->note: always called with path
        self.path = binaryPath;
        
        //save 'baseline' flag
        self.isBaseline = [[attributes objectForKey:@"baselined"] boolValue];
        
        //check if file is from the internet
        // ->if so!, and flag passed it (i.e. its runtime eval), pause to do signing stuff, then resume!
        self.isInternet = [self isFromInternet];
        
        //TODO: TEST
        //for internet binaries and generating this obj at runtime
        // ->suspend to allow signing checks, etc to finish as they are slowww
        if( (nil != [attributes objectForKey:@"processID"]) &&
            (YES == self.isInternet) )
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ is from the internet, so suspending while generating signing info", self.path]);
            #endif
            
            //TODO: once this works, no need for error checking
            //suspend
            if(-1 == kill([[attributes objectForKey:@"processID"] intValue], SIGSTOP))
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to suspend %@ (%@), with %d", [attributes objectForKey:@"processID"], self.path, errno]);
            }
            //TODO: remove
            else
            {
                logMsg(LOG_ERR, [NSString stringWithFormat:@"suspended %@ (%@)", [attributes objectForKey:@"processID"], self.path]);
            }
            
            //set flag
            wasSuspended = YES;
        }
        
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
            
            //set flag if its graylisted
            self.isGrayListed = isInGrayList(self.signingInfo[KEY_SIGNATURE_IDENTIFIER]);
        }
        
        //resume process
        if(YES == wasSuspended)
        {
            //resume
            kill([[attributes objectForKey:@"processID"] intValue], SIGCONT);
        }
        
    }//init self

    return self;
}

//determine if a binary is from the internet
// ->done by checking the 'NSURLQuarantinePropertiesKey' key
-(BOOL)isFromInternet
{
    //flag
    BOOL fromInternet = NO;
    
    //dictionary for quarantine attributes
    NSDictionary* quarantineAttributes = nil;
    
    //get attributes
    if( (YES != [[NSURL fileURLWithPath:self.path] getResourceValue:&quarantineAttributes forKey:NSURLQuarantinePropertiesKey error:NULL]) ||
        (nil == quarantineAttributes) )
    {
        //bail
        goto bail;
    }
    
    //got quarantine attributes
    // ->means file is from the internet
    fromInternet = YES;
    
//bail
bail:
    
    return fromInternet;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"path=%@ (isApple: %d / isAppStore: %d / isBaseline: %d / isApproved: %d)", self.path, self.isApple, self.isAppStore, self.isBaseline, self.isApproved];
}


@end
