//
//  StatusBar.h
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InterProcComms.h"
#import "Control.h"

@interface StatusBar : NSObject <NSMenuDelegate>
{
    //IPC object
    InterProcComms* interProcComms;
    
    //Control object
    Control* controlObj;
}



//(top) status bar item
@property (strong, nonatomic)NSStatusItem* statusBarItem;

//menu (in status bar)
@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;

//status msg
// ->first menu item
@property (weak) IBOutlet NSMenuItem *statusMsg;

//status
// ->second menu item
@property (weak) IBOutlet NSMenuItem *menuItemStatus;


/* METHODS */
-(void)initStatusBar;

-(IBAction)toggle:(id)sender;
-(IBAction)uninstallHandler:(id)sender;
-(IBAction)about:(id)sender;


@end
