//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "AppDelegate.h"
#import "PrefsWindowController.h"


@implementation PrefsWindowController

@synthesize okButton;
@synthesize passiveMode;
@synthesize enableLogging;
@synthesize loggingViaPassive;
@synthesize disableUpdateCheck;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //make 'ok' button selected
    [self.window makeFirstResponder:self.okButton];
    
    //reset flag
    self.loggingViaPassive = NO;
    
    //check if 'enable logging' button should be selected
    if(YES == self.enableLogging)
    {
        //set
        self.enableLoggingBtn.state = NSOnState;
    }
    
    //check if 'run in passive mode' button should be selected
    // ->and when so, select, then disable logging
    if(YES == self.passiveMode)
    {
        //set
        self.enablePassiveBtn.state = NSOnState;
        
        //enable logging
        self.enableLoggingBtn.state = NSOnState;
        
        //disable logging button
        self.enableLoggingBtn.enabled = NO;
    }
    //no passive mode
    // ->make sure logging button is enabled
    else
    {
        //enable
        self.enableLoggingBtn.enabled = YES;
    }
    
    //check if 'disable update checks' button should be selected
    if(YES == self.disableUpdateCheck)
    {
        //set
        self.disableUpdateCheckBtn.state = NSOnState;
    }
    
    return;
}

//register default prefs
// ->only used if user hasn't set any
-(void)registerDefaults
{
    //set defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{PREF_ENABLE_LOGGING:@NO, PREF_PASSIVE_MODE:@NO, PREF_DISABLE_UPDATE_CHECK:@NO}];
    
    return;
}

//load (persistence) preferences from file system
-(void)loadPreferences
{
    //user defaults
    NSUserDefaults* defaults = nil;
    
    //init
    defaults = [NSUserDefaults standardUserDefaults];
    
    //load prefs
    // ->won't be any until user sets some...
    if(nil != defaults)
    {
        //load 'enable logging'
        if(nil != [defaults objectForKey:PREF_ENABLE_LOGGING])
        {
            //save
            self.enableLogging = [defaults boolForKey:PREF_ENABLE_LOGGING];
        }
        
        //load 'run in passive mode'
        if(nil != [defaults objectForKey:PREF_PASSIVE_MODE])
        {
            //save
            self.passiveMode = [defaults boolForKey:PREF_PASSIVE_MODE];
        }
        
        //load 'disable update checks'
        if(nil != [defaults objectForKey:PREF_DISABLE_UPDATE_CHECK])
        {
            //save
            self.disableUpdateCheck = [defaults boolForKey:PREF_DISABLE_UPDATE_CHECK];
        }
    }
    
    return;
}

//'run in passive mode' button handler
// ->handle extra logic to turn on logging as well
-(IBAction)togglePassiveMode:(id)sender
{
    //TODO: remove
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@" passive mode: %d / logging: %d", ((NSButton*)sender).state, self.enableLoggingBtn.state]);
    
    //passive mode enabled
    // ->ensure logging is enabled as well
    if(NSOnState == ((NSButton*)sender).state)
    {
        //when logging isn't enabled
        // ->enable, then disable button
        if(NSOnState != self.enableLoggingBtn.state)
        {
            //TODO: remove
            logMsg(LOG_DEBUG, @"selecting logging, then disabling");
            
            //select logging
            self.enableLoggingBtn.state = NSOnState;
        
            //set flag
            // ->on
            self.loggingViaPassive = YES;
        }
        
        //always disable logging button
        self.enableLoggingBtn.enabled = NO;
    }
    //passive mode disabled
    // ->always enable logging button, optionally unselect as well
    else
    {
        //deselect logging when it was enabled because of passive mode enablement
        if(YES == self.loggingViaPassive)
        {
            //TODO: remove
            logMsg(LOG_DEBUG, @"unselecting logging");
            
            //unselect logging (as well)
            self.enableLoggingBtn.state = NSOffState;
            
            //reset flag
            self.loggingViaPassive = NO;
        }
        
        //TODO: remove
        logMsg(LOG_DEBUG, @"enabling logging button");

        //always enable logging button
        self.enableLoggingBtn.enabled = YES;
    }
    
    return;
}

//automatically invoked when window is closing
// ->save prefs and make window unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //if logging was toggled
    // ->handle both on/off logic
    if(self.enableLogging != self.enableLoggingBtn.state)
    {
        //now enabled?
        // ->init/begin
        if(NSOnState == self.enableLoggingBtn.state)
        {
            //init
            if(YES != initLogging())
            {
                //err msg
                logMsg(LOG_ERR, @"failed to init logging");
            }
        }
        //not enabled
        // ->close/de-init
        else
        {
            //close
            deinitLogging();
        }
    }
    
    //save prefs
    [self savePrefs];
    
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}

//save prefs
// ->persist them to disk
-(void)savePrefs
{
    //user defaults
    NSUserDefaults* defaults = nil;
    
    //init
    defaults = [NSUserDefaults standardUserDefaults];

    //save 'enable logging' flag
    self.enableLogging = self.enableLoggingBtn.state;
    
    //save 'run in passive mode' flag
    self.passiveMode = self.enablePassiveBtn.state;
    
    //save 'disable update checks' flag
    self.disableUpdateCheck = self.disableUpdateCheckBtn.state;
    
    //save 'enable logging'
    [defaults setBool:self.enableLogging forKey:PREF_ENABLE_LOGGING];
    
    //save 'run in passive mode'
    [defaults setBool:self.passiveMode forKey:PREF_PASSIVE_MODE];

    //save 'disable update checks'
    [defaults setBool:self.disableUpdateCheck forKey:PREF_DISABLE_UPDATE_CHECK];
    
    //flush/save
    [defaults synchronize];
    
    return;
}

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender
{
    //close
    [self.window close];
    
    return;
}

@end
