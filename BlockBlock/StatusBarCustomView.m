
#import "Logging.h"
#import "Utilities.h"
#import "StatusBarCustomView.h"

#import <Quartz/Quartz.h>




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


-(void)drawRect:(NSRect)rect
{
    //icon
    NSImage *menuletIcon = nil;
    
    //clear color
    [[NSColor clearColor] set];
    
    //set image for disabled mode
    if([self.delegate isDisabled])
    {
        //check mode
        // ->normal
        if(YES != isMenuDark())
        {
            //set normal image
            menuletIcon = [NSImage imageNamed:@"statusOFF"];
        }
        //check mode
        // ->dark
        else
        {
            //set light image for dark image
            menuletIcon = [NSImage imageNamed:@"statusOFFWhite"];
        }

    }
    //set image for enabled mode
    else
    {
        //check mode
        // ->normal
        if(YES != isMenuDark())
        {
            //set normal image
            menuletIcon = [NSImage imageNamed:@"statusON"];
        }
        //check mode
        // ->dark
        else
        {
            //set light image for dark image
            menuletIcon = [NSImage imageNamed:@"statusONWhite"];
        }
    }
    
    //draw
    [menuletIcon drawInRect:NSInsetRect(rect, 2, 2) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    
    return;
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
