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

        //migrate any non-canonical keys
        // (rules saved before path normalization was added)
        NSMutableDictionary* migrated = [NSMutableDictionary dictionary];
        BOOL changed = NO;
        for(NSString* key in loadedRules) {
            NSString* canon = [[key stringByStandardizingPath] stringByResolvingSymlinksInPath];
            if(![canon isEqualToString:key]) {
                changed = YES;
            }
            migrated[canon] = loadedRules[key];
        }
        self.rules = migrated;

        //persist migration if anything changed
        if(changed) {
            [self save];
        }
    }

    //dbg msg
    os_log_debug(logHandle, "loaded %lu rules from: %{public}@", (unsigned long)self.rules.count, file);

    return YES;
}

//find rule
// note: key is process path (canonicalized)
// returns RULE_ALLOW, RULE_BLOCK, or RULE_NOT_FOUND
-(NSInteger)find:(NSString*)key
{
    //results
    NSInteger result = RULE_NOT_FOUND;

    //value
    NSNumber* value = nil;

    NSString* canon = [[key stringByStandardizingPath] stringByResolvingSymlinksInPath];

    @synchronized(self.rules) {

        value = self.rules[canon];
        if(value) {
            result = value.boolValue ? RULE_ALLOW : RULE_BLOCK;
        }
    }

    return result;
}

//add (+save) a rule
// note: key is process path (canonicalized)
-(BOOL)add:(NSString*)path action:(NSNumber*)action {

    NSString* canon = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];

    os_log_debug(logHandle, "adding rule: %{public}@ -> %{public}@", canon, (RULE_ALLOW == action.intValue) ? @"allow" : @"block");

    @synchronized(self.rules){
        self.rules[canon] = action;
    }

    return [self save];
}

//delete (+save) rule
// note: key is process path (canonicalized)
-(BOOL)delete:(NSString*)path {

    NSString* canon = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];

    os_log_debug(logHandle, "deleting rule: %{public}@", canon);

    @synchronized(self.rules) {
        [self.rules removeObjectForKey:canon];
    }

    //reset
    [monitor resetProcess:canon];

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
