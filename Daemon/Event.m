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
@synthesize binary;
@synthesize filePath;
@synthesize processID;
@synthesize processHierarchy;
@synthesize untrustedAncestor;

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
        
        //default
        self.untrustedAncestor = nil;
        
        //generated process hierarchy for apple binaries
        // ->will allow for the detecting of apps using zip w/ encryption, etc
        if(YES == self.binary.isApple)
        {
            //alloc array
            processHierarchy = [NSMutableArray array];
            
            //enumerate parents
            [self generateProcessHierarchy:binary];
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"generated process hierachy: %@", self.processHierarchy]);
            #endif
            
            //check if any ancestors don't belong to apple
            for(Binary* ancestor in self.processHierarchy)
            {
                //non-apple?
                if(YES != ancestor.isApple)
                {
                    //save
                    self.untrustedAncestor = ancestor;
                    
                    //done
                    break;
                }
            }
        }
    }
    
//bail
bail:
    
    return self;
}


//generate process hierarchy
// ->note: currently only invoked for apple procs (i.e. zip)
-(void)generateProcessHierarchy:(Binary*)binary
{
    //current process id
    pid_t currentPID = -1;
    
    //parent pid
    pid_t parentPID = -1;
    
    //parent path
    NSString* parentPath = nil;

    //parent binary obj
    Binary* parentBinary = nil;
    
    //start with current process
    currentPID = self.processID.intValue;
    
    //add until we get to to end (pid 0)
    // ->or error out during the traversal
    while(YES)
    {
        //get parent pid
        parentPID = getParentID(currentPID);
        if( (0 == parentPID) ||
            (-1 == parentPID) ||
            (currentPID == parentPID) )
        {
            //bail
            break;
        }
        
        //now, get parent's path
        parentPath = getProcessPath(parentPID);
        if( (nil == parentPath) ||
            (0 == parentPath.length) )
        {
            //bail
            break;
        }
        
        //update
        currentPID = parentPID;
        
        //sync to check there's a binary obj
        @synchronized(enumerator.binaryList)
        {
            //is there an existing binary object?
            parentBinary = enumerator.binaryList[parentPath];
            if(nil != parentBinary)
            {
                //add
                [self.processHierarchy addObject:parentBinary];
                
                //next
                continue;
            }
        }
        
        //create binary object as it's new
        // ->this is kinda slow so don't do in a @sync
        parentBinary = [[Binary alloc] init:parentPath attributes:nil];
        
        //add
        [self.processHierarchy addObject:parentBinary];
        
        //sync to add
        @synchronized(enumerator.binaryList)
        {
            //add
            enumerator.binaryList[parentPath] = parentBinary;
        }
    }
    
    return;
}


//description
-(NSString*)description
{
    return [NSString stringWithFormat:@"(%@) %@ -> %@ (flags: %@)", self.processID, self.binary, self.filePath, self.flags];
}


@end

