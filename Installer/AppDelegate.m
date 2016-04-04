//
//  AppDelegate.m
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Exception.h"
#import "Utilities.h"
#import "AppDelegate.h"

@implementation AppDelegate

@synthesize errorWindowController;
@synthesize configureWindowController;

//automatically invoked when app is loaded
// ->check OS version, then show configure (install/uninstall) popup
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //config object
    Configure* configureObj = nil;
    
    //first thing...
    // ->install exception handlers
    installExceptionHandlers();
    
    //alloc/init Config obj
    configureObj = [[Configure alloc] init];
    
    //check if OS is supported
    if(YES != isSupportedOS())
    {
        //show error popup
        [self displayErrorWindow: @{KEY_ERROR_MSG:@"ERROR: unsupported OS", KEY_ERROR_SUB_MSG: [NSString stringWithFormat:@"OS X %@ is not supported", [[NSProcessInfo processInfo] operatingSystemVersionString]], KEY_ERROR_SHOULD_EXIT:@YES}];
        
        //bail
        goto bail;
    }
    
    //already installed?
    // ->display uninstall window
    if(YES == [configureObj isInstalled])
    {
        //show window
        [self displayConfigureWindow:[NSString stringWithFormat:@"Uninstall v. %@", getVersion()] action:ACTION_UNINSTALL_FLAG];
    }
    //not installed
    // ->display install window
    else
    {
        //show window
        [self displayConfigureWindow:[NSString stringWithFormat:@"Install v. %@", getVersion()] action:ACTION_INSTALL_FLAG];
    }
    
//bail
bail:
    
    return;
}

//display configuration window w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(NSString*)windowTitle action:(NSUInteger)action
{
    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //display it
    // ->call this first to so that outlets are connected
    [self.configureWindowController display];
    
    //configure it
    [self.configureWindowController configure:windowTitle action:action];
    
    return;
}

//display error window
-(void)displayErrorWindow:(NSDictionary*)errorInfo
{
    //alloc error window
    errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];

    //main thread
    // ->just show UI alert, unless its fatal (then load URL)
    if(YES == [NSThread isMainThread])
    {
        //non-fatal errors
        // ->show error error popup
        if(YES != [errorInfo[KEY_ERROR_URL] isEqualToString:FATAL_ERROR_URL])
        {
            //display it
            // ->call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
        }
        //fatal error
        // ->launch browser to go to fatal error page, then exit
        else
        {
            //launch browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:errorInfo[KEY_ERROR_URL]]];
            
            //then exit
            [NSApp terminate:self];
        }
    }
    //background thread
    // ->have to show error window on main thread
    else
    {
        //show alert
        // ->in main UI thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //display it
            // ->call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
            
        });
    }
    
    return;
}

@end
