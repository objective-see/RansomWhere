//
//  Utilities.m
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize moreInfoButton;

//automatically called when nib is loaded
// ->just center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//configure window/buttons
// ->also brings window to front
-(void)configure:(BOOL)isInstalled
{
    //set window title
    [self window].title = [NSString stringWithFormat:@"version %@", getAppVersion()];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"configuring install/uninstall window");
    #endif
    
    //init status msg
    [self.statusMsg setStringValue:@"generically thwart ransomware 😇"];
    
    //enable 'uninstall' button when app is installed already
    if(YES == isInstalled)
    {
        //enable
        self.uninstallButton.enabled = YES;
    }
    //otherwise disable
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //make 'install' have focus
    // ->more likely they'll be upgrading
    [self.window makeFirstResponder:self.installButton];

    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// ->center, make front, set bg to white, etc
-(void)display
{
    //indicate title bar is transparent (too)
    self.window.titlebarAppearsTransparent = YES;
    
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make white
    //[self.window setBackgroundColor: NSColor.whiteColor];

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //button title
    NSString* buttonTitle = nil;
    
    //extact button title
    buttonTitle = ((NSButton*)sender).title;
    
    //action
    NSUInteger action = 0;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@", buttonTitle]);
    #endif
    
    //Close/No?
    // ->just exit
    if( (YES == [buttonTitle isEqualToString:ACTION_CLOSE]) ||
        (YES == [buttonTitle isEqualToString:ACTION_NO]) )
    {
        //close
        [self.window close];
        
        //bail
        goto bail;
    }
    
    //Next >>?
    // ->show 'support' us view
    if(YES == [buttonTitle isEqualToString:ACTION_NEXT])
    {
        //frame
        NSRect frame = {0};
        
        //unset window title
        self.window.title = @"";
        
        //get main window's frame
        frame = self.window.contentView.frame;
        
        //set origin to 0/0
        frame.origin = CGPointZero;
        
        //increase y offset
        frame.origin.y += 5;
        
        //reduce height
        frame.size.height -= 5;
        
        //pre-req
        [self.supportView setWantsLayer:YES];
        
        //update overlay to take up entire window
        self.supportView.frame = frame;
        
        //set overlay's view color to white
        //self.supportView.layer.backgroundColor = [NSColor whiteColor].CGColor;
        
        //nap for UI purposes
        [NSThread sleepForTimeInterval:0.10f];
        
        //add to main window
        [self.window.contentView addSubview:self.supportView];
        
        //show
        self.supportView.hidden = NO;
        
        //make 'yes!' button active
        [self.window makeFirstResponder:self.supportButton];
        
        //bail
        goto bail;
    }
    
    //'yes' for support
    // ->load supprt in URL
    if(YES == [buttonTitle isEqualToString:ACTION_YES])
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
        //close
        [self.window close];
        
        //bail
        goto bail;
    }
    
    //install/uninstall logic handlers
    else
    {
       //hide 'get more info' button
        self.moreInfoButton.hidden = YES;
        
        //set action
        // ->install daemon
        if(YES == [buttonTitle isEqualToString:ACTION_INSTALL])
        {
            //set
            action = ACTION_INSTALL_FLAG;
        }
        //set action
        // ->uninstall daemon
        else
        {
            //set
            action = ACTION_UNINSTALL_FLAG;
        }
        
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
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@'ing RansomWhere?", buttonTitle]);
        #endif
        
        //invoke logic to install/uninstall
        // ->do in background so UI doesn't block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //install/uninstall
            [self lifeCycleEvent:action];
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"done %@'ing RansomWhere?", buttonTitle]);
            #endif
        });
    }
    
//bail
bail:

    
    return;
}

//button handler for '?' button (on an error)
// ->load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
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
-(void)lifeCycleEvent:(NSUInteger)event
{
    //status var
    BOOL status = NO;
    
    //configure object
    Configure* configureObj = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling life cycle event, %lu", (unsigned long)event]);
    #endif
    
    //alloc control object
    configureObj = [[Configure alloc] init];
    
    //begin event
    // ->updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //complete
        [self beginEvent:event];
    });
    
    //sleep
    // ->allow 'install' || 'uninstall' msg to show up
    sleep(1);
    
    //perform action (install | uninstall)
    // ->perform background actions
    if(YES == [configureObj configure:event])
    {
        //set flag
        status = YES;
    }
    
    //error occurred
    else
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to perform life cycle event");
        
        //set flag
        status = NO;
    }
    
    //complet event
    // ->updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// ->basically just update UI
-(void)beginEvent:(NSUInteger)event
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
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        [self.statusMsg setStringValue:@"Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        [self.statusMsg setStringValue:@"Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// ->update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSUInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {0};
    
    //action
    NSString* action = nil;
    
    //result msg
    NSString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //generally want centered text
    [self.statusMsg setAlignment:NSCenterTextAlignment];
    
    //set action msg for install
    if(ACTION_INSTALL_FLAG == event)
    {
        //set msg
        action = @"install";
        
        //set result msg
        resultMsg = @"RansomWhere? installed\r\n(automatic protection enabled)";

    }
    //set action msg for uninstall
    else
    {
        //set msg
        action = @"uninstall";
        
        //set result msg
        resultMsg = @"RansomWhere? uninstalled";
    }
    
    //success
    if(YES == success)
    {
        //(re)set font to black
        resultMsgColor = [NSColor blackColor];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSString stringWithFormat:@"error: %@ failed", action];
        
        //set font to red
        resultMsgColor = [NSColor redColor];
        
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    [self.activityIndicator setHidden:YES];
    
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
    
    //update button
    // ->after install change butter to 'Next'
    if(ACTION_INSTALL_FLAG == event)
    {
        //set button title to 'close'
        self.installButton.title = ACTION_NEXT;
        
        //enable
        self.installButton.enabled = YES;
        
        //make it active
        [self.window makeFirstResponder:self.installButton];
    }
    //update button
    // ->after uninstall change butter to 'close'
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
// ->just exit application
-(void)windowWillClose:(NSNotification *)notification
{
    //exit
    [NSApp terminate:self];
    
    return;
}


@end
