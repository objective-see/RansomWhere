//
//  NSWindow+BugFix.m
//  PopoverMenulet
//
//  Created by Julián Romero on 17/04/14.
//  Copyright (c) 2014 Wuonm Web Services S.L. All rights reserved.
//

#import <objc/objc-class.h>
#import "NSWindow+BugFix.h"
#import "StatusBarMenu.h"
#import "AppDelegate.h"
#import "Logging.h"

@implementation NSWindow (BugFix)

+(void)load
{
    //swizzle
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(canBecomeKeyWindow)),
                                   class_getInstanceMethod(self, @selector(_canBecomeKeyWindow)));
}

//custom 'canBecomeKeyWindow'
// ->helps popover close cleanly
-(BOOL)_canBecomeKeyWindow
{
    //status bar controller
    StatusBarMenu* controller = nil;
    
    //extra foo for NSStatusBar Window
    if([self class] == NSClassFromString(@"NSStatusBarWindow"))
    {
        //get instance of status bar controller
        controller = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).statusBarMenuController;
        
        //only want to invoke this code to handle closing the popover
        // ->which happens only once!
        if( ([controller isActive]) &&
            (YES != controller.wasClosed) )
        {
            return YES;
        }
    }
    
    //(otherwise) call NSWindow implementation
    return [self _canBecomeKeyWindow];
}


@end
