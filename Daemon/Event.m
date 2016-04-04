//
//  Event.m
//  RansomWhere
//
//  Created by Patrick Wardle on 3/28/16.
//  Copyright © 2016 Patrick Wardle. All rights reserved.
//

#import "Event.h"
#import "Utilities.h"

@implementation Event

@synthesize flags;
@synthesize filePath;
@synthesize processID;
@synthesize processPath;

//init
-(id)initWithParams:(NSString*)path fsEvent:(kfs_event_a *)fsEvent procPath:(NSString*)procPath;
{
    //init super
    self = [super init];
    if(nil != self)
    {
        self.processPath = procPath;
        
        /*
        //first try get process path
        // ->might error if proc exit'd, which won't (generally) happen w/ ransomware
        self.processPath = getProcessPath(fsEvent->pid);
        if( (nil == processPath) ||
            (0 == processPath.length) )
        {
            //unset
            // ->indicate errors
            self = nil;
            
            //error
            goto bail;
        }
        */
        
        //save flags
        self.flags = [NSNumber numberWithUnsignedShort:fsEvent->type];
        
        //save file path
        self.filePath = path;
        
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
    return [NSString stringWithFormat:@"%@ -> %@", self.processID, self.filePath];
}


@end

