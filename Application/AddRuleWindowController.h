//
//  file: AddRuleWindowController.h
//  project: RansomWhere?
//  description: 'add/edit rule' window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Cocoa;
@import OSLog;

@interface AddRuleWindowController : NSWindowController <NSTextFieldDelegate>

/* PROPERTIES */

//app/binary icon
@property (weak) IBOutlet NSImageView *icon;

//path to app/binary
@property (weak) IBOutlet NSTextField *path;

//'add' button
@property (weak) IBOutlet NSButton *addButton;

//block button
@property (weak) IBOutlet NSButton *blockButton;

//allow button
@property (weak) IBOutlet NSButton *allowButton;


//captured in window
@property(nonatomic, retain)NSString* rulePath;
@property(nonatomic, retain)NSNumber* ruleAction;


/* METHODS */

//'block'/'allow' button handler
// just needed so buttons will toggle
-(IBAction)radioButtonsHandler:(id)sender;

//'browse' button handler
// open a panel for user to select file
-(IBAction)browseButtonHandler:(id)sender;

//'cancel' button handler
// returns NSModalResponseCancel
-(IBAction)cancelButtonHandler:(id)sender;

//'add' button handler
// returns NSModalResponseOK
-(IBAction)addButtonHandler:(id)sender;

@end
