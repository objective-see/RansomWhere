//
//  ProcessMonitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import <dtrace.h>
#import <Foundation/Foundation.h>

#import "OrderedDictionary.h"

//output tokenizer
// ->needed since dtrace dumps to a pipe
#define OUTPUT_TOKENIZER "###"

//max number of items in process list
#define PROCESS_LIST_MAX_SIZE 64



//dtrace program for pre-rootless (pre-OS X 10.11) systems
// ->return pid, name, path, args, etc
//   see: https://gist.github.com/viroos/1242279
static const char *dtraceProbePreRootless =
"syscall::exec*:return,proc::posix_spawn:exec-success,syscall::fork:return  \
{ \
this->isx64 = (curproc->p_flag & P_LP64) != 0; \
this->ptrsize = this->isx64 ? sizeof(uint64_t) : sizeof(uint32_t); \
this->argc=curproc->p_argc; \
this->argv=(uint64_t)copyin(curproc->p_dtrace_argv,this->ptrsize*this->argc); \
this->processName = this->isx64 ? copyinstr(*(uint64_t*)(this->argv)) : copyinstr(*(uint32_t*)(this->argv)); \
printf(\"###{\\\"pid\\\": %d, \\\"uid\\\": %d, \\\"name\\\": \\\"%s\\\", \\\"path\\\": \\\"%s\\\", \\\"ppid\\\": %d}\", pid, uid, execname, this->processName, ppid); \
}";

//dtrace program for rootless (OS X 10.11+) systems
// ->return pid, name, uuid, etc only...
static const char *dtraceProbeRootless =
"syscall::execve:return,syscall::posix_spawn:return,syscall::fork:return  \
{ \
printf(\"###{\\\"pid\\\": %d, \\\"uid\\\": %d, \\\"name\\\": \\\"%s\\\", \\\"ppid\\\": %d}\", pid, uid, execname, ppid); \
}";

//size of dtrace output buffer
#define BUFFER_SIZE 512

//sleep time
#define PSLEEP_TIME 1

//note for audit stuffz
// classes defined in /etc/security/audit_class
// events in classes, defined in /etc/security/audit_event

//audit pipe
#define AUDIT_PIPE "/dev/auditpipe"

//audit class for proc events
#define AUDIT_CLASS_PROCESS 0x00000080

//audit class for exec events
#define AUDIT_CLASS_EXEC 0x40000000

@interface ProcessMonitor : NSObject
{
    //dtrace monitor thread
    NSThread* dtraceProducerThread;
    
    //dtrace reader thread
    NSThread* dtraceConsumerThread;
    
    //audit pipe monitor thread
    NSThread* auditThread;
    
    //dtrace handle
    dtrace_hdl_t *dtraceHandle;
    
    //output pipes
    int outputPipe[2];
    
    //processes
    // ->gui, background, cmdline
    OrderedDictionary* processList;
    
    //for chunked (split) output
    NSString* outputChunk;
    
    //flag indicating rootless OS
    BOOL isRootless;
    
}

/* METHODS */

//kick off thread to monitor
-(BOOL)monitor;

//main thread function
-(void)produceOutput:(id)threadParam;

//check if audit event is one we care about
// ->i.e. one that deals with process exec/spawning
-(BOOL)shouldProcessRecord:(u_int16_t)eventType;



/* PROPERTIES */

//@property int stdoutPipe[2];
@property BOOL isRootless;
@property dtrace_hdl_t *dtraceHandle;
@property (nonatomic, retain)NSThread* auditThread;
@property (nonatomic, retain)NSString* outputChunk;
@property (nonatomic, retain)OrderedDictionary* processList;
@property (nonatomic, retain)NSThread* dtraceProducerThread;
@property (nonatomic, retain)NSThread* dtraceConsumerThread;




@end
