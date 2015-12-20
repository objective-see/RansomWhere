//
//  PrefsWindowController.h
//  DHS
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PrefsWindowController : NSWindowController <NSWindowDelegate>
{
    
}

//button for filtering out OS componets
@property (weak) IBOutlet NSButton* enableLoggingBtn;

//button for enabling passive mode
@property (weak) IBOutlet NSButton *enablePassiveBtn;

//button for disabling talking to VT
@property (weak) IBOutlet NSButton* disableUpdateCheckBtn;

//button for ok/close
@property (weak) IBOutlet NSButton *okButton;

//show popup
@property BOOL showPopup;

//logging flag
@property BOOL enableLogging;

//disable update checks flag
@property BOOL disableUpdateCheck;

//run in passive mode flag
@property BOOL passiveMode;

//flag indicating logging was enabled via passive mode
@property BOOL loggingViaPassive;

/* METHODS */

//register default prefs
// ->only used if user hasn't set any
-(void)registerDefaults;

//load (persistence) preferences from file system
-(void)loadPreferences;

//'run in passive mode' button handler
// ->handle extra logic to turn on logging as well
-(IBAction)togglePassiveMode:(id)sender;

//set (single) pref
-(void)setPref:(NSString*)key value:(BOOL)value;

//save prefs
// ->persist them to disk
-(void)savePrefs;

//'OK' button handler
// ->save prefs and close window
-(IBAction)closeWindow:(id)sender;

@end
