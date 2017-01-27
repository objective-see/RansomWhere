//
//  PopoverViewController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/8/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "VirusTotal.h"
#import "PopoverViewController.h"

@implementation PopoverViewController

@synthesize type;
@synthesize itemPath;
@synthesize vtSpinner;
@synthesize vtQueryMsg;
@synthesize processInfo;
@synthesize processPath;
@synthesize startupItemInfo;

//automatically invoked
// ->configure popover and kick off VT queries
-(void)popoverWillShow:(NSNotification *)notification;
{
    //hide process label
    self.processInfo.hidden = YES;
    
    //hide startup item label
    self.startupItemInfo.hidden = YES;
    
    //start spinner
    [self.vtSpinner startAnimation:nil];
    
    //bg thread for VT
    [self performSelectorInBackground:@selector(queryVT) withObject:nil];
    
    return;
}

-(void)queryVT
{
    return;
}



@end
