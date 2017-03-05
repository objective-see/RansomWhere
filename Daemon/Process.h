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

//type
// TODO: needed?
@property u_int16_t type;

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//path
@property(nonatomic, retain) NSString* path;

//args
@property (nonatomic, retain)NSMutableArray* arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* ancestors;

//TODO: set!
//untrusted ancestor
@property pid_t untrustedAncestor;

//binary object
// ->has path, hash, etc
@property(nonatomic, retain)Binary* binary;

//encrypted files
@property(nonatomic, retain)NSMutableDictionary* encryptedFiles;

//is allowed
@property BOOL isAllowed;

//was disallowed
@property BOOL wasDisallowed;

/* METHODS */

//generate list of ancestors
-(void)enumerateAncestors;

//check if process has created enough encrypted files, fast enough
-(BOOL)hitEncryptedTheshold;

@end
