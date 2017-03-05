//
//  ProcMonitor.m
//  RansomWhere
//
//  Created by Patrick Wardle on 2/22/17.
//  Copyright (c) Objective-See. All rights reserved.
//

#import "main.h"
#import "Event.h"
#import "Consts.h"
#import "Logging.h"
#import "Process.h"
#import "Utilities.h"
#import "ProcMonitor.h"

#import <libproc.h>
#import <sys/ioctl.h>
#import <bsm/audit.h>
#import <bsm/libbsm.h>
#import <Cocoa/Cocoa.h>
#import <bsm/audit_kevents.h>
#import <Foundation/Foundation.h>
#import <security/audit/audit_ioctl.h>

@implementation ProcMonitor

@synthesize processes;

//init function
// ->load watch paths, alloc queue, etc
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc/init dictionary for all procs
        processes = [NSMutableDictionary dictionary];
    }
    
    return self;
}

//generate process objects for all runnings procs
-(void)enumerateRunningProcesses
{
    //running processes
    NSMutableArray* runningProcesses = nil;
    
    //process object
    Process* process = nil;
    
    //process path
    NSString* processPath = nil;
    
    //get list of pids, of all running processes
    runningProcesses = enumerateProcesses();
    if( (nil == runningProcesses) ||
        (0 == runningProcesses.count) )
    {
        //err msg
        logMsg(LOG_ERR, @"failed to enumerate running processes");
        
        //bail
        goto bail;
    }
    
    //iterate over all running processes
    // ->get path and save into list of binaries to process
    for(NSNumber* processID in runningProcesses)
    {
        //get process path from pid
        processPath = getProcessPath(processID.unsignedIntValue);
        if(nil == processPath)
        {
            //skip
            continue;
        }
        
        //create a new process
        process = [[Process alloc] init];
        
        //set pid
        process.pid = processID.intValue;
        
        //set path
        process.path = processPath;
        
        //process
        [self handleNewProcess:process];
    }
    
//bail
bail:
    
    return;
}

//monitor for new process events
-(void)monitor
{
    //event mask
    // ->what event classes to watch for
    u_int eventClasses = AUDIT_CLASS_EXEC | AUDIT_CLASS_PROCESS;
    
    //file pointer to audit pipe
    FILE* auditFile = NULL;
    
    //file descriptor for audit pipe
    int auditFileDescriptor = -1;
    
    //status var
    int status = -1;
    
    //preselect mode
    int mode = -1;
    
    //queue length
    int maxQueueLength = -1;
    
    //record buffer
    u_char* recordBuffer = NULL;
    
    //token struct
    tokenstr_t tokenStruct = {0};
    
    //total length of record
    int recordLength = -1;
    
    //amount of record left to process
    int recordBalance = -1;
    
    //amount currently processed
    int processedLength = -1;
    
    //process record obj
    Process* process = nil;
    
    //last fork
    Process* lastFork = nil;
    
    //process path
    NSString* processPath = nil;
    
    //open audit pipe for reading
    auditFile = fopen(AUDIT_PIPE, "r");
    if(auditFile == NULL)
    {
        //TODO: errors, here and below!
        
        //err msg
        
        //bail
        goto bail;
    }
    
    //grab file descriptor
    auditFileDescriptor = fileno(auditFile);
    
    //init mode
    mode = AUDITPIPE_PRESELECT_MODE_LOCAL;
    
    //set preselect mode
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_PRESELECT_MODE, &mode);
    if(-1 == status)
    {
        //bail
        //goto bail;
    }
    
    //grab max queue length
    status = ioctl(auditFileDescriptor, AUDITPIPE_GET_QLIMIT_MAX, &maxQueueLength);
    if(-1 == status)
    {
        //bail
        //goto bail;
    }
    
    //set queue length to max
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_QLIMIT, &maxQueueLength);
    if(-1 == status)
    {
        //bail
        //goto bail;
    }
    
    //set preselect flags
    // ->event classes we're interested in
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_PRESELECT_FLAGS, &eventClasses);
    if(-1 == status)
    {
        //bail
        //goto bail;
    }
    
    //set non-attributable flags
    // ->event classes we're interested in
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_PRESELECT_NAFLAGS, &eventClasses);
    if(-1 == status)
    {
        //bail
        //goto bail;
    }
    
    //forever
    // ->read/parse/process audit records
    while(YES)
    {
        //reset process record object
        process = nil;
        
        //free prev buffer
        if(NULL != recordBuffer)
        {
            //free
            free(recordBuffer);
            
            //unset
            recordBuffer = NULL;
        }
        
        //read a single audit record
        // ->note: buffer is allocated by function, so must be freed when done
        recordLength = au_read_rec(auditFile, &recordBuffer);
        
        //sanity check
        if(-1 == recordLength)
        {
            //continue
            continue;
        }
        
        //init (remaining) balance to record's total length
        recordBalance = recordLength;
        
        //init processed length to start (zer0)
        processedLength = 0;
        
        //parse record
        // ->read all tokens/process
        while(0 != recordBalance)
        {
            //extract token
            // ->and sanity check
            if(-1  == au_fetch_tok(&tokenStruct, recordBuffer + processedLength, recordBalance))
            {
                //error
                // ->skip record
                break;
            }
            
            //ignore records that aren't related to process exec'ing/spawning
            // ->gotta wait till we hit/capture a AUT_HEADER* though, as this has the event type
            if( (nil != process) &&
                (YES != [self shouldProcessRecord:process.type]) )
            {
                //bail
                // ->skips reset of record
                break;
            }
            
            
            //process token(s)
            // ->create Process object, etc
            switch(tokenStruct.id)
            {
                //handle start of record
                // ->grab event type, allowing to ignore events not of interest
                case AUT_HEADER32:
                case AUT_HEADER32_EX:
                case AUT_HEADER64:
                case AUT_HEADER64_EX:
                {
                    //create a new process
                    process = [[Process alloc] init];
                    
                    //save type
                    process.type = tokenStruct.tt.hdr32.e_type;
                    
                    break;
                }
                    
                //path
                // ->note: this might be updated/replaced later (if it's '/dev/null', etc)
                case AUT_PATH:
                {
                    //save path
                    process.path = [NSString stringWithUTF8String:tokenStruct.tt.path.path];
                    
                    break;
                }
                    
                //subject
                // ->extract/save pid || ppid
                //   all these cases can be treated as subj32 cuz only accessing initial members
                case AUT_SUBJECT32:
                case AUT_SUBJECT32_EX:
                case AUT_SUBJECT64:
                case AUT_SUBJECT64_EX:
                {
                    //SPAWN (pid/ppid)
                    //  ->if there was an AUT_ARG32 (which always come first), that's the pid! so this will be the ppid
                    if(AUE_POSIX_SPAWN == process.type)
                    {
                        //no AUT_ARG32?
                        // ->set as pid, and try manually to get ppid
                        if(0 == process.pid)
                        {
                            //set pid
                            process.pid = tokenStruct.tt.subj32.pid;
                            
                            //manually get parent
                            process.ppid = getParentID(process.pid);
                        }
                        //pid already set (via AUT_ARG32)
                        // ->this then, is the ppid
                        else
                        {
                            //set ppid
                            process.ppid = tokenStruct.tt.subj32.pid;
                        }
                    }
                    
                    //FORK
                    // ->ppid (pid is in AUT_ARG32)
                    else if(AUE_FORK == process.type)
                    {
                        //set ppid
                        process.ppid = tokenStruct.tt.subj32.pid;
                    }
                    
                    //AUE_EXEC/VE
                    // ->this is the pid
                    else
                    {
                        //save pid
                        process.pid = tokenStruct.tt.subj32.pid;
                        
                        //manually get parent
                        process.ppid = getParentID(process.pid);
                        
                    }
                    
                    break;
                }
                    
                    
                //args
                // ->SPAWN/FORK this is pid
                case AUT_ARG32:
                case AUT_ARG64:
                {
                    //save pid
                    if( (AUE_POSIX_SPAWN == process.type) ||
                       (AUE_FORK == process.type) )
                    {
                        //32bit
                        if(AUT_ARG32 == tokenStruct.id)
                        {
                            //save
                            process.pid = tokenStruct.tt.arg32.val;
                        }
                        //64bit
                        else
                        {
                            //save
                            process.pid = (pid_t)tokenStruct.tt.arg64.val;
                        }
                    }
                    
                    //FORK
                    // ->doesn't have token for path, so try manually find it now
                    if(AUE_FORK == process.type)
                    {
                        //save path
                        process.path = getProcessPath(process.pid);
                    }
                    
                    break;
                }
                    
                //exec args
                // ->just save into args (processed later, well args[0], if path wasn't found)
                case AUT_EXEC_ARGS:
                {
                    //save args
                    for(int i = 0; i<tokenStruct.tt.execarg.count; i++)
                    {
                        //add
                        [process.arguments addObject:[NSString stringWithUTF8String:tokenStruct.tt.execarg.text[i]]];
                    }
                    
                    break;
                }
                    
                //record trailer
                // ->end/save, etc
                case AUT_TRAILER:
                {
                    //end
                    if( (nil != process) &&
                        (YES == [self shouldProcessRecord:process.type]) )
                    {
                        //try get process path
                        // ->this is the most 'trusted way' (since exec_args can change)
                        processPath = getProcessPath(process.pid);
                        if(nil != processPath)
                        {
                            //save
                            process.path = getProcessPath(process.pid);
                        }
                        
                        //failed to get path at runtime
                        // ->if 'AUT_PATH' was something like '/dev/null' or '/dev/console' use arg[0]...yes this can be spoofed :/
                        else if( (nil == processPath) &&
                                 (0 != process.arguments.count) &&
                                 (YES != [process.arguments.firstObject hasPrefix:@"/dev/"]))
                        {
                            //use arg[0]
                            process.path = process.arguments.firstObject;
                        }
                        
                        //save fork events
                        // ->this will have ppid that can be used for child events (exec/spawn, etc)
                        if(AUE_FORK == process.type)
                        {
                            //save
                            lastFork = process;
                        }
                        
                        //when we don't have a ppid
                        // ->see if there was a 'matching' fork() that has it (only for non AUE_FORK events)
                        else if( (-1 == process.ppid)  &&
                                 (lastFork.pid == process.pid) )
                        {
                            //update
                            process.ppid = lastFork.ppid;
                        }
                        
                        //dbg msg
                        //NSLog(@"NEW PROCESS EVENT: %@", process);
                        //NSLog(@"parents: %@", generateProcessHierarchy(processRecord.ppid));
                        
                        //handle new process
                        [self handleNewProcess:process];
                    }
                    
                    //unset
                    process = nil;
                    
                    break;
                }
                    
                    
                default:
                    ;
                    
            }//process token
            
            
            //add length of current token
            processedLength += tokenStruct.len;
            
            //subtract lenght of current token
            recordBalance -= tokenStruct.len;
        }
    }
    
//bail
bail:
    
    //free buffer
    if(NULL != recordBuffer)
    {
        //free
        free(recordBuffer);
    }
    
    //close audit pipe
    if(NULL != auditFile)
    {
        //close
        fclose(auditFile);
    }
    
    return;
}

//check if event is one we care about
// ->for now, just anything associated with new processes
-(BOOL)shouldProcessRecord:(u_int16_t)eventType
{
    //flag
    BOOL shouldProcess =  NO;
    
    //check
    if( (eventType == AUE_EXECVE) ||
        (eventType == AUE_FORK) ||
        (eventType == AUE_EXEC) ||
        (eventType == AUE_POSIX_SPAWN))
    {
        //set flag
        shouldProcess = YES;
    }
    
    return shouldProcess;
}


//TODO only do on macOS 10.12.4 <

//register for app launchings
-(void)setupAppMonitoring
{
    //notification center
    NSNotificationCenter* center = nil;
    
    //get shared center
    center = [[NSWorkspace sharedWorkspace] notificationCenter];
    
    //register notification
    [center addObserver:self selector:@selector(appLaunched:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    
    return;
}

//automatically invoked when an app is launched
// ->create new process object and add to dictionary
//   note: this is needed since on can only use BSM auditing on macOS 10.11.4+ due to kernel panic :(
-(void)appLaunched:(NSNotification *)notification
{
    //process object
    Process* process = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //create a new process
    process = [[Process alloc] init];
    
    //set pid
    process.pid = [notification.userInfo[@"NSApplicationProcessIdentifier"] intValue];
    
    //load bundle to get path
    appBundle = [NSBundle bundleWithPath:notification.userInfo[@"NSApplicationPath"]];
    if(nil != appBundle)
    {
        //get path
        process.path = appBundle.executablePath;
    }
    
    //no path?
    if(nil == process.path)
    {
        //TODO: err msg
        
        //bail
        goto bail;
    }
    
    //handle new process
    [self handleNewProcess:process];
    
//bail
bail:
    
    return;
}

//TODO: removed exit'd procs - but only if dead for maybe more than 1 min?
// (add timestamp to process obj?)

//create binary object
// ->enum/process ancestors, etc
-(void)handleNewProcess:(Process*)newProcess
{
    //get parent
    if(-1 == newProcess.ppid)
    {
        //set ppid
        newProcess.ppid =  getParentID(newProcess.pid);
    }
    
    //create binary obj
    newProcess.binary = [[Binary alloc] init:newProcess.path attributes:nil];
    if(nil == newProcess.binary)
    {
        //TODO: error msg
        
        //bail
        goto bail;
        
    }
    //generate ancestors for apple bins
    if(YES == newProcess.binary.isApple)
    {
        //generate
        // ->also ID's if there's an untrusted ancestor
        [newProcess enumerateAncestors];
    }
    
    //add to list
    @synchronized(self.processes)
    {
        //add
        self.processes[[NSNumber numberWithUnsignedInteger:newProcess.pid]] = newProcess;
    }

//bail
bail:
    
    return;
    
}


@end
