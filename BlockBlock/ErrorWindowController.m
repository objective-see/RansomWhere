//
//  ErrorWindowController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/26/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import "Logging.h"
#import "ErrorWindowController.h"

@interface ErrorWindowController ()

@end

@implementation ErrorWindowController

@synthesize errMsg;
@synthesize shouldExit;
@synthesize closeButton;

@synthesize instance;

//configure the object/window
-(void)configure:(NSString*)errorMessage shouldExit:(BOOL)exitOnClose
{
    //set error msg
    self.errMsg.stringValue = errorMessage;
    
    //save exit
    self.shouldExit = exitOnClose;
    
    //save instance
    // ->needed to ensure window isn't ARC-dealloc'd when this function returns
    self.instance = self;
    
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
    
    return;
}

//invoked when user clicks '?' (help button)
- (IBAction)help:(id)sender
{
    //load website w/ #anchor
    
    //TODO get erorr and append it to url as anchor?
    
    NSURL *URL = [NSURL URLWithString:@"http://google.com"];
    
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

//invoked when user clicks 'Close'
// ->close window and exit process if 'shouldExit' iVar is set
-(IBAction)close:(id)sender
{
    //close
    [self.window close];
    
    //check if should exit process
    if(YES == self.shouldExit)
    {
        //exit
        [NSApp terminate:self];
    }
    
    return;
}


//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //bdg msg
    logMsg(LOG_DEBUG, @"error popup window - windowWillClose()");
    
    //check if should exit process
    // ->e.g. an error during install, etc
    if(YES == self.shouldExit)
    {
        //exit
        [NSApp terminate:self];
    }
    
    //set strong instance var to nil
    // ->will tell ARC, its finally ok to release us :)
    self.instance = nil;
    
    return;
}

@end
