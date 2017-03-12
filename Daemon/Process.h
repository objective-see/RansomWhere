//
//  Process.h
//  RansomWhere
//
//  Created by Patrick Wardle on 02/22/17.
//  Copyright (c) Objective-See. All rights reserved.
//

#import "Binary.h"
#import <Foundation/Foundation.h>

@interface Process : NSObject
{

}

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//type
// used by process mon
@property u_int16_t type;

//path
@property (nonatomic, retain) NSString* path;

//args
@property (nonatomic, retain)NSMutableArray* arguments;

//ancestors
@property (nonatomic, retain)NSMutableArray* ancestors;


//untrusted ancestor
@property (nonatomic, retain)Process* untrustedAncestor;

//binary object
// ->has path, hash, etc
@property(nonatomic, retain)Binary* binary;

//encrypted files
@property(nonatomic, retain)NSMutableDictionary* encryptedFiles;

//timestamp
@property(nonatomic, retain)NSDate* timestamp;

//was reported
// ->ensures process isn't reported on twice
@property BOOL wasReported;

/* METHODS */

//generate list of ancestors
-(void)enumerateAncestors;

//check if any of the ancestors aren't Apple
-(void)validateAncestors;

//check if process has created enough encrypted files, fast enough
-(BOOL)hitEncryptedTheshold;

@end
