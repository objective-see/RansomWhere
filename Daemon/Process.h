//
//  Process.h
//  RansomWhere
//
//  Created by Patrick Wardle on 02/22/17.
//  Copyright (c) Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* CONSTS */

//code signing keys
#define KEY_SIGNING_IS_NOTARIZED @"notarized"
#define KEY_SIGNATURE_STATUS @"signatureStatus"
#define KEY_SIGNATURE_SIGNER @"signatureSigner"
#define KEY_SIGNATURE_IDENTIFIER @"signatureID"
#define KEY_SIGNATURE_TEAM_IDENTIFIER @"teamID"
#define KEY_SIGNATURE_AUTHORITIES @"signatureAuthorities"

//code sign options
enum csOptions{csNone, csStatic, csDynamic};

//signers
enum Signer{None, Apple, AppStore, DevID, AdHoc};

//architectures
enum Architectures{ArchUnknown, ArchAppleSilicon, ArchIntel};

//cs options
#define CS_STATIC_CHECK YES

/* OBJECT: PROCESS */

@interface Process : NSObject

/* PROPERTIES */

//pid
@property pid_t pid;

//ppid
@property pid_t ppid;

//rpid
@property pid_t rpid;

//event
// exec, fork, exit
@property u_int32_t event;

//cpu type
@property NSUInteger architecture;

//exit code
@property int exit;

//audit token
@property(nonatomic, retain)NSData* _Nullable auditToken;

//name
@property(nonatomic, retain)NSString* _Nullable name;

//path
@property(nonatomic, retain)NSString* _Nullable path;

//args
@property(nonatomic, retain)NSMutableArray* _Nonnull arguments;

//ancestors
@property(nonatomic, retain)NSMutableArray* _Nonnull ancestors;

//platform binary
@property(nonatomic, retain)NSNumber* _Nonnull isPlatformBinary;

//csflags
@property(nonatomic, retain)NSNumber* _Nonnull csFlags;

//cd hash
@property(nonatomic, retain)NSData* _Nonnull cdHash;

//signing ID
@property(nonatomic, retain)NSString* _Nonnull signingID;

//team ID
@property(nonatomic, retain)NSString* _Nonnull teamID;

//signing info
// manually generated via CS APIs if `codesign:TRUE` is set
@property(nonatomic, retain)NSMutableDictionary* _Nonnull signingInfo;

//script
@property(nonatomic, retain)NSString* _Nullable script;

//encrypted files
@property(nonatomic, retain)NSMutableDictionary* _Nullable encryptedFiles;

//pid version
@property(nonatomic, retain)NSNumber* _Nullable pidVersion;

@property BOOL alertShown;
@property NSInteger rule;


/* METHODS */

//inits
-(id _Nonnull)initWithToken:(audit_token_t)token;
-(id _Nullable)initWithES:(const es_message_t* _Nonnull)message;

@end

