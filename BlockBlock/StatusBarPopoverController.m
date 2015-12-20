//TODO: label/copyright!

#import "AppDelegate.h"
#import "StatusBarPopoverController.h"


@implementation StatusBarPopoverController

//'close' button handler
// ->simply close popover
-(IBAction)interactionHandler:(NSControl *)sender
{
    //close
    [[[self view] window] close];
    
    return;
}

@end
