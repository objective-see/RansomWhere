//
//  PopoverViewController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 1/8/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

@interface PopoverViewController : NSViewController <NSPopoverDelegate>
{
    
}

/* METHODS */


/* PROPERTIES */

//auto-run type
@property(nonatomic, retain) NSString* type;

//process path
@property(nonatomic, retain) NSString* processPath;

//item path
@property(nonatomic, retain) NSString* itemPath;

//progress indicator
@property (weak) IBOutlet NSProgressIndicator *vtSpinner;

//query msg
@property (weak) IBOutlet NSTextField *vtQueryMsg;

//process vt info
@property (weak) IBOutlet NSTextField *processInfo;

//start up item info
@property (weak) IBOutlet NSTextField *startupItemInfo;


@end
