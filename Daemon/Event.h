//
//  Event.h
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#import "fsEvents.h"
#import <Foundation/Foundation.h>

@class Binary;

@interface Event : NSObject
{
    
}

/* PROPERTIES */

//flags
@property (nonatomic, retain)NSNumber* flags;

//file path
@property (nonatomic, retain)NSString* filePath;

//process id
@property (nonatomic, retain)NSNumber* processID;

//binary object
@property (nonatomic, retain)Binary* binary;

//process path
//@property (nonatomic, retain)NSString* processPath;

/* PROPERTIES */

//init
-(id)initWithParams:(NSString*)path binary:(Binary*)bin fsEvent:(kfs_event_a *)fsEvent;

@end