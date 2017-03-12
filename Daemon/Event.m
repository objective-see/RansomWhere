//
//  Event.m
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright (c) 2016 Patrick Wardle. All rights reserved.
//

#import "main.h"
#import "Event.h"
#import "Binary.h"
#import "Logging.h"
#import "Utilities.h"

@implementation Event

@synthesize flags;
@synthesize process;
@synthesize filePath;
@synthesize ancestorTriggered;

//init
-(id)init:(NSString*)fsPath fsProcess:(Process*)fsProcess fsEvent:(kfs_event_a *)fsEvent;
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save flags
        self.flags = [NSNumber numberWithUnsignedShort:fsEvent->type];
        
        //save file path
        self.filePath = fsPath;
        
        //process
        self.process = fsProcess;
    }
    
//bail
bail:
    
    return self;
}

//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"(%@) %@ -> %@ (flags: %@)", self.process, self.process.binary, self.filePath, self.flags];
}


@end

