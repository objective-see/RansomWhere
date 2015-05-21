//
//  ParentsWindowController.h
//  BlockBlock
//
//  Created by Patrick Wardle on 5/11/15.
//  Copyright (c) 2015 Synack. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ParentsWindowController : NSViewController <NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    
}

/* PROPERTIES */

//process hierarchy
@property (nonatomic, retain)NSArray* processHierarchy;

/* METHODS */

@end
