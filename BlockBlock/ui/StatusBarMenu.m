//
//  StatusBarMenu.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "StatusBarMenu.h"

#import "ConfigureWindowController.h"



@implementation StatusBarMenu

@synthesize wasClosed;
@synthesize controlObj;
@synthesize shouldOpen;
@synthesize viewController;
@synthesize infoWindowController;


//configure
// ->set initial state, etc
-(void)configure
{
    //thickness
    CGFloat thickness = 0;
    
    //init contol object
    controlObj = [[Control alloc] init];
    
    //get thickness
    thickness = [[NSStatusBar systemStatusBar] thickness];
    
    //init status bar item
    self.statusBarItem = [[NSStatusBar systemStatusBar] statusItemWithLength:thickness];
    
    //custom view
    self.menulet = [[StatusBarCustomView alloc] initWithFrame:(NSRect){.size={thickness, thickness}}]; /* square item */
    
    //delegate is this controller
    self.menulet.delegate = self;
    
    //set custom view as view for status bar item
    [self.statusBarItem setView:self.menulet];
    
    //disable highlighting
    [self.statusBarItem setHighlightMode:NO];
    
    return;
}

//automatically show the popover
// ->do this via mouse click (otherwise have issues...)
-(void)showPopover
{
    //(currrent) position event
    CGEventRef positionEvent = NULL;
    
    //mouse reset event
    CGEventRef mouseResetEvent = NULL;
    
    //current mouse position
    CGPoint originalPoint = {0};
    
    //frame relative to window
    NSRect frameRelativeToWindow = {0};
    
    //frame relative to screen
    NSRect frameRelativeToScreen = {0};
    
    //point to click
    CGPoint clickTarget = {0};
    
    //click down event
    CGEventRef clickDownEvent = NULL;
    
    //click up event
    CGEventRef clickUpEvent = NULL;
    
    //set this here
    // ->need since we send a click which checks whether to show popover or menu
    self.shouldOpen = YES;
    
    //create event
    positionEvent = CGEventCreate(NULL);
    
    //get current mouse point
    originalPoint = CGEventGetLocation(positionEvent);
    
    //get frame relative to window
    frameRelativeToWindow = [self.statusBarItem.view convertRect:self.statusBarItem.view.bounds toView:nil];
    
    //get frame relative to screen
    // ->absolute coordinates
    frameRelativeToScreen = [self.statusBarItem.view.window convertRectToScreen:frameRelativeToWindow];

    //init point target
    // ->x coodinate
    clickTarget.x = frameRelativeToScreen.origin.x + (0.5 * self.statusBarItem.view.bounds.size.width);
    
    //init point target
    // ->y coodinate
    clickTarget.y = [[NSStatusBar systemStatusBar] thickness] / 2;
    
    //dgb msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"clicking status bar at point: %@", NSStringFromPoint(clickTarget)]);
    
    //init click down event
    clickDownEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, clickTarget, kCGMouseButtonLeft);
    
    //init click up event
    clickUpEvent = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, clickTarget, kCGMouseButtonLeft);
    
    //click down
    CGEventPost(kCGHIDEventTap, clickDownEvent);
    
    //click up
    CGEventPost(kCGHIDEventTap, clickUpEvent);

    //init mouse reset event
    // ->uses original point
    mouseResetEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, originalPoint, kCGMouseButtonLeft);
    
    //move mouse back to original location
    CGEventPost(kCGHIDEventTap, mouseResetEvent);
    
    //release position event
    CFRelease(positionEvent);
    
    //release mouse reset event
    CFRelease(mouseResetEvent);
    
    //release click down event
    CFRelease(clickDownEvent);
    
    //release click up event
    CFRelease(clickUpEvent);
    
    return;
}

//hide the popover
// ->if its already hidden, nothing is done...
-(void)hidePopover
{
   //check if it needs to be closes
   if(NO != self.active)
   {
       //dbg msg
       logMsg(LOG_DEBUG, @"sending event to close popover");
       
       //send blank mouse down event
       [self closePopover];
   }
   //no need to close
   else
   {
       //dbg msg
       logMsg(LOG_DEBUG, @"popover already closed");
   }

    return;
}



//required callback
// ->just return the status menu
-(NSMenu*)menu
{
    return self.statusMenu;
}

//invoked by the status bar menu to disable BlockBlock
// ->all we do is disable the alert notification since the core is running as r00t (so can't be unloaded via user menu)
//   also, don't want to stop agent, since then the user can't (re)enable it via the menu
-(void)disable
{
    //dbg msg
    // ->and log to file (if logging is enabled)
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"user clicked: 'disable'");
    
    //tell IPC object ui is disabled
    // ->allows it to ignore alerts from daemon (core)
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms setAgentStatus:UI_STATUS_DISABLED];
    
    //set status
    // ->top (disabled) menu item
    self.status.title = @"BLOCKBLOCK: disabled";
    
    //toggle menu item's title
    self.menuItemStatus.title = @"Enable";
    
    //set flag
    self.disabled = YES;
    
    return;
}


//invoked by the status bar menu to re-enable BlockBlock
// ->basically just send msg via IPC to let it know we are again interested in alerts
-(void)enable
{
    //dbg msg
    // ->and log to file (if logging is enabled)
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"user clicked: 'enable'");
    
    //tell IPC object ui is enabled
    // ->allows it to listen/show alerts from daemon (core)
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms setAgentStatus:UI_STATUS_ENABLED];

    //set status
    // ->top (disabled) menu item
    self.status.title = @"BLOCKBLOCK: enabled";
    
    //toggle menu item's title
    self.menuItemStatus.title = @"Disable";
    
    //set flag
    self.disabled = NO;
    
    return;
}



#pragma mark - menu actions

//automatically invoked when user clicks 'enable' || 'disable' in the status bar menu
-(void)toggle:(id)sender
{
    //user clicked 'Disable'
    if(YES == [ ((NSMenuItem*)sender).title isEqualToString:@"Disable"])
    {
        //disable
        [self disable];
    }
    //user clicked 'Enable'
    else if(YES == [ ((NSMenuItem*)sender).title isEqualToString:@"Enable"])
    {
        //enable
        [self enable];
    }
    
    return;
}

//handler for 'uninstall' menu item
// ->spawn UI instance of self to kick off uninstaller logic
-(void)uninstallHandler:(id)sender
{
    //dbg mgs
    // ->and log to file (if logging is enabled)
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"user clicked: 'uninstall'");
    
    //dbg msg
    logMsg(LOG_DEBUG, @"exec'ing UI instance of uninstaller");
    
    //kick of uninstaller
    // ->self, with 'Uninstall_UI' as argument
    if(STATUS_SUCCESS != execTask([NSBundle mainBundle].executablePath, @[ACTION_UNINSTALL_UI], NO))
    {
        //err msg
        logMsg(LOG_ERR, @"failed to exec uninstaller (UI instance)");
    }
    
    return;
}
//handler for 'preferences' menu item
// ->show window that has selectabel preferences
-(IBAction)preferencesHandler:(id)sender
{
    //controller for preferences window
    PrefsWindowController* prefsWindowController = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"displaying preferences window");
    
    //grab controller
    prefsWindowController = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController;
    
    //show pref window
    //TODO: is nil ok?
    [prefsWindowController showWindow:nil];
    
    //invoke function in background that will make window modal
    // ->waits until window is non-nil
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(prefsWindowController);
        
    });
    
    return;
}

//menu handler that's automatically invoked when user clicks 'about'
// ->load objective-see's documentation for BlockBlock
-(void)about:(id)sender
{
    //alloc/init about window
    infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
    
    //configure label and button
    [self.infoWindowController configure:[NSString stringWithFormat:@"version: %@", getAppVersion()] buttonTitle:@"more info"];
    
    //center window
    [[self.infoWindowController window] center];
    
    //show it
    [self.infoWindowController showWindow:self];
    
    return;
}

#pragma mark - Popover

-(void)closePopover
{
    //dbg msg
    logMsg(LOG_DEBUG, @"closing popover method()");
    
    //TODO: can't just use wasClosed?
    //set flag
    self.active = NO;
    
    //invoke NSPopover performClose method
    [self.viewController.popover performClose:self];
    
    //re-draw view
    [self.menulet setNeedsDisplay:YES];
    
    //kill it!
    //[self.menulet removeFromSuperview];
    
    //set flag
    self.wasClosed = YES;
    
    //init menu
    [self initMenu];
    
}

//init the dropdown menu
-(void)initMenu
{
    //dbg msg
    logMsg(LOG_DEBUG, @"init'ing dropdown menu");
    
    //highlight when clicked
    [self.statusBarItem setHighlightMode:YES];
    
    //set menu
    [self.statusBarItem setMenu:self.statusMenu];
    
    //init status
    self.status.title = @"BLOCKBLOCK: enabled";
    
    //remove popover controller/view
    self.viewController = nil;
    
}

//open
-(void)openPopover
{
    [self _setup];
    
    //invoke NSPopover showRelativeToRect method
    [self.viewController.popover showRelativeToRect:self.menulet.bounds ofView:self.statusBarItem.view preferredEdge:NSMinYEdge];
    
    return;
}

#pragma mark - StatusBarCustomViewDelegate
-(void)menuletClicked
{
    //toggle active flag
    self.active = !self.active;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"menu clicked!");
    
    //show menu
    // ->popover wasn't shown or was closed
    if( (YES != self.shouldOpen) ||
        (YES == self.wasClosed) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"show drop down menu: %@", self.menu]);
        
        //show menu
        [self.statusBarItem popUpStatusItemMenu:self.statusMenu];
    }
    
    //open or close the popover
    //TODO: use self.wasClosed?!
    else
    {
        if (self.isActive)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"opening popover!");
            
            [self openPopover];
        }
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"closing popover!");
            
            [self closePopover];
            
        }
    }
}


#pragma mark - StatusBarPopoverDelegate
- (void)didClickButton
{
    [self closePopover];
}


#pragma mark - Private

- (void)_setup
{
    if (!self.viewController)
    {
        logMsg(LOG_DEBUG, @"allocing 'StatusBarPopoverController'");
        
        self.viewController = [[StatusBarPopoverController alloc] init];
        self.viewController.delegate = self;
    }
    else
    {
        logMsg(LOG_DEBUG, @"NOT allocing 'StatusBarPopoverController'");
        
    }
}

@end
