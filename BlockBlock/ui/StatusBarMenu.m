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
#import "StatusBarPopoverController.h"

@implementation StatusBarMenu

@synthesize isEnabled;
@synthesize preYosemite;
@synthesize infoWindowController;

//init method
// ->set some intial flags, etc
-(id)init
{
    //os version
    NSDictionary* osVersionInfo = nil;
    
    //load from nib
    self = [super init];
    if(self != nil)
    {
        //set flag
        self.isEnabled = YES;
        
        //get OS version info
        osVersionInfo = getOSVersion();
        
        //anything less than 0S X 10.10
        // ->pre-Yosemite
        if([osVersionInfo[@"minorVersion"] intValue] < 10)
        {
            //set flag
            self.preYosemite = YES;
        }
    }
    
    return self;
}

//setup status item
// ->init button, show popover, etc
-(void)setupStatusItem
{
    //status bar image
    NSImage *image = nil;
    
    //init status item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    //init image
    image = [NSImage imageNamed:@"StatusBarIcon"];
    
    //tell OS to handle image
    // ->dark mode, etc
    [image setTemplate:YES];
    
    //set image
    self.statusItem.image = image;
    
    //logic for first run
    // ->show popover - but only YOSEMITE+
    if( (YES != self.preYosemite) &&
        (YES == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController.showPopup) )
    {
        //alloc popover
        self.popover = [[NSPopover alloc] init];
        
        //don't want highlight for popover
        self.statusItem.highlightMode = NO;
    
        //set action
        // ->can close popover with click
        self.statusItem.action = @selector(action:);
        
        //set target
        self.statusItem.target = self;
        
        //set view controller
        self.popover.contentViewController = [[StatusBarPopoverController alloc] initWithNibName:@"StatusBarPopover" bundle:nil];
        
        //set behavior
        // ->auto-close if user clicks button in status bar
        self.popover.behavior = NSPopoverBehaviorTransient;// NSPopoverBehaviorApplicationDefined;//NSPopoverBehaviorTransient;
        
        //set delegate
        self.popover.delegate = self;
        
        //show popover
        // ->have to wait cuz?
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //show
            [self.popover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
        });
        
        //automatically hide popup if user has not
        // ->after 5 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //hide
            if(YES == self.popover.shown)
            {
                //close
                [self.popover performClose:nil];
            }
         });
        
        //update pref
        // ->unset 'show popup' as only need to show popover first time
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController setPref:PREF_SHOW_POPOVER value:NO];
        
    }
    //otherwise,
    // ->just init drop-down menu
    else
    {
        //init menu
        [self updateStatusItemMenu];
    }
    
    return;
}

//automatically invoked
// ->only need this 1x, to close popover
-(void)action:(id)sender
{
    //no logic needed if popover is (already) closed
    if(YES != self.popover.shown)
    {
        //bail
        goto bail;
    }
    
    //close popover
    [self.popover performClose:nil];
    
//bail
bail:
    
    //remove action handler
    self.statusItem.action = nil;
    
    return;
}

//create/update status item menu
-(void)updateStatusItemMenu
{
    //menu
    NSMenu *menu = nil;

    //status
    NSString* toggle = nil;
    
    //status message
    NSString* statusMsg = nil;
    
    //alloc/init window
    menu = [[NSMenu alloc] init];
    
    //set status/status msg
    // ->enabled
    if(YES == self.isEnabled)
    {
        //toggle
        toggle = @"Disable";
        
        //status msg
        statusMsg = @"BLOCKBLOCK: enabled";
    }
    //set status/status msg
    // ->disabled
    else
    {
        //status
        toggle = @"Enable";
        
        //status msg
        statusMsg = @"BLOCKBLOCK: disabled";
    }
    
    //add status msg
    [menu addItemWithTitle:statusMsg action:NULL keyEquivalent:@""];
    
    //add top separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    //create/add menu item
    // ->toggle ('enable'/'disable')
    [menu addItem:[self initializeMenuItem:toggle action:@selector(toggle:)]];
    
    //create/add menu item
    // ->'uninstall'
    [menu addItem:[self initializeMenuItem:@"Uninstall" action:@selector(uninstall:)]];
    
    //create/add menu item
    // ->'preferences'
    [menu addItem:[self initializeMenuItem:@"Preferences" action:@selector(preferences:)]];
    
    //add bottom separator
    [menu addItem:[NSMenuItem separatorItem]];
    
    //create/add menu item
    // ->'about'
    [menu addItem:[self initializeMenuItem:@"About BlockBlock" action:@selector(about:)]];
    
    //tie menu to status item
    self.statusItem.menu = menu;
    
    return;
}

//init a menu item
-(NSMenuItem*)initializeMenuItem:(NSString*)title action:(SEL)action
{
    //menu item
    NSMenuItem* menuItem =  nil;
    
    //alloc menu item
    // ->toggle ('enable'/'disable')
    menuItem = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    
    //enabled
    menuItem.enabled = YES;
    
    //self
    menuItem.target = self;
    
    return menuItem;
}

//remove status item
-(void)removeStatusItem
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"removing status menu");
    #endif
    
    //remove
    [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
    
    return;
}

#pragma mark - Popover actions

//automatically called
// ->as popover is closing, init drop-down menu
-(void)popoverWillClose:(NSNotification *)notification
{
    //init menu
    [self updateStatusItemMenu];
    
    //want highlight for menu
    [self.statusItem setHighlightMode:YES];
    
    return;
}

#pragma mark - Menu actions

//handler for 'enable'/'disable' menu item
// ->tell IPC that agent is disabled or (re)enabled
-(void)toggle:(id)sender
{
    //when currently enabled
    // ->disable
    if(YES == self.isEnabled)
    {
        //dbg msg
        // ->and log to file (if logging is enabled)
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"user clicked: 'disable'");
        
        //set button to appear disabled
        // ->but only YOSEMITE+
        if(YES != preYosemite)
        {
            //set
            self.statusItem.button.appearsDisabled = YES;
        }
        
        //tell IPC object ui is disabled
        // ->allows it to ignore alerts from daemon (core)
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms setAgentStatus:UI_STATUS_DISABLED];
        
        //unset flag
        self.isEnabled = NO;
    }
    //otherwise, when currently disabled
    // ->enable
    else
    {
        //dbg msg
        // ->and log to file (if logging is enabled)
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"user clicked: 'enable'");
    
        //set button to enabled
        // ->but only YOSEMITE+
        if(YES != preYosemite)
        {
            //set
            self.statusItem.button.appearsDisabled = NO;
        }
        
        //tell IPC object ui is enabled
        // ->allows it to listen/show alerts from daemon (core)
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms setAgentStatus:UI_STATUS_ENABLED];
        
        //set flag
        self.isEnabled = YES;
    }
    
    //always update menu
    // ->ensures status msg/toggle option is updated
    [self updateStatusItemMenu];
    
    return;
}

//handler for 'uninstall' menu item
// ->spawn UI instance of self to kick off uninstaller logic
-(void)uninstall:(id)sender
{
    //dbg mgs
    // ->and log to file (if logging is enabled)
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"user clicked: 'uninstall'");
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"exec'ing UI instance of uninstaller");
    #endif
    
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
-(void)preferences:(id)sender
{
    //controller for preferences window
    PrefsWindowController* prefsWindowController = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"displaying preferences window");
    #endif
    
    //grab controller
    prefsWindowController = ((AppDelegate*)[[NSApplication sharedApplication] delegate]).prefsWindowController;
    
    //show pref window
    [prefsWindowController showWindow:sender];
    
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

@end
