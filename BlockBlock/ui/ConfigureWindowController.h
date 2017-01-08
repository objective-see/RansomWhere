//
//  ConfigureWindowController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

//pointer to self
// ->ensure that memory isn't prematurely released
@property (strong, nonatomic)ConfigureWindowController* instance;

//title for button
@property (nonatomic, retain)NSString* buttonTitle;

//title for window
@property (nonatomic, retain)NSString* windowTitle;

//action
@property NSUInteger action;

@property (weak) IBOutlet NSProgressIndicator *activityIndicator;
@property (weak) IBOutlet NSTextField *statusMsg;
@property (weak) IBOutlet NSButton *uninstallButton;
@property (weak) IBOutlet NSButton *installButton;
@property (weak) IBOutlet NSButton *moreInfoButton;

-(IBAction)handleActionClick:(id)sender;
-(IBAction)handleInfoClick:(id)sender;

/* METHODS */

//display (show) window
-(void)display;

@end
