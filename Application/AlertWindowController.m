//
//  file: AlertWindowController.m
//  project: RansomWhere? (login item)
//  description: window controller for main firewall alert
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <sys/socket.h>

#import "consts.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "AlertWindowController.h"

//#import "FileMonitor/FileMonitor.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc daemon
extern XPCDaemonClient* xpcDaemonClient;

@implementation AlertWindowController

@synthesize alert;
@synthesize processIcon;
@synthesize processName;
@synthesize processSummary;
@synthesize ancestryButton;
@synthesize ancestryPopover;
@synthesize processHierarchy;
@synthesize virusTotalButton;
@synthesize signingInfoButton;
@synthesize virusTotalPopover;

//center window
// also, transparency
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //full size content view for translucency
    self.window.styleMask = self.window.styleMask | NSWindowStyleMaskFullSizeContentView;
    
    //title bar; translucency
    self.window.titlebarAppearsTransparent = YES;
    
    //move via background
    self.window.movableByWindowBackground = YES;
    
    return;
}

//delegate method
// populate/configure alert window
-(void)windowDidLoad
{
    //paragraph style (for temporary label)
    NSMutableParagraphStyle* paragraphStyle = nil;
    
    //title attributes (for temporary label)
    NSMutableDictionary* titleAttributes = nil;
    
    //init paragraph style
    paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    
    //init dictionary for title attributes
    titleAttributes = [NSMutableDictionary dictionary];
    
    //set target for 'x' button
    [self.window standardWindowButton:NSWindowCloseButton].target = self;
    
    //set action for 'x' button
    [self.window standardWindowButton:NSWindowCloseButton].action = @selector(handleUserResponse:);
    
    //extract process hierarchy
    self.processHierarchy = alert[ALERT_PROCESS_ANCESTORS];
    
    //disable ancestory button if no ancestors
    if(0 == self.processHierarchy.count)
    {
        //disable
        self.ancestryButton.enabled = NO;
    }
    
    /* TOP */
    
    //set process icon
    self.processIcon.image = getIconForProcess(self.alert[ALERT_PROCESS_PATH]);
    
    //process signing info
    [self setSigningIcon];
    
    //set process name
    self.processName.stringValue = self.alert[ALERT_PROCESS_NAME];
    
    //alert message
    self.alertMessage.stringValue = self.alert[ALERT_MESSAGE];
    
    /* BOTTOM */
    
    //set summary
    // name and pid
    self.processSummary.stringValue = [NSString stringWithFormat:@"%@ (pid: %@)", self.alert[ALERT_PROCESS_NAME], self.alert[ALERT_PROCESS_ID]];
    
    //no args?
    // hide process args label
    if([self.alert[ALERT_PROCESS_ARGS] count] < 2)
    {
        //hide
        self.processArgsLabel.hidden = YES;
    }
       
    //process args
    // create string of all
    else
    {
        //show
        self.processArgsLabel.hidden = NO;
        
        //add each arg
        // note: skip first, since the process name
        [self.alert[ALERT_PROCESS_ARGS] enumerateObjectsUsingBlock:^(NSString* argument, NSUInteger index, BOOL* stop) {
            
            //skip first arg
            if(0 == index) return;
            
            //add argument
            self.processArgs.stringValue = [self.processArgs.stringValue stringByAppendingFormat:@"%@ ", argument];
            
        }];
    }
    
    //process path
    self.processPath.stringValue = self.alert[ALERT_PROCESS_PATH];
    
    //add list of encrypted files
    NSArray* files = self.alert[ALERT_ENCRYPTED_FILES];
    NSUInteger count = MIN(files.count, 3);

    NSMutableString* fileList = [NSMutableString string];
    for(NSUInteger i = 0; i < count; i++) {
        if(i > 0) [fileList appendString:@"\n"];
        [fileList appendString:files[i]];
    }

    self.encryptedFiles.stringValue = fileList;
    
    //add a timestamp
    self.timeStamp.stringValue = [NSDateFormatter localizedStringFromDate:NSDate.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterMediumStyle];
    
bail:
    
    return;
}

//set signing icon
-(void)setSigningIcon
{
    //flags
    uint32_t csFlags = 0;
    
    //image
    NSImage* image = nil;
    
    //signing info
    NSDictionary* signingInfo = nil;
    
    //dbg msg
    os_log_debug(logHandle, "processing signing information");
    
    //default to unknown
    image = [NSImage imageNamed:@"SignedUnknown"];
    
    //extract signing info
    signingInfo = self.alert[ALERT_PROCESS_SIGNING_INFO];
    
    //extract flags
    csFlags = [signingInfo[CS_FLAGS] unsignedIntValue];
    
    //unsigned?
    if(0 == csFlags)
    {
        //unsigned
        image = [NSImage imageNamed:@"Unsigned"];
        
        //bail
        goto bail;
    }
    
    //validly signed?
    if(csFlags & CS_VALID)
    {
        //apple?
        if(YES == [signingInfo[PLATFORM_BINARY] boolValue])
        {
            //apple
            image = [NSImage imageNamed:@"SignedApple"];
        }
        
        //signed by dev id/ad hoc, etc
        else
        {
            //set icon
            image = [NSImage imageNamed:@"Signed"];
        }
        
        //bail
        goto bail;
    }
    
bail:
    
    //set image
    signingInfoButton.image = image;
    
    return;
}

//automatically invoked when user clicks signing icon
// depending on state, show/populate the popup, or close it
-(IBAction)signingInfoButtonHandler:(id)sender
{
    //view controller
    SigningInfoViewController* popover = nil;
    
    //open popover
    if(NSControlStateValueOn == self.signingInfoButton.state)
    {
        //grab delegate
        popover = (SigningInfoViewController*)self.signingInfoPopover.delegate;
        
        //set icon image
        popover.icon.image = self.signingInfoButton.image;
        
        //set alert info
        popover.alert = self.alert;
        
        //show popover
        [self.signingInfoPopover showRelativeToRect:[self.signingInfoButton bounds] ofView:self.signingInfoButton preferredEdge:NSMaxYEdge];
    }
    
    //close popover
    else
    {
        //close
        [self.signingInfoPopover close];
    }
    
    return;
}

//VT button handler
// open user's browser w/ VT results
-(IBAction)vtButtonHandler:(id)sender
{
    NSString* path = nil;
    NSString* hash = nil;
    
    //default
    path = self.processPath.stringValue;
    
    //package?
    // get path of binary from bundle
    if([NSWorkspace.sharedWorkspace isFilePackageAtPath:self.processPath.stringValue]) {
        
        //get path
        path = getBundleExecutable(self.processPath.stringValue);
    }
    
    //hash
    if(path) {
        hash = hashFile(path);
    }
    if(hash) {
        
        //dbg msg
        os_log_debug(logHandle, "%{public}@ hashed to %{public}@ for VT", path, hash);
        
        //open/show in browser
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.virustotal.com/gui/file/%@", hash]]];
    }
    //error
    else {
       showAlert(NSAlertStyleWarning, [NSString stringWithFormat:NSLocalizedString(@"ERROR: Failed to hash %@", @"ERROR: Failed to hash %@"), self.processName.stringValue], nil, @[NSLocalizedString(@"OK", @"OK")]);
    }
    
    return;
}

//invoked when user clicks process ancestry button
// depending on state, show/populate the popup, or close it
-(IBAction)ancestryButtonHandler:(id)sender
{
    //open popover
    if(NSControlStateValueOn == self.ancestryButton.state)
    {
        //add the index value to each process in the hierarchy
        // used to populate outline/table
        for(NSUInteger i = 0; i < processHierarchy.count; i++)
        {
            //set index
            processHierarchy[i][@"index"] = [NSNumber numberWithInteger:i];
        }

        //set process hierarchy
        self.ancestryViewController.processHierarchy = processHierarchy;
        
        //dynamically (re)size popover
        [self setPopoverSize];
        
        //reload it
        [self.ancestryOutline reloadData];
        
        //auto-expand
        [self.ancestryOutline expandItem:nil expandChildren:YES];
        
        //show popover
        [self.ancestryPopover showRelativeToRect:[self.ancestryButton bounds] ofView:self.ancestryButton preferredEdge:NSMaxYEdge];
    }
    
    //close popover
    else
    {
        //close
        [self.ancestryPopover close];
    }
    
    return;
}

//set the popover window size
// make it roughly fit to content
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
    popoverFrame = self.ancestryView.frame;
    
    //calculate max line width
    for(NSUInteger i=0; i<self.ancestryViewController.processHierarchy.count; i++)
    {
        //generate text of current row
        currentRow = [NSString stringWithFormat:@"%@ (pid: %@)", self.ancestryViewController.processHierarchy[i][@"name"], [self.ancestryViewController.processHierarchy lastObject][@"pid"]];
        
        //calculate width
        // ->first w/ indentation
        currentRowWidth = [self.ancestryOutline indentationPerLevel] * (i+1);
        
        //calculate width
        // ->then size of string in row
        currentRowWidth += [currentRow sizeWithAttributes: @{NSFontAttributeName: self.ancestryTextCell.font}].width;
        
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
    self.ancestryView.frame = popoverFrame;
    
    return;
}

//close any open popups
-(void)closePopups
{
    //virus total popup
    if(NSControlStateValueOn == self.virusTotalButton.state)
    {
        //close
        [self.virusTotalPopover close];
    
        //set button state to off
        self.virusTotalButton.state = NSControlStateValueOff;
    }
    
    //process ancestry popup
    if(NSControlStateValueOn == self.ancestryButton.state)
    {
        //close
        [self.ancestryPopover close];
        
        //set button state to off
        self.ancestryButton.state = NSControlStateValueOff;
    }
    
    //signing info popup
    if(NSControlStateValueOn == self.signingInfoButton.state)
    {
        //close
        [self.signingInfoPopover close];
        
        //set button state to off
        self.signingInfoButton.state = NSControlStateValueOff;
    }
    
    return;
}

//handler for user's response to alert
-(IBAction)handleUserResponse:(id)sender
{
    //response to daemon
    NSMutableDictionary* alertResponse = nil;
    
    //dbg msg
    os_log_debug(logHandle, "user clicked: %ld", (long)((NSButton*)sender).tag);
    
    //init alert response
    // start w/ copy of received alert
    alertResponse = [self.alert mutableCopy];
    
    //add current user
    alertResponse[ALERT_USER] = [NSNumber numberWithUnsignedInt:getuid()];
    
    //add action scope
    alertResponse[ALERT_ACTION_SCOPE] = [NSNumber numberWithInteger:self.actionScope.indexOfSelectedItem];
    
    //add user response
    alertResponse[ALERT_ACTION] = [NSNumber numberWithLong:((NSButton*)sender).tag];
    
    //save button state for "create rule"
    alertResponse[ALERT_CREATE_RULE] = [NSNumber numberWithBool:(BOOL)self.createRule.state];
    
    //dbg msg
    os_log_debug(logHandle, "responding to daemon, alert: %{public}@", alertResponse);
    
    //close popups
    [self closePopups];
    
    //close window
    [self.window close];

    //send response to daemon
    [xpcDaemonClient alertReply:alertResponse];
    
    //not temp rule & rules window visible?
    // then refresh it, as rules have changed
    if( (YES != [alertResponse[ALERT_CREATE_RULE] boolValue]) &&
        (YES == ((AppDelegate*)[[NSApplication sharedApplication] delegate]).rulesWindowController.window.isVisible) )
    {
        //(shortly thereafter) refresh rules window
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            
            //refresh rules (window)
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]).rulesWindowController loadRules];
            
        });
    }
    
    return;
}

@end
