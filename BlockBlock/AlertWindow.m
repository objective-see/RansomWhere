//
//  AlertWindow.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/27/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "AlertWindow.h"

@implementation AlertWindow


-(id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:flag];
    
    if(self)
    {
        [self setStyleMask:NSBorderlessWindowMask];
        self.opaque = NO;
        self.backgroundColor = [NSColor clearColor];
        self.movableByWindowBackground = YES;
    }
    
    return self;
}

@end
