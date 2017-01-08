//
//  CustomNSButton.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/4/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "CustomNSButton.h"

@implementation CustomNSButton

//ignore simulated keypresses
- (void)mouseDown:(NSEvent *)event
{
    //ignore simulated presses
    if(event.deviceID != 0)
    {
        [super mouseDown:event];
    }
    
}


@end
