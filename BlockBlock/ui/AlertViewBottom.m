//
//  AlertViewTop.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/28/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "AlertViewBottom.h"
#import <Quartz/Quartz.h>

#import "QuartzCore/QuartzCore.h"


@implementation AlertViewBottom

//shadow
static NSShadow *borderShadow = nil;

NSUInteger cornerRadius = 10;

-(void)drawRect:(NSRect)dirtyRect
{
    //super
    [super drawRect:dirtyRect];
    
    //save context
    [NSGraphicsContext saveGraphicsState];
    
    
    //path
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    //
    [path moveToPoint:NSMakePoint(NSMinX(self.bounds), NSMaxY(self.bounds))];
    
    //
    [path lineToPoint:NSMakePoint(NSMinX(self.bounds), NSMinY(self.bounds) + cornerRadius)];
    
    //draw corner
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(self.bounds), NSMinY(self.bounds)) toPoint: NSMakePoint(NSMinX(self.bounds) + cornerRadius, NSMinY(self.bounds)) radius:cornerRadius];
    
    
    
    [path lineToPoint:NSMakePoint(NSMaxX(self.bounds)-cornerRadius, NSMinY(self.bounds))];
    
    
    [path appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(self.bounds), NSMinY(self.bounds)) toPoint: NSMakePoint(NSMaxX(self.bounds), NSMinY(self.bounds) + cornerRadius) radius:cornerRadius];

    
    [path lineToPoint:NSMakePoint(NSMaxX(self.bounds), NSMaxY(self.bounds))];
    
    [path lineToPoint:NSMakePoint(NSMinX(self.bounds), NSMaxY(self.bounds))];
    
    [path lineToPoint:NSMakePoint(NSMinX(self.bounds), NSMinY(self.bounds))];
    
    

    //set color
    [[NSColor colorWithCalibratedRed:(243/255.0f) green:(243/255.0f) blue:(243/255.0f) alpha:1.0] set];
    

    [path fill];
    
    [NSGraphicsContext restoreGraphicsState];
}

@end
