
#import "StatusBarCustomView.h"
#import "Logging.h"



@interface StatusBarCustomView ()

@end

@implementation StatusBarCustomView

-(instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];

    if (self)
    {
        ;
    }
    return self;
}


- (void)drawRect:(NSRect)rect
{
    NSImage *menuletIcon;
    [[NSColor clearColor] set];
    /*
    if ([self.delegate isActive]) {
        menuletIcon = [NSImage imageNamed:[self.delegate activeImageName]];
    } else {
        menuletIcon = [NSImage imageNamed:[self.delegate inactiveImageName]];
    }
     */
    
    
    if ([self.delegate isDisabled])
    {
        menuletIcon = [NSImage imageNamed:[self.delegate inactiveImageName]];
    }
    
    else
    {
        menuletIcon = [NSImage imageNamed:[self.delegate activeImageName]];
    }
     
    [menuletIcon drawInRect:NSInsetRect(rect, 2, 2) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    

}

- (void)mouseDown:(NSEvent *)theEvent
{
    //logMsg(LOG_DEBUG, @"MOUSE DOWN EVENT");
    
    //update
    [self setNeedsDisplay:YES];
    
    [self.delegate menuletClicked];

    //update
    [self setNeedsDisplay:YES];
}




@end
