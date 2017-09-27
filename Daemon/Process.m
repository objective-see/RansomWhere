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
@synthesize timestamp;
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
        
        //set start time
        timestamp = [NSDate date];
        
        //init pid
        self.pid = -1;
        
        //init ppid
        self.ppid = -1;
        
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
    
    //add parent
    if(-1 != self.ppid)
    {
        //add
        [self.ancestors addObject:[NSNumber numberWithInt:self.ppid]];
        
        //set current to parent
        currentPID = self.ppid;
    }
    //don't know parent
    // ->just start with self
    else
    {
        //start w/ self
        currentPID = self.pid;
    }
    
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

//check if any of the ancestors aren't Apple/trusted
-(void)validateAncestors
{
    //ancestor
    Process* ancestor = nil;
    
    //scan all
    for(NSNumber* ancestorPID in self.ancestors)
    {
        //get process object for parent
        ancestor = processMonitor.processes[ancestorPID];
        
        //skip any that don't have a process obj
        // ->shouldn't happen on 'version' with full proc monitor
        if(nil == ancestor)
        {
            //skip
            continue;
        }
        
        //skip if apple, but not graylisted
        if( (YES == ancestor.binary.isApple) &&
            (YES != ancestor.binary.isGrayListed))
        {
            //skip
            continue;
        }
        
        //skip if whitelisted / baseline / allowed
        if( (YES == ancestor.binary.isWhiteListed) ||
            (YES == ancestor.binary.isBaseline) ||
            (YES == ancestor.binary.isApproved) )
        {
            //skip
            continue;
        }
        
        //ok, it's basically unknown/untrusted
        self.untrustedAncestor = ancestor;
        
        //found one
        // ->no need to keep searching
        break;
    }
    
    return;
}

//'refresh' encrypted file list
// ->remove ones that are too old (5 seconds)
-(void)refreshEncrytedFiles
{
    //sync
    @synchronized (self.encryptedFiles)
    {
        //check each
        // ->removing any that are too old
        for(NSString* encryptedFile in self.encryptedFiles.allKeys)
        {
            //remove if older than 5 seconds
            // value for 'encryptedFiles' is timestamp
            if([self.encryptedFiles[encryptedFile] timeIntervalSinceNow] > 5)
            {
                //remove
                [self.encryptedFiles removeObjectForKey:encryptedFile];
            }
        }
        
    }//sync
    
    return;
}

//check if process has created enough encrypted files, fast enough
-(BOOL)hitEncryptedTheshold
{
    //flag
    BOOL hitTheshold = NO;
    
    //first refresh list
    // ->removes any stale files
    [self refreshEncrytedFiles];
    
    @synchronized (self.encryptedFiles)
    {
        //now, we know they are recent enough
        // ->just check the count of encrypted files
        hitTheshold = (self.encryptedFiles.count >= 3);
    }
    
    return hitTheshold;
}

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"pid=%d, path=%@, ancestors=%@, untrusted ancestor=%@ ", self.pid, self.path, self.ancestors, self.untrustedAncestor];
}


@end
