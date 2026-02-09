//
//  file: XPCDaemonProtocol.h
//  project: RansomWhere? (shared)
//  description: methods exported by the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@class Event;

@protocol XPCDaemonProtocol

//get preferences
-(void)getPreferences:(void (^)(NSDictionary*))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//get rules
-(void)getRules:(void (^)(NSDictionary*))reply;

//delete rule
-(void)deleteRule:(NSString*)path;

//respond to an alert
-(void)alertReply:(NSDictionary*)alert;

//quit (user asked!)
-(void)quit;

//add rule
//-(void)addRule:(NSString*)path action:(NSUInteger)action user:(NSUInteger)user;

@end
