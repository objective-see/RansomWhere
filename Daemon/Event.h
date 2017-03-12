//
//  Event.h
//  RansomWhere (Daemon)
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Process.h"
#import "fsEvents.h"
#import <Foundation/Foundation.h>

//@class Binary;

@interface Event : NSObject
{
    
}

/* PROPERTIES */

//flags
@property (nonatomic, retain)NSNumber* flags;

//file path
@property (nonatomic, retain)NSString* filePath;

//process id
@property (nonatomic, retain)Process* process;

//triggered due to ancestor
@property BOOL ancestorTriggered;

/* METHODS */

//init
-(id)init:(NSString*)path fsProcess:(Process*)fsProcess fsEvent:(kfs_event_a *)fsEvent;

@end
