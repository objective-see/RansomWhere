//
//  Monitor.m
//  RansomWhere?
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

#import "Event.h"
#import "Rules.h"
#import "Consts.h"
#import "Events.h"
#import "Process.h"
#import "Monitor.h"
#import "Utilities.h"
#import "Preferences.h"

#import "fileChecks.h"

#import <libproc.h>
#import <sys/proc.h>


/* GLOBALS */

//global rules obj
extern Rules* rules;

//global event obj
extern Events* events;

//log handle
extern os_log_t logHandle;

//glboal prefs obj
extern Preferences* preferences;

//endpoint security client
es_client_t* esClient = nil;

@implementation Monitor


//init function
-(id)init {
    
    //init super
    self = [super init];
    if(nil != self) {
        
        //init process cache
        self.processCache = [[NSCache alloc] init];
        [self.processCache setDelegate:self];
        [self.processCache setCountLimit:8192];
        
        
        //init event queue
        self.eventQueue = dispatch_queue_create(BUNDLE_ID, DISPATCH_QUEUE_CONCURRENT);
        
        //interpreters
        self.interpreters = [NSSet setWithArray:@[
            @"com.apple.bash", @"com.apple.zsh", @"com.apple.ksh",
            @"com.apple.tcsh", @"com.apple.sh", @"com.apple.perl",
            @"com.apple.perl5", @"com.apple.ruby", @"com.apple.php",
            @"com.apple.python", @"com.apple.python2", @"com.apple.python3",
            @"com.apple.pythonw", @"com.apple.osascript",
            @"com.tcltk.tclsh", @"org.python.python"
        ]];
    }

    return self;
}

//enable ES monitor
// start ES monitor for file events
-(BOOL)start {
    
    //events of interest
    // process event(s): exec/exit
    // file event(s): close & rename
    es_event_type_t events[] = {ES_EVENT_TYPE_NOTIFY_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT, ES_EVENT_TYPE_NOTIFY_CLOSE, ES_EVENT_TYPE_NOTIFY_RENAME};
    
    //result
    es_new_client_result_t result = 0;
    
    //create client
    // callback invoked on ES events
    result = es_new_client(&esClient, ^(es_client_t *client, const es_message_t *message) {
       
        //callback
        [self handleESMessage:client message:message];
        
    });
    
    //error?
    if(ES_NEW_CLIENT_RESULT_SUCCESS != result) {
        os_log_error(logHandle, "ERROR: es_new_client() failed with %#x", result);
        return FALSE;
    }
    
    //clear cache
    es_clear_cache(esClient);
    
    //mute self
    es_mute_path(esClient, [NSProcessInfo.processInfo.arguments[0] UTF8String], ES_MUTE_PATH_TYPE_LITERAL);
    es_mute_path(esClient, "/Applications/RansomWhere Helper.app/Contents/MacOS/RansomWhere Helper", ES_MUTE_PATH_TYPE_LITERAL);
    
    //mute each currently running processes
    // assumption: no existing ransomware is already running
    for(NSData* tokenData in enumerateProcesses()) {
        
        audit_token_t token;
        [tokenData getBytes:&token length:sizeof(audit_token_t)];
        
        es_mute_process(esClient, &token);
    }
    
    //mute /dev (tty, etc)
    es_mute_path(esClient, "/dev/", ES_MUTE_PATH_TYPE_TARGET_PREFIX);
        
    //subscribe
    if(ES_RETURN_SUCCESS != es_subscribe(esClient, events, sizeof(events)/sizeof(events[0]))) {
        os_log_error(logHandle, "ERROR: es_subscribe() failed");
        return FALSE;
    }
        
    //happy
    return YES;
}

//handle ES message
-(void)handleESMessage:(es_client_t *)client message:(const es_message_t *)message {
    
    //path
    NSString* filePath = nil;

    //key
    // defaults to responsible process
    NSNumber* processKey = @(audit_token_to_pidversion(message->process->audit_token));
    
    //handle ES msg types
    switch (message->event_type) {
            
        //process event: exec
        // init process and, if of interest, cache
        case ES_EVENT_TYPE_NOTIFY_EXEC: {
            
            //os_log_debug(logHandle, "ES event: ES_EVENT_TYPE_NOTIFY_EXEC");
            
            //init process obj
            Process* process = [[Process alloc] initWithES:message];
            if(!process) {
                return;
            }
            
            //cache if of interest?
            // note, also checks rules/sets process's rule result
            if([self processOfInterest:process]) {
                [self.processCache setObject:process forKey:process.pidVersion];
            }
            //not of interest, so mute
            // (unless its xpcproxy, cuz it doesn't do anything but is respawned x 1000)
            else {
                
                if(![process.path isEqualToString:@"/usr/libexec/xpcproxy"]) {
                    es_mute_path(client, process.path.UTF8String, ES_MUTE_PATH_TYPE_LITERAL);
                    os_log_debug(logHandle, "muted %{public}@, as its not of interest", process.name);
                }
            }

            break;
        }
            
        //process event: exit
        // remove from process cache
        case ES_EVENT_TYPE_NOTIFY_EXIT: {
            
            //os_log_debug(logHandle, "ES event: ES_EVENT_TYPE_NOTIFY_EXIT");
            
            NSNumber* exitKey = processKey;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (5 * NSEC_PER_SEC)), self.eventQueue, ^{
                [self.processCache removeObjectForKey:exitKey];
            });
            break;
            
        }
            
        //close event
        // process fs event
        case ES_EVENT_TYPE_NOTIFY_CLOSE: {
            
            //ignore non-modified files
            if(!message->event.close.modified) {
                return;
            }
            
            //TODO: remove
            // and update debug msg
            NSString* path = convertStringToken(&message->process->executable->path);
            os_log_debug(logHandle, "ES event: ES_EVENT_TYPE_NOTIFY_CLOSE (w/ modified) from %{public}@", path);
            
            //extract path
            filePath = convertStringToken(&message->event.close.target->path);
            
            //dispatch
            [self dispatchFSEvent:processKey path:filePath];
            
            break;
        }
            
        //rename event
        // process fs event
        case ES_EVENT_TYPE_NOTIFY_RENAME:
            
            //dbg msg
            //os_log_debug(logHandle, "ES event: ES_EVENT_TYPE_NOTIFY_RENAME");
            
            //path: existing file
            if(ES_DESTINATION_TYPE_EXISTING_FILE == message->event.rename.destination_type) {
                filePath = convertStringToken(&message->event.rename.destination.existing_file->path);
            }
            //path: new file
            else {
                filePath = [convertStringToken(&message->event.rename.destination.new_path.dir->path) stringByAppendingPathComponent:convertStringToken(&message->event.rename.destination.new_path.filename)];
            }
            
            //dispatch
            [self dispatchFSEvent:processKey path:filePath];
            
            break;
            
        default:
            break;
    }
}

//first, see if we care about process
// if so, check rules / ask user if no rule found
-(void)dispatchFSEvent:(NSNumber*)key path:(NSString *)path {
    
    dispatch_async(self.eventQueue, ^{
        
        //sanity check
        if(!path.length) {
            return;
        }
        
        //grab process from cache
        // not found means we don't care about this process
        Process* process = [self.processCache objectForKey:key];
        if(!process) {
            
            //mute
            // likely just 'older' process
            es_mute_path(esClient, path.UTF8String, ES_MUTE_PATH_TYPE_LITERAL);
            
            os_log_debug(logHandle, "muted %{public}@, as its not in process cache", path.lastPathComponent);
        
            return;
        }
        
        //ignore if notarized (or from app store) and that preference is set
        if([preferences.preferences[PREF_NOTARIZATION_MODE] boolValue]) {
            
            if( process.isNotarized ||
                process.signingCategory.intValue == ES_CS_VALIDATION_CATEGORY_APP_STORE )
            {
                os_log_debug(logHandle, "notarization mode set, and process is notarized (or from app store) ...so allowing!");
                return;
            }
            //TODO: remove
            else
            {
                os_log_debug(logHandle, "notarization mode set, but %{public}@ is *not* notarized (nor from app store) ...signing info: %{public}@ / %@", process.path, process.signingInfo, process.signingCategory);
            }
        }
    
        //ignore if alert was shown
        if(process.alertShown) {
            return;
        }
        
        //what does process rule say?
        switch(process.rule) {
            
            //allow
            case RULE_ALLOW:
                os_log_debug(logHandle, "matching (process') rule says, 'allow' ...so allowing!");
                break;
                
            //block
            // kill process
            case RULE_BLOCK:
                
                os_log_debug(logHandle, "matching (process') rule says, 'block', so blocking %{public}@", process.path);
                
                //kill
                if(-1 == kill(process.pid, SIGKILL)) {
                    
                    if(errno != 3) {
                        os_log_error(logHandle, "ERROR: failed to terminate process %{public}@ (errno: %d)", process.path, errno);
                    }
                    
                }
                else {
                    os_log_debug(logHandle, "terminated %{public}@", process.path);
                }
                
                break;
                
            //not found
            // check file, ask user, etc
            case RULE_NOT_FOUND:
            
                //process
                [self handleFSEvent:process path:path];
                
                break;
                
            default:
                break;
        }
    });
}

//async handle file event
// note: to get here, its a process of interest
-(void)handleFSEvent:(Process *)process path:(NSString*)path {
    
    os_log_debug(logHandle, "handling FS event: %{public}@ modified %{public}@", process.name, path);
    
    //file size
    unsigned long long fileSize = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil] fileSize];
    
    //IGNORE: small files
    // entropy calculations don't do well on smaller files
    if(fileSize < 1024) {
        os_log_debug(logHandle, "IGNORING: too small (%llu bytes)", fileSize);
        return;
    }

    //IGNORE: large files
    // ransomware output is typically small; large files just slow us down
    if(fileSize > (50 * 1024 * 1024)) {
        os_log_debug(logHandle, "IGNORING: too large (%llu bytes)", fileSize);
        return;
    }
    
    //IGNORE: non encrypted files
    if(!isEncrypted(path)) {
        os_log_debug(logHandle, "IGNORING: Not encrypted ");
        return;
    }
    
    @synchronized (process) {
        
        //add file
        process.encryptedFiles[path] = [NSDate date];
        
        //TODO: remove
        os_log_debug(logHandle, "file is encrypted, added to process (count: %lu)", process.encryptedFiles.count);
        
        //process hit limit?
        if(![self hitEncryptedThreshold:process]) {
            
            os_log_debug(logHandle, "IGNORING: process threshold not hit");
            return;
        }
        
        //already alerted?
        if(process.alertShown) {
            
            os_log_debug(logHandle, "IGNORING: alert already shown");
            return;
        }
        
        //flag
        process.alertShown = YES;
    }
    
    //process hit limit
    //suspend the process w/ SIGSTOP
    if(-1 == kill(process.pid, SIGSTOP)) {
        
        //err
        os_log_error(logHandle, "ERROR: failed to suspend process %{public}@ (errno: %d)", process.path, errno);
        return;
    }
    
    //dbg msg
    os_log_debug(logHandle, "suspended: %{public}@", process.name);
    
    //event
    Event* event = nil;
    
    //create event
    event = [[Event alloc] init:process];
    
    //deliver alert to user
    // will trigger (other) XPC method to process response
    if(![events deliver:event]) {
        
        //err
        os_log_error(logHandle, "ERROR: failed to deliver alert to user for %{public}@ ...just allowing process", process.path);
        
        //resume
        kill(process.pid, SIGCONT);
    }
    
    return;
}

//process rapidly creating encrypted files?
-(BOOL)hitEncryptedThreshold:(Process*)process {
    
    //prune files older than 30 seconds
    [process.encryptedFiles removeObjectsForKeys:[process.encryptedFiles keysOfEntriesPassingTest:^BOOL(NSString* path, NSDate* timestamp, BOOL* stop) {
        return [timestamp timeIntervalSinceNow] < -30;
    }].allObjects];
    
    //now check encrypted file count
    return (process.encryptedFiles.count >= 5);
}

//stop
// and cleanup
-(BOOL)stop {
    
    if(!esClient) {
        return NO;
    }
    
    //unsubscribe
    if(ES_RETURN_SUCCESS != es_unsubscribe_all(esClient)) {
        os_log_error(logHandle, "ERROR: es_unsubscribe_all() failed");
        return NO;
    }
    
    //delete client
    if(ES_RETURN_SUCCESS != es_delete_client(esClient)) {
        os_log_error(logHandle, "ERROR: es_delete_client() failed");
        return NO;
    }
    
    //unset
    esClient = nil;
    
    //clear process cache
    [self.processCache removeAllObjects];

    return YES;
}

//is process of interest?
// no if allowed by rule, or platform binary (unless interpreter)
-(BOOL)processOfInterest:(Process*)process {
    
    //first set (any) rules
    process.rule = [rules find:process.path];
    
    //already allowed?
    if(RULE_ALLOW == process.rule) {
        os_log_debug(logHandle, "%{public}@, has 'RULE_ALLOW' set", process.name);
        return NO;
    }
    
    //already blocked?
    if(RULE_BLOCK == process.rule) {
        os_log_debug(logHandle, "%{public}@, has 'RULE_BLOCK' set", process.name);
        return YES;
    }
    
    //platform binary?
    if(process.isPlatformBinary) {
            
        //interpreter? still of interest
        // e.g. python, osascript, bash could run malicious scripts
        if([self.interpreters containsObject:process.signingID]) {
            return YES;
        }
        
        os_log_debug(logHandle, "%{public}@, is platform binary (and not interpreter)", process.name);
        
        //otherwise, not of interest
        return NO;
    }
    
    //everything else is of interest
    // unsigned, third-party, ad hoc signed, etc.
    return YES;
}

//invoked when a rule is deleted
// need to reset process in cache
-(void)resetProcess:(NSString*)path action:(NSInteger)action {
    
    //check all running processes
    for(NSData* tokenData in enumerateProcesses()) {
        
        audit_token_t token;
        [tokenData getBytes:&token length:sizeof(audit_token_t)];
        
        NSNumber* key = @(audit_token_to_pidversion(token));
        
        Process* process = [self.processCache objectForKey:key];
        if(!process) continue;
        
        //match rule's path?
        // reset proc rule, etc.
        if([process.path isEqualToString:path]) {
            
            os_log_debug(logHandle, "reset cached process %{public}@", path);
            
            process.rule = RULE_NOT_FOUND;
            process.alertShown = NO;
        }
    }
}

//handle response
// kill or resume process, create rule, etc
-(void)handleResponse:(NSDictionary*)alert {
    
    NSNumber* action = alert[ALERT_ACTION];
    NSString* processPath = alert[ALERT_PROCESS_PATH];
    
    //get process
    Process* process = [self.processCache objectForKey:alert[ALERT_PROCESS_PID_VERSION]];
    
    //first create rule
    if([alert[ALERT_CREATE_RULE] boolValue]) {
        [rules add:processPath action:action];
    }
    
    //now check process in cache?
    if(!process) {
        os_log_error(logHandle, "ERROR: process not found in cache, maybe already exited?");
        return;
    }
    
    //update process's rule
    process.rule = action.integerValue;
    
    //block?
    if(RULE_BLOCK == action.integerValue) {
        
        //log msg
        os_log(logHandle, "user says, 'block', so blocking %{public}@", processPath);
        
        //kill
        if(-1 == kill(process.pid, SIGKILL)) {
            if(errno != 3) {
                os_log_error(logHandle, "ERROR: failed to terminate process %{public}@ (errno: %d)", process.path, errno);
            }
        }
    }
    //allow
    else
    {
        //log msg
        os_log(logHandle, "user says, 'allow', so allowing %{public}@", processPath);
        
        //resume
        if(-1 == kill(process.pid, SIGCONT)) {
            os_log_error(logHandle, "ERROR: failed to resume process %{public}@ (errno: %d)", process.path, errno);
        }
    }
}

//called when cache is about to evict a process
// if process is suspended, as we're about to "lose it", resume it
-(void)cache:(NSCache *)cache willEvictObject:(id)obj {
    
    //cast
    Process* process = (Process*)obj;
    
    struct proc_bsdinfo info;
    if(proc_pidinfo(process.pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) > 0) {
        
        //suspended (SSTOP)?
        if(SSTOP == info.pbi_status) {
            
            os_log_debug(logHandle, "WARNING: cache evicting suspended process %{public}@ (pid: %d) — resuming to avoid orphan", process.path, process.pid);
            
            //resume
            kill(process.pid, SIGCONT);
        }
    }
}

@end
