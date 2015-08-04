//
//  AlertView.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/27/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "AlertView.h"


@implementation AlertView

//shadow
static NSShadow *borderShadow = nil;


//automatically shown
// ->drawn shadow
-(void)drawRect:(NSRect)dirtyRect
{
    //shadow's bounds
    NSRect bounds  = {};
    
    //bezier path
    NSBezierPath *borderPath = nil;
    
    //super
    [super drawRect:dirtyRect];
    
    //save
    [NSGraphicsContext saveGraphicsState];
    
    //init shadow
    if(borderShadow == nil)
    {
        //alloc
        borderShadow = [[NSShadow alloc] init];
        
        //set color
        borderShadow.shadowColor = [NSColor colorWithDeviceWhite: 0 alpha: 0.5];
        
        //set offset
        borderShadow.shadowOffset = NSMakeSize(1, -1);
        
        //set blur radius
        borderShadow.shadowBlurRadius = 5.0;
    }
    
    //init/set bounds
    bounds = [self bounds];
    
    //adjust
    bounds.size.width -= 80;
    bounds.size.height -= 80;
    bounds.origin.x += 40;
    bounds.origin.y += 40;
    
    //init border path
    borderPath = [NSBezierPath bezierPathWithRoundedRect: bounds xRadius: 10 yRadius: 10];
    
    //set shadow
    [borderShadow set];
    
    //set color for current drawing context
    //[[NSColor lightGrayColor] set];
    
    [[NSColor colorWithCalibratedRed:(230/255.0f) green:(230/255.0f) blue:(230/255.0f) alpha:1.0] set];
    
    
    //fill path
    [borderPath fill];
    
    //restore
    [NSGraphicsContext restoreGraphicsState];
     
    return;
}
 

@end
