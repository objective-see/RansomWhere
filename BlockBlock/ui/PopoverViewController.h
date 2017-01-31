//
//  PopoverViewController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 1/8/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@class HyperlinkTextField;

@interface PopoverViewController : NSViewController <NSPopoverDelegate>
{
    
}

/* METHODS */


/* PROPERTIES */

//auto-run type
@property(nonatomic, retain) NSString* type;

//items
@property(nonatomic, retain) NSMutableArray* items;

//progress indicator
@property (weak) IBOutlet NSProgressIndicator *vtSpinner;

//query msg
@property (weak) IBOutlet NSTextField *vtQueryMsg;

//process vt info
@property (weak) IBOutlet HyperlinkTextField *firstItem;

//start up item info
@property (weak) IBOutlet HyperlinkTextField *secondItem;


@end
