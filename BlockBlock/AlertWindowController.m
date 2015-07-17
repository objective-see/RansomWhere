//
//  AlertWindowController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "AlertWindowController.h"
#import "AlertView.h"
#import "PluginBase.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "Logging.h"
#import "Consts.h"
#import "Utilities.h"


#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>


@interface AlertWindowController ()

@end


@implementation AlertWindowController


@synthesize popover;
@synthesize instance;
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
// ->set to white
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
    
    //save instance
    // ->needed to ensure window isn't ARC-dealloc'd when this function returns
    self.instance = self;
    
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
        
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"checking for %@ in object", key]);
        
        //get instance variable by name
        instanceVariable = class_getInstanceVariable([self class], [[NSString stringWithFormat:@"_%s", [key UTF8String]] UTF8String]);
        
        //check
        // ->this is ok if this fails since passed keys aren't needed/used by the window
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
    
    //make sure text's fits
    // ->some might be multiple lines...
    [self adjust2Fit];
    
    //center alert
    [[self window] center];

    return;
}

//shift/resize the text views as needed
-(void)adjust2Fit
{
    //frame for current element
    CGRect elementFrame = {0};
    
    //rectangle that would fit content
    CGRect size2Fit = {0};
    
    //total increase in size
    float totalIncrease = 0;
    
    //width
    float width = 0;
    
    //calc width for process path
    width = [self findMaxWidth:self.processPath];
    
    //truncate/add '...'s to process path
    // ->may be needed since text field only has two lines (max)
    [self.processPath setStringValue:stringByTruncatingString(self.processPath, width)];
    
    //grab item file's frame
    elementFrame = self.itemFile.frame;
    
    //[self.itemFile setStringValue:[NSString stringWithFormat:@"%@ + %@", [self.itemFile stringValue], [self.itemFile stringValue]]];
    
    //get size to fit for item file
    size2Fit = [[self.itemFile stringValue] boundingRectWithSize:CGSizeMake(elementFrame.size.width, 0) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:self.itemFile.font}];
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"font = %@\tbounds = (%f x %f)",
    //                   [self.itemFile.font fontName],
    //                   size2Fit.size.width,
    //                   size2Fit.size.height]);
    
    
    //check height of item file's frame
    // ->needs to be increased?
    if(size2Fit.size.height > elementFrame.size.height)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"item file path too long, increasing size: %f", elementFrame.size.height]);
        
        //calc width for item file
        width = [self findMaxWidth:self.itemFile];
        
        //truncate/add '...'s to item file
        // ->may be needed since text field only has two lines (max)
        [self.itemFile setStringValue:stringByTruncatingString(self.itemFile, width)];
        
        //increase
        totalIncrease += elementFrame.size.height;
        
        //double height
        [self increaseElementHeight:self.itemFile height:2*elementFrame.size.height];
        
        //shift down item binary label
        [self shiftElementVertically:self.itemBinaryLabel shift:totalIncrease];
        
        //shift down item binary
        [self shiftElementVertically:self.itemBinary shift:totalIncrease];
    }
    
    //grab item binary's frame
    elementFrame = self.itemBinary.frame;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"element frame: %@", NSStringFromRect(elementFrame)]);
    
    //[self.itemBinary setStringValue:[NSString stringWithFormat:@"%@ + %@", [self.itemBinary stringValue], [self.itemBinary stringValue]]];
    
    //get size to fit for item binary
    size2Fit = [[self.itemBinary stringValue] boundingRectWithSize:CGSizeMake(elementFrame.size.width, 0) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:self.itemBinary.font}];
    
    //check height of item binary's frame
    // ->needs to be increased?
    if(size2Fit.size.height > elementFrame.size.height)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"item binany path too long, increasing size: %f", elementFrame.size.height]);
        
        //calc width for item binary
        width = [self findMaxWidth:self.itemBinary];

        //truncate/add '...'s to item binary
        // ->may be needed since text field only has two lines (max)
        [self.itemBinary setStringValue:stringByTruncatingString(self.itemBinary, width)];
        
        //increase
        totalIncrease += elementFrame.size.height;
        
        //double height
        [self increaseElementHeight:self.itemBinary height:2*elementFrame.size.height];
    }
    
    //any shifts?
    // ->shift down buttons and increase main view
    if(0 != totalIncrease)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"shifting buttons down: %f", totalIncrease]);
        
        //shift down 'block' button
        [self shiftElementVertically:self.blockButton shift:totalIncrease];
        
        //shift down item binary
        [self shiftElementVertically:self.allowButton shift:totalIncrease];
        
        //grab frame of main view
        elementFrame = self.mainView.frame;
        
        //increase height
        elementFrame.size.height += totalIncrease;
        
        //keep origin the same
        elementFrame.origin.y -= totalIncrease;
        
        //update frame
        self.mainView.frame = elementFrame;
        
        //grab frame of bottom view
        elementFrame = self.bottomView.frame;
        
        //increase height
        elementFrame.size.height += totalIncrease;
        
        //keep origin the same
        elementFrame.origin.y -= totalIncrease;
        
        //update frame
        self.bottomView.frame = elementFrame;
        
    }//shift buttons and increase view size
    
    return;
}

//increase size of element
-(void)increaseElementHeight:(NSControl*)element height:(float)height
{
    //frame
    CGRect frame = {};
    
    //get current frame
    frame = element.frame;
    
    //increase height
    frame.size.height = height;
    
    //make sure origins stays in 'same place'
    // ->OS X cooridates go 'upwards' :/
    frame.origin.y = frame.origin.y - height + element.frame.size.height;
    
    //set new frame
    element.frame = frame;

    return;
}

//shift an element
-(void)shiftElementVertically:(NSControl*)element shift:(float)shift
{
    //frame
    CGRect frame = {0};
    
    //get current frame
    frame = element.frame;
    
    //shift
    frame.origin.y -= shift;
    
    //set new frame
    element.frame = frame;

    return;
}

//find the max width available in the text field
// ->takes into account font, and word-wrapping breaks!
-(float)findMaxWidth:(NSTextField*)textField
{
    //width
    float width = 0;
    
    //style
    NSMutableParagraphStyle *style = nil;
    
    //attributed string
    NSAttributedString *attrStr = nil;
    
    //frame setter
    CTFramesetterRef frameSetter = NULL;
    
    //path
    CGMutablePathRef path = NULL;
    
    //frame
    CTFrameRef frame = NULL;
    
    //first line ref
    CTLineRef firstLine = NULL;
    
    //first line range
    CFRange lineRange = {0};
    
    //substring
    // ->first line
    NSString* subString = nil;
    
    //alloc/init style
    style = [[NSMutableParagraphStyle alloc] init];
    
    //set paragraph style
    [style setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    
    //set text alignment
    [style setAlignment:NSLeftTextAlignment];
    
    //set line-break mode
    // ->word-wrap!
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    
    //init attributed string
    // ->uses text field's text, a style (w/ word-wrap) and font
    attrStr = [[NSAttributedString alloc] initWithString:[textField stringValue] attributes:@{NSParagraphStyleAttributeName: style,NSFontAttributeName: textField.font}];
    
    //create frame setter with attributed string
    frameSetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attrStr);
    
    //init path
    path = CGPathCreateMutable();
    
    //add text field rect to path
    CGPathAddRect(path, NULL, CGRectMake(0,0, textField.frame.size.width, textField.frame.size.height));
    
    //create frame
    frame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, NULL);

    //draw
    CTFrameDraw(frame, NULL);
    
    //get first line
    firstLine = (__bridge CTLineRef)[(__bridge NSArray*)CTFrameGetLines(frame) firstObject];
    
    //get first line's range
    lineRange = CTLineGetStringRange(firstLine);
    
    //make substring
    // ->string on first line
    subString = [[textField stringValue] substringWithRange:NSMakeRange(lineRange.location, lineRange.length)];
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"substring: %@", subString]);
    
    //NSLog(@"length: %f", [subString sizeWithAttributes: @{NSFontAttributeName: textField.font}].width);
    
    //if item fits in one line
    // ->just return width as is!
    if(1 == [(__bridge NSArray*)CTFrameGetLines(frame) count])
    {
        //width of just first line
        width = [subString sizeWithAttributes: @{NSFontAttributeName: textField.font}].width;
    }
    else
    {
        //width
        // ->first line string, then rest of last line
        width = [subString sizeWithAttributes: @{NSFontAttributeName: textField.font}].width + textField.frame.size.width;
    }
    
//bail
bail:
    
    //release path
    CGPathRelease(path);
    
    //release frame
    CFRelease(frame);
    
    //release frame setter
    CFRelease(frameSetter);

    return width;
}

//automatically invoked when mouse entered
// ->when button isn't pressed, show mouse over effects
-(void)mouseEntered:(NSEvent*)theEvent
{
    //only process if button hasn't been clicked
    if(0 == self.parentsButton.state)
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
    if(0 == self.parentsButton.state)
    {
        //mouse exited
        // ->so reset button to original (visual) state
        [self.parentsButton setImage:[NSImage imageNamed:@"parentsIcon"]];
    }
    
    return;
}


//automatically invoked when user clicks 'deny'
// invokes 'sendActionToDaemon' so that notification will be sent/handled
-(void)deny:(id)sender
{
    //action info
    NSDictionary* actionInfo = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"user clicked: 'block'");
    
    //init dictionary w/ action info
    actionInfo = @{KEY_WATCH_EVENT_UUID:self.watchEventUUID, KEY_ACTION:[NSNumber numberWithInteger:BLOCK_WATCH_EVENT], KEY_REMEMBER:[NSNumber numberWithInteger:self.rememberButton.state]};
    
    //send notification to daemon
    // ->block it!
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendActionToDaemon:actionInfo];
    
    //close window
    [self close];
    
    return;
}

//automatically invoked when user clicks 'allow'
// invokes 'sendActionToDaemon' so that notification will be sent/handled
-(void)allow:(id)sender
{
    //action info
    NSDictionary* actionInfo = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"user clicked: 'allow'");
    
    //init dictionary w/ action info
    actionInfo = @{KEY_WATCH_EVENT_UUID:self.watchEventUUID, KEY_ACTION:[NSNumber numberWithInteger:ALLOW_WATCH_EVENT], KEY_REMEMBER:[NSNumber numberWithInteger:self.rememberButton.state]};
    
    //send notification to daemon
    // ->allow it!
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).interProcComms sendActionToDaemon:actionInfo];

    //close window
    [self close];
    
    return;
}

//automatically invoked when window is closing
// ->tell OS that we are done with window so it can (now) be freed
-(void)windowWillClose:(NSNotification *)notification
{
    //always make sure popover is closed
    if(0x1 == self.parentsButton.state)
    {
        //close
        [self.popover close];
    }
    
    //set strong instance var to nil
    // ->will tell ARC, its finally ok to release us :)
    self.instance = nil;
    
    return;
}

//automatically invoked when user clicks process ancestry button
-(IBAction)ancestryButtonHandler:(id)sender
{
    //when button is clicked
    // ->open popover
    if(0x1 == self.parentsButton.state)
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
    
    //when heirarchy is less than 5
    // ->set three extra rows
    if(self.ancestryViewController.processHierarchy.count < 5)
    {
        //3 extra
        extraRows = 3;
    }
    
    //calc total window height
    // ->number of rows + extra rows, * height
    popoverHeight = (self.ancestryViewController.processHierarchy.count + 1 + extraRows) * [self.ancestryOutline rowHeight];
   
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
    maxRowWidth += 30;

    //set height
    popoverFrame.size.height = popoverHeight;
    
    //set width
    popoverFrame.size.width = maxRowWidth;
    
    //set new frame
    self.ancestorView.frame = popoverFrame;
    
    return;
}

@end
