

#import "StatusBarPopoverController.h"
#import "StatusBarCustomView.h"

@interface StatusBarPopoverController ()
@end

@implementation StatusBarPopoverController

-(id)init
{
    //load from nib
    self = [super initWithNibName:@"StatusBarPopover" bundle:nil];
    if(self != nil)
    {
        //alloc popover
        self.popover = [[NSPopover alloc] init];
        
        //set mode
        self.popover.behavior = NSPopoverBehaviorApplicationDefined;
        
        //set view controller (to self)
        self.popover.contentViewController = self;
    }

    return self;
}

//'close' button click handler
- (IBAction)interactionHandler:(NSControl *)sender
{
    //send to delegate
    // ->can close the popover
    [self.delegate didClickButton];
}


@end
