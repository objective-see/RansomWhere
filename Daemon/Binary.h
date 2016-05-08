//
//  Process.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Binary : NSObject
{

}

/* PROPERTIES */

//binary path
@property (nonatomic, retain)NSString* path;

//binary name
@property (nonatomic, retain)NSString* name;

//signing info
@property(nonatomic, retain)NSDictionary* signingInfo;

//flag indicating binary belongs to Apple OS
@property BOOL isApple;

//flag indicating binary is from official App Store
@property BOOL isAppStore;

//flag indicating binary was present at baseline
@property BOOL isBaseline;

//flag indicating binary was approved
@property BOOL isApproved;

//flag indicating binary is from the internet
@property BOOL isInternet;

//whitelisted (via signing auth)
@property BOOL isWhiteListed;

//graylisted (via signing id)
@property BOOL isGrayListed;

/* METHODS */

//init w/ an info dictionary
-(id)init:(NSString*)path attributes:(NSDictionary*)attributes;

@end
