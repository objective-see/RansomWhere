//
//  AlertWindowController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ParentsWindowController.h"

@class WatchEvent;
@class AlertView;

@interface AlertWindowController : NSWindowController <NSWindowDelegate>
{

    //iVars
}

@property (nonatomic, strong) NSWindowController *windowController;

//menu (in status bar)

//top/main view
@property (weak) IBOutlet AlertView *mainView;

//pointer to self
// ->ensure that memory isn't prematurely released
@property (strong, nonatomic)AlertWindowController* instance;

//top
// ->alert msg
@property (weak) IBOutlet NSTextField* alertMsg;

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
@property (strong) IBOutlet ParentsWindowController *ancestryViewController;

//ancestry outline view
@property (weak) IBOutlet NSOutlineView *ancestryOutline;

//ancestry view
@property (strong) IBOutlet NSView *ancestorView;

//ancestory popover
@property (strong) IBOutlet NSPopover *popover;

//instance of single text cell (row)
@property (weak) IBOutlet NSTextFieldCell *ancestorTextCell;


/* METHODS */

//configure the alert with the info from the daemon
-(void)configure:(NSDictionary*)alertInfo;

//increase size of element
-(void)increaseElementHeight:(NSControl*)element height:(float)height;

//shift an element
-(void)shiftElementVertically:(NSControl*)element shift:(float)shift;

//find the max width available in the text field
// ->takes into account font, and word-wrapping breaks!
-(float)findMaxWidth:(NSTextField*)textField;

//when user clicks 'allow'
-(IBAction)allow:(id)sender;

//when user clicks 'deny'
-(IBAction)deny:(id)sender;

@end
