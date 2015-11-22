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
#import "ConfigureWindowController.h"
#import "Logging.h"
#import "Install.h"
#import "Utilities.h"

//TODO: detect unloading of launch agent? or deletion of app - make sure this doesn't make the system unbootable!!!!


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
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    return;
}

//configure window/buttons
// ->also brings to front
-(void)configure:(NSString*)title action:(NSUInteger)requestedAction
{
    //save window title
    self.windowTitle = title;
    
    //save action
    self.action = requestedAction;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"configuring install/uninstall window");
    
    //init button title
    // ->based on action
    switch (self.action)
    {
        //install
        case ACTION_INSTALL_FLAG:

            //set
            self.buttonTitle = ACTION_INSTALL;
            
            break;
            
        //uninstall
        case ACTION_UNINSTALL_FLAG:
            
            //set
            self.buttonTitle = ACTION_UNINSTALL;
            
            break;
            
        default:
            break;
    }
    
    //more detailed button title
    // ->in case of install, can either be '(re)Install' or 'Upgrade'
    NSString* detailedStatus = nil;
    
    //set window title
    [self window].title = self.windowTitle;
    
    //check if install window should be further customized
    // ->e.g. when BlockBlock is already installed
    if(ACTION_INSTALL_FLAG == self.action)
    {
        //check
        // ->returns action
        detailedStatus = [self shouldCustomizeInstallUI];
    
        //customize futher
        if(nil != detailedStatus)
        {
            //set msg about reinstalling
            if(YES == [detailedStatus isEqualToString:ACTION_REINSTALL])
            {
                //init status msg
                [self.statusMsg setStringValue:@"this version is already installed"];
            }
            
            //set msg about upgrading
            else if(YES == [detailedStatus isEqualToString:ACTION_UPGRADE])
            {
                //init status msg
                [self.statusMsg setStringValue:@"older version is installed"];
            }
        }
    }
    
    //set button title
    // ->non-detailed case (just 'install' or 'uninstall')
    if(nil == detailedStatus)
    {
        //set title
        self.actionButton.title = self.buttonTitle;
    }
    //set button title
    // ->detailed case ('reinstall' or 'upgrade')
    else
    {
        //set title
        self.actionButton.title = detailedStatus;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@/%@", self.actionButton.title, self.window.title]);
    
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
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//check if already installed
// ->then check version and return detailed action (reinstall or upgrade)
-(NSString*)shouldCustomizeInstallUI
{
    //action (reinstall or upgrade)
    NSString* detailedAction =  nil;
    
    //installed version
    NSString* installedVersion = nil;
    
    //current version (of this instance)
    NSString* currentVersion = nil;
    
    //install object
    Install* installObj = nil;
    
    //init
    installObj = [[Install alloc] init];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"seeing if should customize install UI");
    
    //get installed version
    // ->returns nil if nothing is currently installed
    installedVersion = getVersion(VERSION_INSTANCE_INSTALLED);
    if(nil != installedVersion)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"installed version: %@", installedVersion]);
        
        //get version of self
        currentVersion = getVersion(VERSION_INSTANCE_SELF);
        if(nil == currentVersion)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to get current version");
            
            //this should never happen
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current (self's) version: %@", currentVersion]);
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"compare: %d/%lu", [installedVersion isEqualToString:currentVersion], (unsigned long)[installObj installState]]);
        
        //check if versions are equal and that we are already fully installed
        // ->set action to reinstall
        if( (YES == [installedVersion isEqualToString:currentVersion]) &&
            (INSTALL_STATE_FULL == [installObj installState]) )
        {
            //installed already (and same version!)
            detailedAction = ACTION_REINSTALL;
        }
        
        //check if current verison is greater than installed version
        // ->set action to upgrade
        else if(YES == [currentVersion isGreaterThan:installedVersion])
        {
            //current version is newer!
            detailedAction = ACTION_UPGRADE;
        }
        
    }//got installed version
    
//bail
bail:
    
    return detailedAction;
}


//button handler for 'cancel'
// ->note: exit logic handled in 'windowWillClose' delegate callback method
-(IBAction)cancel:(id)sender
{
    //dbg msg
    logMsg(LOG_DEBUG, @"handling 'cancel' button click, exiting process");
    
    //close
    [self.window close];
    
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@", button]);
    
    //handle non-'close' clicks
    if(YES != [button isEqualToString:ACTION_CLOSE])
    {
        //disable 'x' button
        // ->don't want user killing app during install/upgrade
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
        
        //clear status msg
        [self.statusMsg setStringValue:@""];
        
        //force redraw of status msg
        // ->sometime doesn't refresh (e.g. slow VM)
        [self.statusMsg setNeedsDisplay:YES];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@'ing BlockBlock", button]);
        
        //invoke install logic
        if(YES != [self lifeCycleEvent:self.action])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to %@", self.buttonTitle]);
        }
        
        //ok to re-enable 'x' button
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    }
    
    //handle 'close'
    // ->note: should always exit
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"closing...");
        
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

//call into Control obj to perform install | uninstall
-(BOOL)lifeCycleEvent:(NSUInteger)event
{
    //return var
    BOOL bRet = NO;
    
    //control object
    Control* controlObj;
    
    //status msg frame
    CGRect statusMsgFrame = {0};

    //result msg
    NSString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"handling life cycle event");
    
    //alloc control object
    controlObj = [[Control alloc] init];
    
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
    
    //disable action button
    self.actionButton.enabled = NO;
    
    //disable cancel button
    self.cancelButton.enabled = NO;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    //nap, briefly
    // ->allows update to status to be displayed before auth popup
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO);

    //perform action (install | uninstall)
    // ->perform background actions
    if(YES != [controlObj execControlInstance:self.buttonTitle])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to perform life cycle event");
        
        //set result msg
        resultMsg = [[NSString stringWithFormat:@"error: %@ failed", self.buttonTitle] lowercaseString];
        
        //set font to red
        resultMsgColor = [NSColor redColor];
        
        //show 'get more info' button
        // -> don't have to worry about (re)hiding since the only option is to close the app
        [self.moreInfoButton setHidden:NO];
        
        //set return var/flag
        bRet = NO;
    }
    
    //no errors
    // ->action completed OK
    else
    {
        //set result msg
        resultMsg = [NSString stringWithFormat:@"BlockBlock %@ed", self.buttonTitle];
        
        //set font to black
        resultMsgColor = [NSColor blackColor];
        
        //set return var/flag
        bRet = YES;
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
    
    //set button title to 'close'
    self.actionButton.title = ACTION_CLOSE;
    
    //enable
    self.actionButton.enabled = YES;
    
    //make it active
    [self.window makeFirstResponder:self.actionButton];
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return bRet;    
}

//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //dbg msg
    logMsg(LOG_DEBUG, @"configure window: windowWillClose()");
    
    //exit
    [NSApp terminate:self];
    
    return;
}


@end
