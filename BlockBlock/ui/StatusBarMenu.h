//
//  StatusBarMenu.h
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import "Control.h"
#import "InterProcComms.h"

#import "StatusBarCustomView.h"
#import "StatusBarPopoverController.h"

#import <Cocoa/Cocoa.h>


@interface StatusBarMenu : NSWindowController <NSMenuDelegate, NSPopoverDelegate, StatusBarPopoverDelegate, StatusBarCustomViewDelegate>
{
    //IPC object
    //InterProcComms* interProcComms;
    
    //Control object
    Control* controlObj;

}

- (void)didClickButton;

//popover stuffz
@property StatusBarPopoverController *viewController;     /** popover content view controller */
@property StatusBarCustomView *menulet;                      /** menu bar icon view */
@property (getter = isActive) BOOL active;          /** menu bar active */
@property (getter= isDisabled) BOOL disabled;

//flag indicating popover should be opened
@property BOOL shouldOpen;

//flag indicating popover was closed
@property BOOL wasClosed;

//IPC obj
//@property (nonatomic, retain)InterProcComms* interProcComms;

//Control obj
@property (nonatomic, retain)Control* controlObj;


-(IBAction)toggle:(id)sender;
-(IBAction)uninstallHandler:(id)sender;
-(IBAction)about:(id)sender;


//(top) status bar item
@property (strong, nonatomic)NSStatusItem* statusBarItem;

//menu (in status bar)
@property (strong) IBOutlet NSMenu *statusMenu;

@property (weak) IBOutlet NSMenuItem *status;

//status
// ->second menu item
@property (weak) IBOutlet NSMenuItem *menuItemStatus;

/* METHODS */
//configure
// ->set initial state, etc
-(void)configure;

//automatically show the popover
// ->do this via mouse click (otherwise have issues...)
-(void)showPopover;

//hide the popover
// ->if its already hidden, nothing is done...
-(void)hidePopover;

//init the dropdown menu
-(void)initMenu;

@end
