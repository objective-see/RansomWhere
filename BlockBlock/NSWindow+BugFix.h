//
//  NSWindow+BugFix.h
//  PopoverMenulet
//

#import <Cocoa/Cocoa.h>

/* This is to fix a bug on 10.7+ that prevent NSTextFields inside NSPopovers to get the focus. */

@interface NSWindow (BugFix)

@end
