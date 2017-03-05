//
//  Process.m
//  RansomWhere (Daemon)
//
//  Created by Patrick Wardle on 2/22/17.
//  Copyright (c) Objective-See. All rights reserved.
//

#import "main.h"
#import "Consts.h"
#import "Process.h"
#import "Logging.h"
#import "Utilities.h"

@implementation Process

@synthesize pid;
@synthesize path;
@synthesize ppid;
@synthesize ancestors;
@synthesize arguments;
@synthesize isAllowed;
@synthesize wasDisallowed;
@synthesize encryptedFiles;
@synthesize untrustedAncestor;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc args
        arguments = [NSMutableArray array];
        
        //alloc parents
        ancestors  = [NSMutableArray array];
        
        //alloc encrypted file
        encryptedFiles = [NSMutableDictionary dictionary];
        
        //init pid
        self.pid = -1;
        
        //init ppid
        self.ppid = -1;
        
        //init untrusted ancestor
        self.untrustedAncestor = -1;
    }
    
    return self;
}

//generate list of ancestors
-(void)enumerateAncestors
{
    //current process id
    pid_t currentPID = -1;
    
    //parent pid
    pid_t parentPID = -1;
    
    //start with current process
    currentPID = self.pid;
    
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
        
        //update
        currentPID = parentPID;
        
        //add
        [self.ancestors addObject:[NSNumber numberWithInt:parentPID]];
    }
    
    return;
}

//'refresh' encrypted file list
// ->remove ones that are too old (5 seconds)
-(void)refreshEncrytedFiles
{
    //time stamps
    NSDate* timestamp = nil;
    
    //check each
    // ->removing any that are too old
    for(NSString* encryptedFile in self.encryptedFiles.allKeys)
    {
        //get timestamp
        timestamp = self.encryptedFiles[encryptedFile];
        
        //remove if older than 5 seconds
        if([timestamp timeIntervalSinceNow] > 5)
        {
            //remove
            [self.encryptedFiles removeObjectForKey:encryptedFile];
        }
    }
    
    return;
}


//check if process has created enough encrypted files, fast enough
-(BOOL)hitEncryptedTheshold
{
    //first refresh list
    // ->removes any stale files
    [self refreshEncrytedFiles];
    
    //now, we know they are recent enough
    // ->just check the count of encrypted files
    return (self.encryptedFiles.count <= 3);
}

@end
