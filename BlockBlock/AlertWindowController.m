//
//  AlertWindowController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "AlertView.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "AlertWindowController.h"


#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>


@interface AlertWindowController ()

@end


@implementation AlertWindowController


@synthesize popover;
@synthesize pluginType;
@synthesize parentsButton;
@synthesize rememberButton;
@synthesize processHierarchy;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->add tracking area, etc
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //tracking area for buttons
    NSTrackingArea* trackingArea = nil;
    
    //init tracking area for 'show parents' button
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self.parentsButton bounds] options:(NSTrackingInVisibleRect|NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways) owner:self userInfo:nil];
    
    //add tracking area to 'show parents' button
    [self.parentsButton addTrackingArea:trackingArea];
    
    return;
}

//configure the alert with the info from the daemon
-(void)configure:(NSDictionary*)alertInfo
{
    //instance varialble
    Ivar instanceVariable = nil;
    
    //instance variable obj
    id iVarObj = nil;
    
    //set window level to float
    self.window.level = NSFloatingWindowLevel;
    
    //set delegate
    self.window.delegate = self;
    
    //iterate over all keys
    // ->add value from dictionary into object
    for(NSString* key in alertInfo)
    {
        //process icon is special case
        // ->it was converted to NSData so it could be passed via notification
        if(YES == [key isEqualToString:@"processIcon"])
        {
            //set 'processIcon' iVar
            // ->image must be extracted/converted
            self.processIcon.image = [[NSImage alloc] initWithData:alertInfo[key]];
            
            //next
            continue;
        }
        
        //'watchEventUUID' isn't a UI element
        // ->so just save it here
        else if(YES == [key isEqualToString:KEY_WATCH_EVENT_UUID])
        {
            //set 'watchEventUUID' iVar
            self.watchEventUUID = alertInfo[key];
            
            //next
            continue;
        }
        
        //parent ID isn't a UI element (for now)
        // ->so just save it here
        else if(YES == [key isEqualToString:@"parentID"])
        {
            //set 'watchEventUUID' iVar
            self.parentID = alertInfo[key];
            
            //next
            continue;
        }
        
        //process hierarchy isn't a UI element
        // ->so just save it here
        else if(YES == [key isEqualToString:@"processHierarchy"])
        {
            //set 'watchEventUUID' iVar
            self.processHierarchy = alertInfo[key];
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process heirarchy: %@", self.processHierarchy]);
            
            //next
            continue;
        }
        
        //plugin type isn't a UI element
        // ->so just save it here
        else if(YES == [key isEqualToString:@"pluginType"])
        {
            //set ivar
            self.pluginType = alertInfo[key];
            
            //next
            continue;
        }
        
        //skip signing info
        // ->this is processed when process/item binary is processed
        if( (YES == [key isEqualToString:@"processSigning"]) ||
            (YES == [key isEqualToString:@"itemSigning"]) )
        {
            //next
            continue;
        }
        
        //signing icon
        // ->image name, so load image
        else if(YES == [key isEqualToString:@"signingIcon"])
        {
            //load image
            self.signedIcon.image = [NSImage imageNamed:alertInfo[key]];
            
            //next
            continue;
        }
        
        //handle process name
        // ->combine with process signing info
        else if(YES == [key isEqualToString:@"processName"])
        {
            //add any signing info
            if(nil != [alertInfo objectForKey:@"processSigning"])
            {
                //combine and set
                self.processName.attributedStringValue = [self binarySigningInfo:alertInfo[@"processName"] signingInfo:alertInfo[@"processSigning"]];
            }
            //no signing info
            // ->just set as is
            else
            {
                //set
                self.processName.stringValue = alertInfo[@"processName"];
            }
            
            //next
            continue;
        }
        
        //handle item name
        // ->combine with item's (binary) signing info
        else if(YES == [key isEqualToString:@"itemName"])
        {
            //add any signing info
            if(nil != [alertInfo objectForKey:@"itemSigning"])
            {
                //combine and set
                self.itemName.attributedStringValue = [self binarySigningInfo:alertInfo[@"itemName"] signingInfo:alertInfo[@"itemSigning"]];
            }
            //no signing info
            // ->just set as is
            else
            {
                //set
                self.itemName.stringValue = alertInfo[@"itemName"];
            }
            
            //next
            continue;
        }
        
        //get instance variable by name
        instanceVariable = class_getInstanceVariable([self class], [[NSString stringWithFormat:@"_%s", [key UTF8String]] UTF8String]);
        if(NULL == instanceVariable)
        {
            //next
            continue;
        }
    
        //get iVar object
        iVarObj = object_getIvar(self, instanceVariable);
        
        //most other instance variable should be NSTextFields
        // ->so map in passed string, into the text fields
        if(YES == [[iVarObj class] isSubclassOfClass:[NSTextField class]])
        {
            //set text field's string
            ((NSTextField*)iVarObj).stringValue = alertInfo[key];
        }
    }

    //for commands (e.g. cron jobs), change label
    // ->change to 'startup command'
    if(PLUGIN_TYPE_CRON_JOB == [self.pluginType unsignedIntegerValue])
    {
        //change
        self.itemBinaryLabel.stringValue = @"startup command:";
    }
    //set (back) to default
    else
    {
        //(re)set
        self.itemBinaryLabel.stringValue = @"startup binary:";
    }

    //center alert
    [[self window] center];

    return;
}

//build string with process/binary name + signing info
-(NSAttributedString*)binarySigningInfo:(NSString*)name signingInfo:(NSString*)signingInfo
{
    //info
    NSMutableAttributedString* info = nil;

    //combine both
    info = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@)", name, signingInfo] attributes:@{NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:11]}];
    
    //edit name
    // ->bold and bigger
    [info beginEditing];
    
    //make bigger
    [info addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Menlo-Bold" size:13] range:NSMakeRange(0, name.length)];
    
    //make name bold
    [info applyFontTraits:NSBoldFontMask range:NSMakeRange(0, name.length)];
    
    //done editing
    [info endEditing];
    
    return info;
}

//automatically invoked when mouse entered
// ->when button isn't pressed, show mouse over effects
-(void)mouseEntered:(NSEvent*)theEvent
{
    //only process if button hasn't been clicked
    if(NSOffState == self.parentsButton.state)
    {
        //mouse entered
        // ->highlight (visual) state
        [self.parentsButton setImage:[NSImage imageNamed:@"parentsIconOver"]];
    }
    
    return;
}

//automatically invoked when mouse exits
// ->when button isn't pressed, show mouse exit effects
-(void)mouseExited:(NSEvent*)theEvent
{
    //only process if button hasn't been clicked
    if(NSOffState == self.parentsButton.state)
    {
        //mouse exited
        // ->so reset button to original (visual) state
        [self.parentsButton setImage:[NSImage imageNamed:@"parentsIcon"]];
    }
    
    return;
}

//automatically invoked when user clicks 'block' or 'allow'
// invokes 'sendActionToDaemon' so that notification will be sent/handled
-(void)doAction:(id)sender
{
    //action info
    NSDictionary* actionInfo = nil;
    
    //action
    // ->block or allow
    NSInteger action = 0;
    
    //sanity check
    if(nil == self.watchEventUUID)
    {
        //bail
        goto bail;
    }
    
    //set action
    // ->allow
    if(sender == self.allowButton)
    {
        //allow
        action = ALLOW_WATCH_EVENT;
    }
    //set action
    // ->block
    else
    {
        //allow
        action = BLOCK_WATCH_EVENT;
    }
    
    //dbg msg
    // ->and to file (if logging is enabled)
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"user clicked: %@", ((NSButton*)sender).title]);
    
    //init dictionary w/ action info
    actionInfo = @{KEY_WATCH_EVENT_UUID:self.watchEventUUID, KEY_ACTION:[NSNumber numberWithInteger:action], KEY_REMEMBER:[NSNumber numberWithInteger:self.rememberButton.state], KEY_ALERT_WINDOW:self};
    
    //send notification to daemon
    // ->will ignore or block it :)
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendActionToDaemon:[actionInfo mutableCopy]];
    
    //take care of popup
    if(NSOnState == self.parentsButton.state)
    {
        //remove/close
        [self deInitPopup];
    }
    
    //close window
    [self close];
    
//bail
bail:
    
    return;
}

//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //reset button's state
    self.parentsButton.state = NSOffState;
    
    //reset button's image to original (visual) state
    [self.parentsButton setImage:[NSImage imageNamed:@"parentsIcon"]];
    
    return;
}

//automatically invoked when user clicks process ancestry button
-(IBAction)ancestryButtonHandler:(id)sender
{
    //when button is clicked
    // ->open popover
    if(NSOnState == self.parentsButton.state)
    {
        //set process hierarchy
        self.ancestryViewController.processHierarchy = self.processHierarchy;
        
        //dynamically (re)size popover
        [self setPopoverSize];
        
        //auto-expand
        [self.ancestryOutline expandItem:nil expandChildren:YES];
    
        //show popover
        [self.popover showRelativeToRect:[self.parentsButton bounds] ofView:self.parentsButton preferredEdge:NSMaxYEdge];
    }
    //otherwise
    // ->close popover
    else
    {
        //hide popover
        [self.popover close];
    }
    
    return;
}

//set the popover window size
// ->make it roughly fit to content :)
-(void)setPopoverSize
{
    //popover's frame
    CGRect popoverFrame = {0};
    
    //required height
    CGFloat popoverHeight = 0.0f;
 
    //text of current row
    NSString* currentRow = nil;
    
    //width of current row
    CGFloat currentRowWidth = 0.0f;
    
    //length of max line
    CGFloat maxRowWidth = 0.0f;
    
    //extra rows
    NSUInteger extraRows = 0;
    
    //when hierarchy is less than 4
    // ->set (some) extra rows
    if(self.ancestryViewController.processHierarchy.count < 4)
    {
        //5 total
        extraRows = 4 - self.ancestryViewController.processHierarchy.count;
    }
    
    //calc total window height
    // ->number of rows + extra rows, * height
    popoverHeight = (self.ancestryViewController.processHierarchy.count + extraRows + 2) * [self.ancestryOutline rowHeight];
   
    //get window's frame
    popoverFrame = self.ancestorView.frame;
    
    //calculate max line width
    for(NSUInteger i=0; i<self.ancestryViewController.processHierarchy.count; i++)
    {
        //generate text of current row
        currentRow = [NSString stringWithFormat:@"%@ (pid: %@)", self.ancestryViewController.processHierarchy[i][@"name"], [self.ancestryViewController.processHierarchy lastObject][@"pid"]];

        //calculate width
        // ->first w/ indentation
        currentRowWidth = [self.ancestryOutline indentationPerLevel] * i;
        
        //calculate width
        // ->then size of string in row
        currentRowWidth += [currentRow sizeWithAttributes: @{NSFontAttributeName: self.ancestorTextCell.font}].width;
        
        //save it greater than max
        if(maxRowWidth < currentRowWidth)
        {
            //save
            maxRowWidth = currentRowWidth;
        }
    }
    
    //add some padding
    // ->scroll bar, etc
    maxRowWidth += 50;

    //set height
    popoverFrame.size.height = popoverHeight;
    
    //set width
    popoverFrame.size.width = maxRowWidth;
    
    //set new frame
    self.ancestorView.frame = popoverFrame;
    
    return;
}

//logic to close/remove popup from view
// ->needed, otherwise random memory issues occur :/
-(void)deInitPopup
{
    //close
    [self.popover close];
        
    //remove view
    [self.ancestorView removeFromSuperview];
    
    //set to nil
    self.popover = nil;

    return;
}

@end
