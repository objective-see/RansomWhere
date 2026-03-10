//
//  file: XPCListener
//  project: RansomWhere? (launch daemon)
//  description: XPC listener for connections for user components (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


@import Foundation;
#import "XPCDaemonProto.h"


@interface XPCListener : NSObject <NSXPCListenerDelegate>
{
    
}

/* PROPERTIES */

//XPC listener
@property(nonatomic, retain)NSXPCListener* listener;

//XPC connection for login item
@property(weak)NSXPCConnection* client;

/* METHODS */

//setup XPC listener
-(BOOL)initListener;

//automatically invoked
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection;

@end
