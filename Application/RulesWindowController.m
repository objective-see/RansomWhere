//
//  file: RulesWindowController.m
//  project: RansomWhere? (main app)
//  description: window controller for 'rules' table
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "RuleRow.h"
#import "utilities.h"
#import "AppDelegate.h"
#import "XPCDaemonClient.h"
#import "RulesWindowController.h"

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc daemon
extern XPCDaemonClient* xpcDaemonClient;

@implementation RulesWindowController

@synthesize rules;
@synthesize refreshing;
@synthesize refreshingIndicator;

//configure (UI)
-(void)configure
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked", __PRETTY_FUNCTION__);
    
    //load rules
    [self loadRules];
    
    //center window
    [self.window center];
    
    //show window
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //table resizing settings
    [self.tableView sizeLastColumnToFit];

    return;
}

//clear and reload
-(IBAction)refresh:(id)sender
{
    //remove all rules
    [rules removeAllObjects];
    
    //reload table
    // will clear all data
    [self.tableView reloadData];
    
    //start spinner
    [self.refreshingIndicator startAnimation:nil];
    
    //show message
    self.refreshing.hidden = NO;
    
    //hide overlay
    self.overlay.hidden = YES;
    
    //load rules after a bit
    // ...allows UI to show message
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (250 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self loadRules];
    });
}

//load
-(void)loadRules
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSDictionary* rulesDict = [xpcDaemonClient getRules];
        
        //convert to sorted array for table view
        NSMutableArray* rulesArray = [NSMutableArray array];
        for(NSString* path in rulesDict) {
            [rulesArray addObject:@{
                RULE_PROCESS_PATH: path,
                RULE_ACTION: rulesDict[path]
            }];
        }
        
        //sort by path
        [rulesArray sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:RULE_PROCESS_PATH ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]]];
        
        self.rules = rulesArray;
        
        //reload table on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //reload table
            [self.tableView reloadData];
            
            //update overlay
            self.overlay.hidden = (self.rules.count != 0);
            
            //stop spinner
            [self.refreshingIndicator stopAnimation:nil];
            self.refreshing.hidden = YES;
        });
    });
}

//delete a rule
// grab rule, then invoke daemon to delete
-(IBAction)deleteRule:(id)sender
{
    //index of row
    // either clicked or selected row
    NSInteger row = 0;
    
    //rule
    __block NSDictionary* rule = nil;
    
    //dbg msg
    os_log_debug(logHandle, "deleting rule");
    
    //sender nil?
    // invoked manually due to context menu
    if(nil == sender)
    {
        //get selected row
        row = self.tableView.selectedRow;
    }
    //invoked via button click
    // grab selected row to get index
    else
    {
        //get selected row
        row = [self.tableView rowForView:sender];
    }

    //get rule
    rule = [self ruleForRow:row];
    if(nil != rule)
    {
        //dbg msg
        os_log_debug(logHandle, "deleting rule, %{public}@", rule);
    
        //delete and reload
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //delete
            [xpcDaemonClient deleteRule:rule[RULE_PROCESS_PATH]];
            
            //reload rules
            [self loadRules];
        });
    }
    
    return;
}
- (IBAction)addRule:(id)sender {
    
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked with %{public}@", __PRETTY_FUNCTION__, sender);
    
    //alloc sheet
    self.addRuleWindowController = [[AddRuleWindowController alloc] initWithWindowNibName:@"AddRule"];
    
    //show it
    // on close/OK, invoke XPC to add rule, then reload
    [self.window beginSheet:self.addRuleWindowController.window completionHandler:^(NSModalResponse response) {

            //dbg msg
            os_log_debug(logHandle, "add/edit rule window closed...");
            
            //on OK, add rule via XPC
            if(response == NSModalResponseOK)
            {
                //add
                [xpcDaemonClient addRule:self.addRuleWindowController.rulePath action:self.addRuleWindowController.ruleAction];
                
                //reload rules
                [self loadRules];
            }
            
            //unset add rule window controller
            self.addRuleWindowController = nil;
    }];
}

#pragma mark -
#pragma mark table delegate methods

//number of rows
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    //row's count
    return self.rules.count;
}

//cell for table column
-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString* name = nil;
    NSString* path = nil;
    NSNumber* action = nil;
    NSDictionary* rule = nil;
    
    NSTableCellView *tableCell = nil;
    
    //get rule
    rule = [self ruleForRow:row];
    if(!rule) {
        goto bail;
    }
    
    //extract rule info
    action = rule[RULE_ACTION];
    path = rule[RULE_PROCESS_PATH];
    
    //get name
    name = getBinaryName(path);

    //column: 'process'
    // set process icon, name and path
    if(tableColumn == tableView.tableColumns[0])
    {
        //init table cell
        tableCell = [tableView makeViewWithIdentifier:@"processCell" owner:self];
        if(!tableCell) {
            goto bail;
        }
        
        //set icon
        tableCell.imageView.image = getIconForProcess(rule[RULE_PROCESS_PATH]);
            
        //set main text
        tableCell.textField.stringValue = name;
        
        //set sub text to path
        ((NSTextField*)[tableCell viewWithTag:TABLE_ROW_SUB_TEXT_FILE]).stringValue = path;
        
    }
    
    //column: 'rule'
    // set icon and rule action
    else
    {
        //init table cell
        tableCell = [tableView makeViewWithIdentifier:@"ruleCell" owner:self];
        if(nil == tableCell)
        {
            //bail
            goto bail;
        }
        
        //block
        if(![action boolValue])
        {
            tableCell.imageView.image = [NSImage imageNamed:@"block"];
            tableCell.textField.stringValue = @"block";
        }
        //allow
        else
        {
            tableCell.imageView.image = [NSImage imageNamed:@"allow"];
            tableCell.textField.stringValue = @"allow";
        }
    }
    
bail:
    
    return tableCell;
}

//row for view
-(NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    //row view
    RuleRow* rowView = nil;
    
    //row ID
    static NSString* const kRowIdentifier = @"RowView";
    
    //try grab existing row view
    rowView = [tableView makeViewWithIdentifier:kRowIdentifier owner:self];
    
    //make new if needed
    if(nil == rowView)
    {
        //create new
        // ->size doesn't matter
        rowView = [[RuleRow alloc] initWithFrame:NSZeroRect];
        
        //set row ID
        rowView.identifier = kRowIdentifier;
    }
    
    return rowView;
}

//given a table row
// find/return the corresponding rule
-(NSDictionary*)ruleForRow:(NSInteger)row
{
    //rule
    NSDictionary* rule = nil;
    
    //sanity check
    if(-1 == row) {
        goto bail;
    }
    
    //sync
    @synchronized(self.rules) {
    
        //sanity check
        if(row >= self.rules.count)
        {
            //bail
            goto bail;
        }
    
        //get rule
        rule = self.rules[row];
    
    }//sync
    
bail:
    
    return rule;
}

//on window close
// set activation policy
-(void)windowWillClose:(NSNotification *)notification
{
     //wait a bit, then set activation policy
     dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
     ^{
         //on main thread
         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             
             //set activation policy
             [((AppDelegate*)[[NSApplication sharedApplication] delegate]) setActivationPolicy];
             
         });
     });
    
    return;
}

@end
