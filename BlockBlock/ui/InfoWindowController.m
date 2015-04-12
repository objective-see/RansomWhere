//
//  PrefsWindowController.m
//  KnockKnock
//
//  Created by Patrick Wardle on 2/6/15.
//  Copyright (c) 2015 Objective-See, LLC. All rights reserved.
//


#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "InfoWindowController.h"


@implementation InfoWindowController


@synthesize infoLabel;
@synthesize actionButton;
@synthesize infoLabelString;
@synthesize actionButtonTitle;


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
    
    //set main label
    [self.infoLabel setStringValue:self.infoLabelString];
    
    //set button text
    self.actionButton.title = self.actionButtonTitle;
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//save the main label's & button title's text
-(void)configure:(NSString*)label buttonTitle:(NSString*)buttonTitle
{
    //save label's string
    self.infoLabelString = label;
    
    //save button's title
    self.actionButtonTitle = buttonTitle;
    
    return;
}

//invoked when user clicks button
// ->trigger action such as opening product website, updating, etc
-(IBAction)buttonHandler:(id)sender
{
    //for now, all actions just open blockblock's webpage
    
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    
    //then close window
    [[self window] close];
        
    return;
}
@end
