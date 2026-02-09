//
//  file: XPCDaemonClient.h
//  project: RansomWhere? (shared)
//  description: talk to daemon via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCDaemonProto.h"

@interface XPCDaemonClient : NSObject

//xpc connection to daemon
@property (atomic, strong, readwrite)NSXPCConnection* daemon;

//get rules
// note: synchronous
-(NSDictionary*)getRules;

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences;

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//delete rule
-(void)deleteRule:(NSString*)path;

//add rule
-(void)addRule:(NSString*)path action:(NSNumber*)action;

//respond to alert
-(void)alertReply:(NSDictionary*)alert;

-(void)quit;

@end
