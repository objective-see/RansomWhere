//
//  ConfigureWindowController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//
#import "Consts.h"
#import "Control.h"
#import "Logging.h"
#import "Logging.h"
#import "Install.h"
#import "Utilities.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize action;
@synthesize instance;
@synthesize statusMsg;
@synthesize buttonTitle;
@synthesize windowTitle;
@synthesize moreInfoButton;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//when window is shown
// ->make white
-(void)windowDidLoad
{
    //installed state
    NSUInteger state = INSTALL_STATE_NONE;
    
    //args
    NSArray* arguments = nil;
    
    //grab args
    arguments = NSProcessInfo.processInfo.arguments;
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //disable 'install' button if exec'd with 'ACTION_UNINSTALL_UI' (from drop-down)
    if( (arguments.count >= 2) &&
        (YES == [arguments[1] isEqualToString:ACTION_UNINSTALL_UI]) )
    {
        //disable
        self.installButton.enabled = NO;
    }

    //get state
    state = [Install installedState];
    
    //disable uninstall button if not installed for self
    if( (INSTALL_STATE_NONE == state) ||
        (INSTALL_STATE_OTHERS_ONLY == state) )
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    return;
}

//display (show) window
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //save instance
    // ->needed to ensure window isn't ARC-dealloc'd when this function returns
    self.instance = self;
    
    //set delegate
    [self.window setDelegate:self];

    return;
}

//button handler for action (install/uninstall)
-(IBAction)handleActionClick:(id)sender
{
    //button title
    NSString* button = nil;
    
    //extact button title
    button = ((NSButton*)sender).title;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@", button]);
    #endif
    
    //handle non-'close' clicks
    if(YES != [button isEqualToString:ACTION_CLOSE])
    {
        //save action
        self.action = ((NSButton*)sender).tag;
        
        //disable 'x' button
        // ->don't want user killing app during install/upgrade
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
        
        //clear status msg
        [self.statusMsg setStringValue:@""];
        
        //force redraw of status msg
        // ->sometime doesn't refresh (e.g. slow VM)
        [self.statusMsg setNeedsDisplay:YES];
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@'ing BlockBlock", button]);
        #endif
        
        //invoke logic to install/uninstall
        // ->do in background so UI doesn't block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //set
            self.buttonTitle = ((NSButton*)sender).title;
            
            //install/uninstall
            [self lifeCycleEvent];
        });
    }
    
    //handle 'close'
    // ->note: should always exit
    else
    {
        //close
        [self.window close];
    }

//bail
bail:
    
    return;
}

//button handler that's automatically invoked when user clicks '?' button (on an error)
// ->load objective-see's documentation for BlockBlock error(s)
-(IBAction)handleInfoClick:(id)sender
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

//perform install | uninstall via Control obj
// ->invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent
{
    //status var
    BOOL status = NO;
    
    //control object
    Control* controlObj;
    
    //alloc control object
    controlObj = [[Control alloc] init];
    
    //begin event
    // ->updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //complete
        [self beginEvent];
    });
    
    //perform action (install | uninstall)
    // ->perform background actions
    if(YES == [controlObj execControlInstance:self.buttonTitle])
    {
        //set flag
        status = YES;
    }
    
    //error occurred
    else
    {
        //err msg
        logMsg(LOG_ERR, @"failed to perform life cycle event");
        
        //set flag
        status = NO;
    }
    
    //complet event
    // ->updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status];
    });
    
    return;
}

//begin event
// ->basically just update UI
-(void)beginEvent
{
    //status msg frame
    CGRect statusMsgFrame = {0};
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // ->shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    [self.statusMsg setAlignment:NSLeftTextAlignment];
    
    //update status msg UI
    [self.statusMsg setStringValue:[NSString stringWithFormat:@"%@ing...", [self.buttonTitle lowercaseString]]];
    
    //disable install button
    self.installButton.enabled = NO;
    
    //disable uninstall button
    self.uninstallButton.enabled = NO;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    //nap, briefly
    // ->allows update to status to be displayed before auth popup
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO);
    
    return;
}

//complete event
// ->update UI after background event has finished
-(void)completeEvent:(BOOL)success
{
    //status msg frame
    CGRect statusMsgFrame = {0};
    
    //result msg
    NSString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //success
    if(YES == success)
    {
        //set result msg
        resultMsg = [NSString stringWithFormat:@"BlockBlock %@ed", self.buttonTitle];
        
        //set font to black
        resultMsgColor = [NSColor blackColor];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [[NSString stringWithFormat:@"error: %@ failed", self.buttonTitle] lowercaseString];
        
        //set font to red
        resultMsgColor = [NSColor redColor];
        
        //show 'get more info' button
        // ->don't have to worry about (re)hiding since the only option is to close the app
        [self.moreInfoButton setHidden:NO];
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //align text center
    [self.statusMsg setAlignment:NSCenterTextAlignment];
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //shift back since activity indicator is gone
    statusMsgFrame.origin.x -= FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //set font to bold
    [self.statusMsg setFont:[NSFont fontWithName:@"Menlo-Bold" size:13]];
    
    //set msg color
    [self.statusMsg setTextColor:resultMsgColor];
    
    //set status msg
    [self.statusMsg setStringValue:resultMsg];
    
    //install logic
    if(BUTTON_INSTALL == self.action)
    {
        //set button title to 'close'
        self.installButton.title = ACTION_CLOSE;
        
        //enable
        self.installButton.enabled = YES;
        
        //make it active
        [self.window makeFirstResponder:self.installButton];
        
    }
    //uninstall logic
    else
    {
        //set button title to 'close'
        self.uninstallButton.title = ACTION_CLOSE;
        
        //enable
        self.uninstallButton.enabled = YES;
        
        //make it active
        [self.window makeFirstResponder:self.uninstallButton];
    }
    
    //ok to re-enable 'x' button
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"configure window: windowWillClose()");
    #endif
    
    //exit
    [NSApp terminate:self];
    
    return;
}


@end
