//
//  Process.m
//  FileMonitor
//
//  Created by Patrick Wardle on 9/1/19.
//  Copyright © 2020 Objective-See. All rights reserved.
//


#import <dlfcn.h>
#import <libproc.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>

#import "consts.h"
#import "Process.h"
#import "signing.h"
#import "utilities.h"


//pointer to function
// responsibility_get_pid_responsible_for_pid
pid_t (* _Nullable getRPID)(pid_t pid) = NULL;


/* FUNCTIONS */

@implementation Process

@synthesize pid;
@synthesize exit;
@synthesize path;
@synthesize ppid;
@synthesize event;
@synthesize script;
@synthesize ancestors;
@synthesize arguments;
@synthesize auditToken;
@synthesize signingInfo;

//init w/ ES message
-(id)init:(const es_message_t *)message {
    
    //sanity check
    if(ES_EVENT_TYPE_NOTIFY_EXEC != message->event_type) {
        return nil;
    }
    
    //init super
    self = [super init];
    if(nil != self)
    {
        //code ref
        SecCodeRef codeRef = NULL;
        
        //process from msg
        es_process_t* process = NULL;
        
        //init
        self.rule = RULE_NOT_FOUND;
        
        //alloc array for args
        self.arguments = [NSMutableArray array];
        
        //alloc array for parents
        self.ancestors = [NSMutableArray array];
        
        //alloc dictionary for signing info
        self.signingInfo = [NSMutableDictionary dictionary];
        
        //alloc dictionary encrypted file
        self.encryptedFiles = [NSMutableDictionary dictionary];
        
        //set process (target)
        process = message->event.exec.target;
        
        //pid version
        self.pidVersion = @(audit_token_to_pidversion(process->audit_token));
        
        //init exit
        self.exit = -1;
        
        //init event
        self.event = -1;
        
        //set type
        self.event = message->event_type;
        
        //extract/format args
        [self extractArgs:&message->event];
                
        //init audit token
        self.auditToken = [NSData dataWithBytes:&process->audit_token length:sizeof(audit_token_t)];
        
        //now get code ref via audit token
        SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit:self.auditToken}), kSecCSDefaultFlags, &codeRef);
        
        //init pid
        self.pid = audit_token_to_pid(process->audit_token);
        
        //init ppid
        self.ppid = process->ppid;
        
        //init rpid
        if(message->version >= 4) {
            self.rpid = audit_token_to_pid(process->responsible_audit_token);
        }
        
        //add cs flags
        self.csFlags = [NSNumber numberWithUnsignedInt:process->codesigning_flags];
        
        //path
        self.path = convertStringToken(&process->executable->path);
        
        //now, get name
        self.name = [self getName];
        
        //signing ID
        self.signingID = convertStringToken(&process->signing_id);

        //team ID
        self.teamID = convertStringToken(&process->team_id);
        
        //cs_validation_category (macOS 26 / es version 10+)
        if(message->version >= 10) {
            self.signingCategory = @(process->cs_validation_category);
        }
        //set signer manaually
        else {
            if(codeRef) {
                self.signingCategory = extractSigner(codeRef, self.csFlags);
            }
        }
        
        //add platform binary
        self.isPlatformBinary = process->is_platform_binary;
        
        //3rd-party
        // check if notarized
        if(!self.isPlatformBinary) {
            //check
            if(codeRef) {
                self.isNotarized = isNotarized(codeRef, self.csFlags.intValue);
            }
        }
        
        //script
        if( (message->version >= 2) &&
            (ES_EVENT_TYPE_NOTIFY_EXEC == message->event_type) ) {
            
            //save
            if(message->event.exec.script != NULL) {
                self.script = convertStringToken(&message->event.exec.script->path);
            }
        }
    
        //enumerate ancestors
        [self enumerateAncestors];
        
        if(codeRef) {
            CFRelease(codeRef);
        }
    }

    return self;
}


//get process' name
// either via app bundle, or path
-(NSString*)getName
{
    //name
    NSString* name = nil;
    
    //app path
    NSString* appPath = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //convert path to app path
    // generally, <blah.app>/Contents/MacOS/blah
    appPath = [[[self.path stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    if(YES != [appPath hasSuffix:@".app"])
    {
        //bail
        goto bail;
    }
    
    //try load bundle
    // and verify it's the 'right' bundle
    appBundle = [NSBundle bundleWithPath:appPath];
    if( (nil != appBundle) &&
        (YES == [appBundle.executablePath isEqualToString:self.path]) )
    {
        //grab name from app's bundle
        name = [appBundle infoDictionary][@"CFBundleDisplayName"];
    }
    
bail:
    
    //still nil?
    // just grab from path
    if(nil == name)
    {
        //from path
        name = [self.path lastPathComponent];
    }
    
    return name;
}

//extract/format args
-(void)extractArgs:(const es_events_t *)event
{
    //number of args
    uint32_t count = 0;
    
    //argument
    NSString* argument = nil;
    
    //get # of args
    count = es_exec_arg_count(&event->exec);
    if(0 == count)
    {
        //bail
        goto bail;
    }
    
    //extract all args
    for(uint32_t i = 0; i < count; i++)
    {
        //current arg
        es_string_token_t currentArg = {0};
        
        //extract current arg
        currentArg = es_exec_arg(&event->exec, i);
        
        //convert argument
        argument = convertStringToken(&currentArg);
        if(nil != argument)
        {
            //append
            [self.arguments addObject:argument];
        }
    }
    
bail:
    
    return;
}

//generate list of ancestors
// note: if possible, built off responsible pid (vs. parent)
-(void)enumerateAncestors
{
    //current process id
    pid_t currentPID = -1;
    
    //parent pid
    pid_t parentPID = -1;

    //have rpid (from ESF)
    // init parent w/ that
    if(0 != self.rpid)
    {
        parentPID = self.rpid;
    }
    //no rpid
    // try lookup via private API
    else if(NULL != getRPID)
    {
        //get rpid
        parentPID = getRPID(pid);
    }
    
    //couldn't find/get rPID?
    // default back to using ppid
    if( (parentPID <= 0) ||
        (self.pid == parentPID) )
    {
        //use ppid
        parentPID = self.ppid;
    }
    
    //add parent
    [self.ancestors addObject:[NSNumber numberWithInt:parentPID]];
        
    //set current to parent
    currentPID = parentPID;
    
    //complete ancestry
    while(YES)
    {
        //for parent
        // first try via rPID
        if(NULL != getRPID)
        {
            //get rpid
            parentPID = getRPID(currentPID);
        }
        
        //couldn't find/get rPID?
        // default back to using standard method
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //get parent pid
            parentPID = getParentID(currentPID);
        }
        
        //done?
        if( (parentPID <= 0) ||
            (currentPID == parentPID) )
        {
            //bail
            break;
        }
        
        //update
        currentPID = parentPID;
        
        //add
        [self.ancestors addObject:[NSNumber numberWithInt:parentPID]];
    }
    
    return;
}

@end
