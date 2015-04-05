//
//  ErrorWindowController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 1/26/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ErrorWindowController : NSWindowController <NSWindowDelegate>
{
    
}

//pointer to self
// ->ensure that memory isn't prematurely released
@property (strong, nonatomic)ErrorWindowController* instance;

//error msg in window
@property (weak) IBOutlet NSTextField *errMsg;

//close button
@property (weak) IBOutlet NSButton *closeButton;

//flag indicating close button should exit app
@property BOOL shouldExit;

/* METHODS */

//configure the object/window
-(void)configure:(NSString*)errorMessage shouldExit:(BOOL)shouldExit;

//display (show) window
-(void)display;

@end
