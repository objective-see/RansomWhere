//
//  file: AboutWindowController.m
//  project: RansomWhere? (login item)
//  description: 'About' window controller
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"
#import "AboutWindowController.h"

@implementation AboutWindowController

@synthesize patrons;
@synthesize versionLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// set to window to white, set app version, patrons, etc
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode()){
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set version sting
    self.versionLabel.stringValue =  [NSString stringWithFormat:@"Version: %@", getAppVersion()];

    //load patrons
    // <3 you all :)
    self.patrons.string = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"patrons" ofType:@"txt"] encoding:NSUTF8StringEncoding error:NULL];
    if(nil == self.patrons.string) {
        //default
        self.patrons.string = @"error: failed to load patrons :/";
    }

    return;
}

//automatically invoked when window is closing
// ->make window unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [NSApplication.sharedApplication stopModal];
    
    return;
}

//automatically invoked when user clicks any of the buttons
// ->perform actions, such as loading patreon or products URL
-(IBAction)buttonHandler:(id)sender {
    
    //support us button
    if(((NSButton*)sender).tag == BUTTON_SUPPORT_US) {
        
        //open URL via browser
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:PATREON_URL]];
    }
    
    //more info button
    else if(((NSButton*)sender).tag == BUTTON_MORE_INFO) {
        
        //open URL via browser
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:PRODUCT_URL]];
    }
}
@end
