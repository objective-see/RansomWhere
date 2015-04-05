//
//  WOMController.h
//  PopoverMenulet
//
//  Created by Julián Romero on 10/26/11.
//  Copyright (c) 2011 Wuonm Web Services S.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WOMMenulet.h"
#import "WOMPopoverController.h"

@interface WOMController : NSObject <WOMPopoverDelegate, WOMMenuletDelegate>

@property WOMPopoverController *viewController;     /** popover content view controller */
@property WOMMenulet *menulet;                      /** menu bar icon view */
@property NSStatusItem *item;                       /** status item */
@property (getter = isActive) BOOL active;          /** menu bar active */

@end
