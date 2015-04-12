//
//  ProcessMonitor.h
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import <dtrace.h>
#import <Foundation/Foundation.h>

#import "OrderedDictionary.h"

//output tokenizer
// ->needed since dtrace dumps to a pipe
#define OUTPUT_TOKENIZER "###"

//max number of items in process list
#define PROCESS_LIST_MAX_SIZE 64



//dtrace program
// ->pid, name, path
//   see: https://gist.github.com/viroos/1242279
//   note: sticking with exec*:return since proc::posix_spawn:exec-success caused major perf issues!
static const char *dtraceProbe =
"syscall::exec*:return,proc::posix_spawn:exec-success  \
{ \
this->isx64 = (curproc->p_flag & P_LP64) != 0; \
this->ptrsize = this->isx64 ? sizeof(uint64_t) : sizeof(uint32_t); \
this->argc=curproc->p_argc; \
this->argv=(uint64_t)copyin(curproc->p_dtrace_argv,this->ptrsize*this->argc); \
this->processName = this->isx64 ? copyinstr(*(uint64_t*)(this->argv)) : copyinstr(*(uint32_t*)(this->argv)); \
printf(\"###{\\\"pid\\\": %d, \\\"uid\\\": %d, \\\"name\\\": \\\"%s\\\", \\\"path\\\": \\\"%s\\\", \\\"ppid\\\": %d}\", pid, uid, execname, this->processName, ppid); \
}";

//size of dtrace output buffer
#define BUFFER_SIZE 512

//sleep time
#define PSLEEP_TIME 1


@interface ProcessMonitor : NSObject
{
    //dtrace monitor thread
    NSThread* dtraceProducerThread;
    
    //reader thread
    NSThread* dtraceConsumerThread;

    //dtrace handle
    dtrace_hdl_t *dtraceHandle;
    
    //output pipes
    int outputPipe[2];
    
    //processes
    // ->gui, background, cmdline
    OrderedDictionary* processList;
    
    //for chunked (split) output
    NSString* outputChunk;
    
}

/* METHODS */

//kick off thread to monitor
-(BOOL)monitor;

//main thread function
-(void)produceOutput:(id)threadParam;


/* PROPERTIES */

//@property int stdoutPipe[2];
@property dtrace_hdl_t *dtraceHandle;
@property (nonatomic, retain)OrderedDictionary* processList;
@property (nonatomic, retain)NSThread* dtraceProducerThread;
@property (nonatomic, retain)NSThread* dtraceConsumerThread;
@property (nonatomic, retain)NSString* outputChunk;


@end
