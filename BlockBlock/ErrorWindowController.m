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

@synthesize errorURL;
@synthesize shouldExit;
@synthesize closeButton;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//configure the object/window
-(void)configure:(NSDictionary*)errorInfo
{
    //set error msg
    self.errMsg.stringValue = errorInfo[KEY_ERROR_MSG];
    
    //set error sub msg
    self.errSubMsg.stringValue = errorInfo[KEY_ERROR_SUB_MSG];
    
    //save exit
    self.shouldExit = [errorInfo[KEY_ERROR_SHOULD_EXIT] boolValue];
    
    //grab optional error url
    if(nil != errorInfo[KEY_ERROR_URL])
    {
        //extract/convert
        self.errorURL = [NSURL URLWithString:errorInfo[KEY_ERROR_URL]];
    }
    
    //when exiting
    // ->change 'close' to 'exit'
    if(YES == self.shouldExit)
    {
        //change title
        self.closeButton.title = @"Exit";
    }
    
    //for fatal errors
    // ->change 'Info' to 'help fix'
    if(YES == [[self.errorURL absoluteString] isEqualToString:FATAL_ERROR_URL])
    {
        //change title
        self.infoButton.title = @"Help Fix";
    }
    
    //set delegate
    [self.window setDelegate:self];
    
    return;
}

//display (show) window
-(void)display
{
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
    //if a url was specified
    // ->use that one
    if(nil != self.errorURL)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:self.errorURL];
    }
    //use default URL
    else
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@#errors", PRODUCT_URL]]];
    }
    
    //when error should cause an exit
    // ->close window here (to trigger exit)
    if(YES == self.shouldExit)
    {
        //close
        [self.window close];
    }

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
        //dbg msg
        logMsg(LOG_ERR, @"terminating agent");
        
        //exit
        [NSApp terminate:self];
    }
    
    return;
}

@end
