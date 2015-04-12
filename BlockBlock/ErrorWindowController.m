//
//  ErrorWindowController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/26/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "ErrorWindowController.h"

@interface ErrorWindowController ()

@end

@implementation ErrorWindowController

@synthesize errMsg;
@synthesize shouldExit;
@synthesize closeButton;

//configure the object/window
-(void)configure:(NSString*)errorMessage shouldExit:(BOOL)exitOnClose
{
    //set error msg
    self.errMsg.stringValue = errorMessage;
    
    //save exit
    self.shouldExit = exitOnClose;
    
    //set delegate
    [self.window setDelegate:self];
    
    return;
}

//display (show) window
-(void)display
{
    //center it
    [self.window center];
    
    //show (now configured), alert
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make close button active
    [self.window makeFirstResponder:closeButton];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    return;
}

//invoked when user clicks '?' (help button)
// ->error situation
- (IBAction)help:(id)sender
{
    //url
    NSURL *helpURL = nil;

    //build help URL
    helpURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#errors", PRODUCT_URL]];
    
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:helpURL];
    
    return;
}

//invoked when user clicks 'Close'
// ->tell window to close
-(IBAction)close:(id)sender
{
    //close
    [self.window close];
    
    return;
}


//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //check if should exit process
    // ->e.g. an error during install, etc
    if(YES == self.shouldExit)
    {
        //exit
        [NSApp terminate:self];
    }
    
    //set strong instance var to nil
    // ->will tell ARC, its finally ok to release us :)
    //self.instance = nil;
    
    return;
}

@end
