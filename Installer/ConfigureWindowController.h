//
//  ConfigureWindowController.h
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 11/23/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//title for window
@property (nonatomic, retain)NSString* windowTitle;

//action
//@property NSUInteger action;

@property (weak) IBOutlet NSProgressIndicator *activityIndicator;
@property (weak) IBOutlet NSTextField *statusMsg;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *actionButton;
@property (weak) IBOutlet NSButton *moreInfoButton;



/* METHODS */

//cancel button handler
-(IBAction)cancel:(id)sender;

//install/uninstall button handler
-(IBAction)handleActionClick:(id)sender;

//(more) info button handler
-(IBAction)handleInfoClick:(id)sender;

//configure window/buttons
// ->also brings to front
-(void)configure:(NSString*)title action:(NSUInteger)requestedAction;

//display (show) window
-(void)display;


@end
