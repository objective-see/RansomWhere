//
//  Event.m
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright (c) 2016 Patrick Wardle. All rights reserved.
//

#import "Event.h"
#import "Binary.h"
#import "Utilities.h"

@implementation Event

@synthesize flags;
@synthesize binary;
@synthesize filePath;
@synthesize processID;

//init
-(id)init:(NSString*)path binary:(Binary*)bin fsEvent:(kfs_event_a *)fsEvent
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save flags
        self.flags = [NSNumber numberWithUnsignedShort:fsEvent->type];
        
        //save file path
        self.filePath = path;
        
        //save binary
        self.binary = bin;
        
        //save process id
        self.processID = [NSNumber numberWithUnsignedInt:fsEvent->pid];
    }
    
//bail
bail:
    
    return self;
}

//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"(%@) %@ -> %@ (flags: %@)", self.processID, self.binary, self.filePath, self.flags];
}


@end

