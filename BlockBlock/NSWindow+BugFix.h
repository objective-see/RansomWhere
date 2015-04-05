//
//  NSWindow+BugFix.h
//  PopoverMenulet
//
//  Created by Julián Romero on 17/04/14.
//  Copyright (c) 2014 Wuonm Web Services S.L. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* This is to fix a bug on 10.7+ that prevent NSTextFields inside NSPopovers to get the focus. */

@interface NSWindow (BugFix)

@end
