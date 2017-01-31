//
//  PopoverViewController.m
//  BlockBlock
//
//  Created by Patrick Wardle on 1/8/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "Utilities.h"
#import "VirusTotal.h"
#import "HyperlinkTextField.h"
#import "PopoverViewController.h"

@implementation PopoverViewController

@synthesize type;
@synthesize items;
@synthesize vtSpinner;
@synthesize vtQueryMsg;
@synthesize firstItem;
@synthesize secondItem;

-(void)awakeFromNib
{
    //alloc array for items
    items = [NSMutableArray array];
}

//automatically invoked
// ->configure popover and kick off VT queries
-(void)popoverWillShow:(NSNotification *)notification;
{
    //hide first item label
    self.firstItem.hidden = YES;
    
    //hide second item label
    self.secondItem.hidden = YES;
    
    //set message
    self.vtQueryMsg.stringValue = @"querying virus total...";
    
    //show message
    self.vtQueryMsg.hidden = NO;
    
    //show spinner
    self.vtSpinner.hidden = NO;
    
    //start spinner
    [self.vtSpinner startAnimation:nil];
    
    //bg thread for VT
    [self performSelectorInBackground:@selector(queryVT) withObject:nil];
    
    return;
}

//cleanup
-(void)popoverDidClose:(NSNotification *)notification
{
    //remove all items
    [self.items removeAllObjects];
    
    return;
}


//make a query to VT in the background
// ->invokes helper function to update UI as needed (results/errors)
-(void)queryVT
{
    //vt object
    VirusTotal* vtObj = nil;
    
    //hash
    NSString* hash = nil;
    
    //hash flag
    BOOL addedHash = NO;
    
    //alloc
    vtObj = [[VirusTotal alloc] init];
    
    //nap to allow msg/spinner to do a bit
    [NSThread sleepForTimeInterval:1.0f];
    
    //hash all items
    for(NSMutableDictionary* item in self.items)
    {
        //hash
        hash = hashFile(item[@"path"]);
        if(0 != hash.length)
        {
            //add
            item[@"hash"] = hash;
            
            //set flag
            addedHash = YES;
        }
    }
    
    //sanity check
    if( (0 == items.count) ||
        (YES != addedHash) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"didn't get any items/hashes to submit: %@", self.items]);
        
        //show error on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //show error
            [self showError];
            
        });
    }
    
    //query vt
    // ->response will be parsed and mapped into each item
    else
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"querying VT with %@", self.items]);
        #endif
        
        //query VT
        // ->also check for error (offline, etc)
        if(YES == [vtObj queryVT:self.type items:self.items])
        {
            //update UI on main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                //update UI
                [self displayResults];
                
            });
        }
        
        //error
        else
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to query virus total: %@", self.items]);
            
            //show error on main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                //show error
                [self showError];
                
            });
        }
    }

    return;
}

//display results
-(void)displayResults
{
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"VT response: %@", self.items]);
    #endif
    
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    //hide query message
    self.vtQueryMsg.hidden = YES;
    
    //check for first item
    // ->then format/add it to UI
    if(self.items.count > 0x0)
    {
        //format/set info
        self.firstItem.attributedStringValue = [self formatVTInfo:self.items[0]];
        
        //show it
        self.firstItem.hidden = NO;
    }
    
    //check for second item
    // ->then format/add it to UI
    if(self.items.count > 0x1)
    {
        //format/set info
        self.secondItem.attributedStringValue = [self formatVTInfo:self.items[1]];
        
        //show it
        self.secondItem.hidden = NO;
    }
    
    return;
}

//show error in UI
-(void)showError
{
    //stop spinner
    [self.vtSpinner stopAnimation:nil];
    
    //hide spinner
    self.vtSpinner.hidden = YES;
    
    //set message
    self.vtQueryMsg.stringValue = @"failed to query virus total :(";
    
    //show message
    self.vtQueryMsg.hidden = NO;
    
    return;
}

//build string with process/binary name + signing info
-(NSAttributedString*)formatVTInfo:(NSDictionary*)item
{
    //info
    NSMutableAttributedString* info = nil;
    
    //string attributes
    NSDictionary* attributes = nil;
    
    //name
    // ->handles truncations, etc
    NSString* name = nil;
    
    //init string
    info = [[NSMutableAttributedString alloc] initWithString:@""];
    
    //init string attributes
    attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo-Bold" size:13]};

    //grab name
    name = item[@"name"];
    
    //truncate long names
    if(name.length > 25)
    {
        //truncate
        name = [[name substringToIndex:22] stringByAppendingString:@"..."];
    }
    
    //add name
    [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: ", name] attributes:attributes]];
    
    //un-set bold attributes
    attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13]};
    
    //sanity check
    if( (nil == item[@"vtInfo"]) ||
        (nil == item[@"vtInfo"][@"found"]) )
    {
        //set
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"received invalid response"]];
        
        //bail
        goto bail;
    }

    //add ratio and report link if file is found
    if(0 != [item[@"vtInfo"][@"found"] intValue])
    {
        //sanity check
        if( (nil == item[@"vtInfo"][@"detection_ratio"]) ||
            (nil == item[@"vtInfo"][@"permalink"]) )
        {
            //set
            [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"received invalid response"]];
            
            //bail
            goto bail;
        }
        
        //make ratio red if there are positives
        if( (nil != item[@"vtInfo"][@"positives"]) &&
            (0 != item[@"vtInfo"][@"positives"]) )
        {
            //red
            attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13], NSForegroundColorAttributeName:[NSColor redColor]};
        }
        
        //add ratio
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@, ", item[@"vtInfo"][@"detection_ratio"]] attributes:attributes]];
        
        //set attributes to for html link for report
        attributes = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:13], NSLinkAttributeName:[NSURL URLWithString:item[@"vtInfo"][@"permalink"]], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSSingleUnderlineStyle]};
        
        //add link to full report
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"details" attributes:attributes]];

    }
    //file not found on vt
    else
    {
        //add ratio
        [info appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@"not found" attributes:attributes]];
    }
    
//bail
bail:
    
    return info;
}

@end
