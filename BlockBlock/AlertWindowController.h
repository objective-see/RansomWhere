//
//  AlertWindowController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ParentsWindowController.h"

@class WatchEvent;
@class AlertView;

@interface AlertWindowController : NSWindowController <NSWindowDelegate>
{

}

@property (nonatomic, strong) NSWindowController *windowController;


//top/main view
@property (weak) IBOutlet AlertView *mainView;

//top
// ->alert msg
@property (weak) IBOutlet NSTextField* alertMsg;

//top
// ->icon/image for signing info
@property (weak) IBOutlet NSImageView *signedIcon;

//top
// ->name of process/label
@property (weak) IBOutlet NSTextField *processLabel;

//top
// ->process icon
@property (weak) IBOutlet NSImageView *processIcon;

//top
// ->show parents button
@property (weak) IBOutlet NSButton *parentsButton;

//top
// ->show parents button action/handler
-(IBAction)ancestryButtonHandler:(id)sender;

//bottom view
@property (weak) IBOutlet NSView *bottomView;

//bottom
// ->process name
@property (weak) IBOutlet NSTextField *processName;

//bottom
// ->process path
@property (weak) IBOutlet NSTextField *processPath;

//bottom
// ->process signing info
@property (weak) IBOutlet NSTextField *processSigning;

//bottom
// ->process id
@property (weak) IBOutlet NSTextField *processID;

//bottom
// ->name of launch item
@property (weak) IBOutlet NSTextField *itemName;

//bottom
// ->path to launch item's file
@property (weak) IBOutlet NSTextField *itemFile;

//bottom
// ->label for path to launch item binary
@property (weak) IBOutlet NSTextField *itemBinaryLabel;

//bottom
// ->path to launch item's binary
@property (weak) IBOutlet NSTextField *itemBinary;

//bottom
// ->remember button
@property (weak) IBOutlet NSButton *rememberButton;

//bottom
// ->block button
@property (weak) IBOutlet NSButton *blockButton;

//bottom
// ->allow button
@property (weak) IBOutlet NSButton *allowButton;

//parent ID
@property (nonatomic, retain)NSString* parentID;

//uuid of watch event
@property (nonatomic, retain)NSString* watchEventUUID;

//process hierarchy
@property (nonatomic, retain)NSArray* processHierarchy;

//plugin type
@property (nonatomic, retain)NSNumber* pluginType;

//parents window controller
@property (weak) IBOutlet ParentsWindowController *ancestryViewController;

//ancestry outline view
@property (weak) IBOutlet NSOutlineView *ancestryOutline;

//ancestry view
@property (weak) IBOutlet NSView *ancestorView;

//ancestory popover
@property (weak) IBOutlet NSPopover *popover;

//instance of single text cell (row)
@property (weak) IBOutlet NSTextFieldCell *ancestorTextCell;


/* METHODS */

//configure the alert with the info from the daemon
-(void)configure:(NSDictionary*)alertInfo;

//when user clicks 'block/allow'
// ->send msg to daemon, and close window
-(IBAction)doAction:(id)sender;

//logic to close/remove popup from view
-(void)deInitPopup;

@end
