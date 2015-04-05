//
//  WOMController.m
//  PopoverMenulet
//
//  Created by Julián Romero on 10/26/11.
//  Copyright (c) 2011 Wuonm Web Services S.L. All rights reserved.
//

#import "WOMController.h"
#import "WOMMenulet.h"
#import "WOMPopoverController.h"

@interface WOMController ()
@property NSString *droppedDirectory; /* FIXME: temporary */
@end

@implementation WOMController

@synthesize viewController;
@synthesize item;

- (instancetype)init
{
    self = [super init];
    

    //create statu bar item
    CGFloat thickness = [[NSStatusBar systemStatusBar] thickness];
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:thickness];
    
    
    //custom view
    self.menulet = [[WOMMenulet alloc] initWithFrame:(NSRect){.size={thickness, thickness}}]; /* square item */
    
    //delegate is this controller
    self.menulet.delegate = self;
    
    //set custom view as view for status bar item
    [self.item setView:self.menulet];
    
    //disable highlighting
    [self.item setHighlightMode:NO]; /* blue background when clicked ? */
    
    
    //show popup!
    // ->gotta wait...not sure why? for status item to show up?
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.menulet mouseDown: nil];
    });
    
    
    return self;
}



#pragma mark - Popover

- (void)closePopover
{
    self.active = NO;
    
    //invoke NSPopover performClose method
    [self.viewController.popover performClose:self];
   
    //re-draw view
    [self.menulet setNeedsDisplay:YES];
}

//open
- (void)openPopover
{
    [self _setup];
    
    //invoke NSPopover showRelativeToRect method
    [self.viewController.popover showRelativeToRect:[self.menulet frame]
                                             ofView:self.menulet
                                      preferredEdge:NSMinYEdge];
}

#pragma mark - WOMMenuletDelegate

- (NSString *)activeImageName
{
    return @"menulet-icon-on.png";
}

- (NSString *)inactiveImageName
{
    return @"menulet-icon-off.png";
}

- (void)menuletClicked:(MouseButton)mouseButton
{
    self.active = ! self.active;
    
    if (self.isActive)
        [self openPopover];
    else
        [self closePopover];
}


#pragma mark - WOMPopoverDelegate
- (void)popover:(id)popover didClickButtonForAction:(NSUInteger)action
{
    NSLog(@"did click button for action %@", @(action));
    [self closePopover];
}


#pragma mark - Private

- (void)_setup
{
    if (!self.viewController) {
        self.viewController = [[WOMPopoverController alloc] init];
        self.viewController.delegate = self;
    }
}

@end
