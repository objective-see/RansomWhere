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

//hash length
// from: cs_blobs.h
#define CS_CDHASH_LEN 20

//pointer to function
// responsibility_get_pid_responsible_for_pid
pid_t (* _Nullable getRPID)(pid_t pid) = NULL;

/* GLOBALS */


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
@synthesize architecture;

//init with audit token
-(id)initWithToken:(audit_token_t)token {
    
    //init super
    self = [super init];
    if(nil != self)
    {
        
        //init
        self.rule = RULE_NOT_FOUND;
        
        self.arguments = [NSMutableArray array];
        self.ancestors = [NSMutableArray array];
        self.signingInfo = [NSMutableDictionary dictionary];
        self.encryptedFiles = [NSMutableDictionary dictionary];
        
        //pid version
        self.pidVersion = @(audit_token_to_pidversion(token));
        
        //init audit token
        self.auditToken = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
        
        //init pid
        self.pid = audit_token_to_pid(token);
        
        //init ppid
        self.ppid = getParentID(self.pid);
        
        //path
        self.path = getProcessPath(self.pid);
        
        //now, get name
        self.name = [self getName];
        
        //generate signing info
        self.signingInfo = generateSigningInfo(self, csDynamic, kSecCSDefaultFlags);
        
        if(noErr == [self.signingInfo[KEY_SIGNATURE_STATUS] intValue]) {
         
            self.signingID = self.signingInfo[KEY_SIGNATURE_IDENTIFIER];
            self.teamID = self.signingInfo[KEY_SIGNATURE_TEAM_IDENTIFIER];
            
            if(Apple == [self.signingInfo[KEY_SIGNATURE_SIGNER] intValue]) {
                self.isPlatformBinary = @(YES);
            }
        }
       
        //enumerate ancestors
        [self enumerateAncestors];
    }
    
    
    return self;
    
}


//init w/ ES message
-(id)initWithES:(const es_message_t *)message {

    //process from msg
    es_process_t* process = NULL;
    
    //init super
    self = [super init];
    if(nil != self)
    {
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
        
        //pid version
        if(message->event_type == ES_EVENT_TYPE_NOTIFY_EXEC) {
            //new process
            self.pidVersion = @(audit_token_to_pidversion(message->event.exec.target->audit_token));
        }
        else {
            //responsible process
            self.pidVersion = @(audit_token_to_pidversion(message->process->audit_token));
        }
        
        //init exit
        self.exit = -1;
        
        //init event
        self.event = -1;
        
        //set type
        self.event = message->event_type;
        
        //event specific logic
        
        // set type
        // extract (relevant) process object, etc
        switch (message->event_type) {
            
            //exec
            case ES_EVENT_TYPE_AUTH_EXEC:
            case ES_EVENT_TYPE_NOTIFY_EXEC:
                
                //set process (target)
                process = message->event.exec.target;
                
                //extract/format args
                [self extractArgs:&message->event];
                
                break;
                
            //fork
            case ES_EVENT_TYPE_NOTIFY_FORK:
                
                //set process (child)
                process = message->event.fork.child;
                
                break;
                
            //exit
            case ES_EVENT_TYPE_NOTIFY_EXIT:
                
                //set process
                process = message->process;
                
                //set exit code
                self.exit = message->event.exit.stat;
                
                break;
            
            //default
            default:
                
                //set process
                process = message->process;
                
                break;
        }
        
        //init audit token
        self.auditToken = [NSData dataWithBytes:&process->audit_token length:sizeof(audit_token_t)];
        
        //init pid
        self.pid = audit_token_to_pid(process->audit_token);
        
        //init ppid
        self.ppid = process->ppid;
        
        //init rpid
        if(message->version >= 4) 
        {
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
        
        //add platform binary
        self.isPlatformBinary = [NSNumber numberWithBool:process->is_platform_binary];
        
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
    }
    
    return self;
}

//get's process' path
// note: path must be set
-(unsigned long)inode
{
    //stat
    struct stat fileStat = {0};
    
    //inode
    unsigned long iNode = 0;
    
    //stat
    if(0 == stat(self.path.fileSystemRepresentation, &fileStat))
    {
        //save
        iNode = fileStat.st_ino;
    }
  
    return iNode;
}

//generate code signing info
// sets 'signingInfo' iVar
-(void)generateCSInfo:(NSUInteger)csOption
{
    //generate via helper function
    self.signingInfo = generateSigningInfo(self, csOption, kSecCSDefaultFlags);
    
    return;
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

//get process' architecture
-(NSUInteger)getArchitecture
{
    //architecuture
    NSUInteger architecture = ArchUnknown;
    
    //type
    cpu_type_t type = -1;
    
    //size
    size_t size = 0;
    
    //mib
    int mib[CTL_MAXNAME] = {0};
    
    //length
    size_t length = CTL_MAXNAME;
    
    //proc info
    struct kinfo_proc procInfo = {0};
    
    //get mib for 'proc_cputype'
    if(noErr != sysctlnametomib("sysctl.proc_cputype", mib, &length))
    {
        //bail
        goto bail;
    }
    
    //add pid
    mib[length] = self.pid;
    
    //inc length
    length++;
    
    //init size
    size = sizeof(cpu_type_t);
    
    //get CPU type
    if(noErr != sysctl(mib, (u_int)length, &type, &size, 0, 0))
    {
        //bail
        goto bail;
    }
    
    //reversing Activity Monitor
    // if CPU type is CPU_TYPE_X86_64, Apple sets architecture to 'Intel'
    if(CPU_TYPE_X86_64 == type)
    {
        //intel
        architecture = ArchIntel;
        
        //done
        goto bail;
    }
    
    //reversing Activity Monitor
    // if CPU type is CPU_TYPE_ARM64, Apple checks proc's p_flags
    // if P_TRANSLATED is set, then they set architecture to 'Intel'
    if(CPU_TYPE_ARM64 == type)
    {
        //default to apple
        architecture = ArchAppleSilicon;
        
        //(re)init mib
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROC;
        mib[2] = KERN_PROC_PID;
        mib[3] = pid;
        
        //(re)set length
        length = 4;
        
        //(re)set size
        size = sizeof(procInfo);
        
        //get proc info
        if(noErr != sysctl(mib, (u_int)length, &procInfo, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //'P_TRANSLATED' set?
        // set architecture to 'Intel'
        if(P_TRANSLATED == (P_TRANSLATED & procInfo.kp_proc.p_flag))
        {
            //intel
            architecture = ArchIntel;
        }
    }
    
bail:
    
    return architecture;
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

//for pretty printing
// though we convert to JSON
-(NSString *)description
{
    //description
    NSMutableString* description = nil;
    
    //cd hash
    // requires formatting
    NSMutableString* cdHash = nil;

    //init output string
    description = [NSMutableString string];

    //start process
    [description appendString:@"\"process\":{"];
       
    //add pid, path, etc
    [description appendFormat: @"\"pid\":%d,\"name\":\"%@\",\"path\":\"%@\"",self.pid, self.name, self.path];
   
    //add cpu type
    switch(self.architecture)
    {
        //intel
        case ArchIntel:
            [description appendFormat: @"\"architecture\":\"Intel\","];
            break;
        
        //apple
        case ArchAppleSilicon:
            [description appendFormat: @"\"architecture\":\"Apple Silicon\","];
            break;

        //unknown
        default:
            [description appendString:@"\"architecture\":\"unknown\","];
            break;
    }
    
    //arguments
    if(0 != self.arguments.count)
    {
       //start list
       [description appendFormat:@"\"arguments\":["];
       
       //add all arguments
       for(NSString* argument in self.arguments)
       {
           //skip blank args
           if(0 == argument.length) continue;
           
           //add
           [description appendFormat:@"\"%@\",", [argument stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
       }
       
       //remove last ','
       if(YES == [description hasSuffix:@","])
       {
           //remove
           [description deleteCharactersInRange:NSMakeRange([description length]-1, 1)];
       }
       
       //terminate list
       [description appendString:@"],"];
    }
    //no args
    else
    {
       //add empty list
       [description appendFormat:@"\"arguments\":[],"];
    }

    //add ppid
    [description appendFormat: @"\"ppid\":%d,", self.ppid];
    
    //add rpdi
    [description appendFormat: @"\"rpid\":%d,", self.rpid];

    //add ancestors
    [description appendFormat:@"\"ancestors\":["];

    //add each ancestor
    for(NSNumber* ancestor in self.ancestors)
    {
       //add
       [description appendFormat:@"%d,", ancestor.unsignedIntValue];
    }

    //remove last ','
    if(YES == [description hasSuffix:@","])
    {
       //remove
       [description deleteCharactersInRange:NSMakeRange([description length]-1, 1)];
    }

    //terminate list
    [description appendString:@"],"];

    //signing info (reported)
    [description appendString:@"\"signing info (reported)\":{"];
    
    //add cs flags, platform binary
    [description appendFormat: @"\"csFlags\":%d,\"platformBinary\":%d,", self.csFlags.intValue, self.isPlatformBinary.intValue];
    
    //add signing id
    if(0 == self.signingID.length)
    {
        //blank
        [description appendString:@"\"signingID\":\"\","];
    }
    //not blank
    else
    {
        //append
        [description appendFormat:@"\"signingID\":\"%@\",", self.signingID];
    }
    
    //add team id
    if(0 == self.teamID.length)
    {
        //blank
        [description appendString:@"\"teamID\":\"\","];
    }
    //not blank
    else
    {
        //append
        [description appendFormat:@"\"teamID\":\"%@\",", self.teamID];
    }
    
    //alloc string for cd hash
    cdHash = [NSMutableString string];
    
    //format cd hash
    [self.cdHash enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop)
    {
        //To print raw byte values as hex
        for (NSUInteger i = 0; i < byteRange.length; ++i) {
            [cdHash appendFormat:@"%02X", ((uint8_t*)bytes)[i]];
        }
    }];
    
    //add cs hash
    [description appendFormat:@"\"cdHash\":\"%@\"", cdHash];
    
    //terminate dictionary
    [description appendString:@"},"];

    //signing info
    [description appendString:@"\"signing info (computed)\":{"];

    //add all key/value pairs from signing info
    for(NSString* key in self.signingInfo)
    {
       //value
       id value = self.signingInfo[key];
       
       //handle `KEY_SIGNATURE_SIGNER`
       if(YES == [key isEqualToString:KEY_SIGNATURE_SIGNER])
       {
           //convert to pritable
           switch ([value intValue]) {
           
               //'None'
               case None:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"none"];
                   break;
                   
               //'Apple'
               case Apple:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"Apple"];
                   break;
               
               //'App Store'
               case AppStore:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"App Store"];
                   break;
                   
               //'Developer ID'
               case DevID:
                   [description appendFormat:@"\"%@\":\"%@\",", key, @"Developer ID"];
                   break;

               //'AdHoc'
               case AdHoc:
                  [description appendFormat:@"\"%@\":\"%@\",", key, @"AdHoc"];
                  break;
                   
               default:
                   break;
           }
       }
       
       //number?
       // add as is
       else if(YES == [value isKindOfClass:[NSNumber class]])
       {
           //add
           [description appendFormat:@"\"%@\":%@,", key, value];
       }
       //array
       else if(YES == [value isKindOfClass:[NSArray class]])
       {
           //start
           [description appendFormat:@"\"%@\":[", key];
           
           //add each item
           [value enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL * _Nonnull stop) {
               
               //add
               [description appendFormat:@"\"%@\"", obj];
               
               //add ','
               if(index != ((NSArray*)value).count-1)
               {
                   //add
                   [description appendString:@","];
               }
               
           }];
           
           //terminate
           [description appendString:@"],"];
       }
       //otherwise
       // just escape it
       else
       {
           //add
           [description appendFormat:@"\"%@\":\"%@\",", key, value];
       }
    }

    //remove last ','
    if(YES == [description hasSuffix:@","])
    {
      //remove
      [description deleteCharactersInRange:NSMakeRange([description length]-1, 1)];
    }

    //terminate dictionary
    [description appendString:@"}"];

    //exit event?
    // add exit code
    if(ES_EVENT_TYPE_NOTIFY_EXIT == self.event)
    {
       //add exit
       [description appendFormat:@",\"exit code\":%d", self.exit];
    }

    //terminate process
    [description appendString:@"}"];

    return description;
}

@end

