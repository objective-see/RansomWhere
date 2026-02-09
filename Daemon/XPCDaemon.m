//
//  file: XPCDaemon.m
//  project: RansomWhere? (launch daemon)
//  description: interface for XPC methods, invoked by user
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Event.h"
#import "Rules.h"
#import "Events.h"
#import "consts.h"
#import "Monitor.h"
#import "XPCDaemon.h"
#import "utilities.h"
#import "Preferences.h"

/* GLOBALS */

//global rules obj
extern Rules* rules;

//global events obj
extern Events* events;

//global monitor obj
extern Monitor* monitor;

//log handle
extern os_log_t logHandle;

//global prefs obj
extern Preferences* preferences;

@implementation XPCDaemon

//load preferences and send them back to client
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply {
    
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //reply
    reply(preferences.preferences);
    
}

//update preferences
-(void)updatePreferences:(NSDictionary *)updates {
    
    os_log_debug(logHandle, "XPC request: '%s' (%{public}@)", __PRETTY_FUNCTION__, updates);
    
    //update
    if(YES != [preferences update:updates]) {
        os_log_error(logHandle, "ERROR: failed to updates to preferences");
    }
}

//get rules
-(void)getRules:(void (^)(NSDictionary*))reply {
    
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
        
    //reply w/ rules
    @synchronized(rules.rules) {
        reply([rules.rules copy]);
    }
}

//delete rule
-(void)deleteRule:(NSString*)key {
    
    os_log_debug(logHandle, "XPC request: '%s' (rule: %{public}@)", __PRETTY_FUNCTION__, key);
    
    //remove row
    if(YES != [rules delete:key]) {
        os_log_error(logHandle, "ERROR: failed to delete rule, %{public}@", key);
    }
}

//handle client response to alert
-(void)alertReply:(NSDictionary*)alert {

    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);
    
    //process
    [monitor handleResponse:alert];

}

//quit
-(void)quit {
    
    os_log_debug(logHandle, "XPC request: '%s'", __PRETTY_FUNCTION__);

    //stop monitor
    [monitor stop];
    
    os_log_debug(logHandle, "monitor stopped ...now exiting");
    
    //bye
    exit(0);
}

@end
