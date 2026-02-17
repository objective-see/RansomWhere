//
//  file: Rules.h
//  project: RansomWhere? (launch daemon)
//  description: handles rules & actions such as add/delete
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "Rules.h"
#import "Monitor.h"

/* GLOBALS */
extern Monitor* monitor;
extern os_log_t logHandle;

@implementation Rules

@synthesize rules;

-(id)init
{
    self = [super init];
    if(nil != self){
        rules = [NSMutableDictionary dictionary];
    }
    return self;
}

//load rules from plist
-(BOOL)load
{
    //rule's file
    NSString* file = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    os_log_debug(logHandle, "loading rules from: %{public}@", file);
    
    //only load if there are rules
    if([NSFileManager.defaultManager fileExistsAtPath:file]) {
        
        //load plist
        NSDictionary* loadedRules = [NSDictionary dictionaryWithContentsOfFile:file];
        if(!loadedRules) {
            os_log_error(logHandle, "ERROR: failed to load rules from: %{public}@", file);
            return NO;
        }
        
        //set
        self.rules = [loadedRules mutableCopy];
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded %lu rules from: %{public}@", (unsigned long)self.rules.count, file);
    
    return YES;
}

//find rule
// note: key is process path
// returns RULE_ALLOW, RULE_BLOCK, or RULE_NOT_FOUND
-(NSInteger)find:(NSString*)key
{
    //results
    NSInteger result = RULE_NOT_FOUND;
    
    //value
    NSNumber* value = nil;
    
    @synchronized(self.rules) {
        
        value = self.rules[key];
        if(value) {
            result = value.boolValue ? RULE_ALLOW : RULE_BLOCK;
        }
    }

    return result;
}

//add (+save) a rule
// note: key is process path
-(BOOL)add:(NSString*)path action:(NSNumber*)action {
    
    os_log_debug(logHandle, "adding rule: %{public}@ -> %{public}@", path, (RULE_ALLOW == action.intValue) ? @"allow" : @"block");
    
    @synchronized(self.rules){
        self.rules[path] = action;
    }
    
    return [self save];
}

//delete (+save) rule
// note: key is process path
-(BOOL)delete:(NSString*)path {
    
    os_log_debug(logHandle, "deleting rule: %{public}@", path);
    
    NSInteger action;
    @synchronized(self.rules) {
        action = [self.rules[path] integerValue];
        [self.rules removeObjectForKey:path];
    }
    
    //reset
    [monitor resetProcess:path action:action];
   
    return [self save];
}

//save to disk
-(BOOL)save {
    
    //rule's file
    NSString* file = [INSTALL_DIRECTORY stringByAppendingPathComponent:RULES_FILE];
    
    @synchronized(self.rules) {
        
        //save
        if(![self.rules writeToFile:file atomically:YES]) {
            os_log_error(logHandle, "ERROR: failed to save rules to: %{public}@", file);
            return NO;
        }
    }
    
    os_log_debug(logHandle, "saved %lu rules to: %{public}@", (unsigned long)self.rules.count, file);
    
    return YES;
}

@end
