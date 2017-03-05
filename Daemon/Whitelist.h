//
//  Whitelist.h
//  Daemon
//
//  Created by Patrick Wardle on 3/4/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Whitelist_h
#define Whitelist_h

#import "Binary.h"

@interface Whitelist : NSObject
{
    
}

/* PROPERTIES */

//white-listed (hardcoded) developer IDs
@property(nonatomic, retain)NSMutableArray* whitelistedDevIDs;

//baselined binaries
@property(nonatomic, retain)NSMutableDictionary* baselinedBinaries;

//user approved binaries
@property(nonatomic, retain)NSMutableDictionary* userApprovedBinaries;

/* METHODS */

//enumerate all installed app
// ->only done once, unless -reset
-(void)baseline;

//load whitelisted dev IDs, baselined & allowed apps
-(void)loadItems;

//update list of approved apps
// ->when user 'allows'/apporoves app
-(void)updateApproved:(Binary*)binary;

//determine if binary is allowed
// ->either baselined or approved based on path *and* hash
-(BOOL)isWhitelisted:(Binary*)binary;

@end

#endif /* Whitelist_h */
