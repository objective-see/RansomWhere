//
//  ProcessMonitor.m
//  BlockBlock
//
//  Created by Patrick Wardle on 10/19/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//
#import "Process.h"
#import "Utilities.h"
#import "ProcessMonitor.h"
#import "OrderedDictionary.h"
#import "Logging.h"



static int chew(const dtrace_probedata_t *data, void *arg);
static int chewrec(const dtrace_probedata_t *data, const dtrace_recdesc_t *rec, void *arg);

@implementation ProcessMonitor


@synthesize processList;
@synthesize outputChunk;
@synthesize dtraceHandle;
@synthesize dtraceProducerThread;
@synthesize dtraceConsumerThread;


-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init process list
        processList = [[OrderedDictionary alloc] init];
        
        //nil
        outputChunk = nil;
    }
    
    return self;
}

//watch for apps
// ->just apps
-(void)enableAppWatch
{
    //notification center
    NSNotificationCenter* notificationCenter = nil;
    
    //init notification center
    notificationCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    
    //install app launch notification
    [notificationCenter addObserver:self selector:@selector(appLaunched:)
                               name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"enabled app watch");

    return;
}

//callback that's automatically invoked whenever an app is launched
// ->instantiate a process obj and save it
-(void)appLaunched:(NSNotification *)notification
{
    //pid
    NSString* processID = 0;
    
    //info dictionary
    NSMutableDictionary* processInfo = nil;
    
    //process object
    Process* process = nil;
    
    //extract process id
    // ->key for dictionary
    processID = [notification userInfo][@"NSApplicationProcessIdentifier"];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"APP STARTED: %@", notification]);
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"app launched %@", [notification userInfo]]);
    
    //handle (possibly) new process object creation
    // ->sync'd, since this can happen in from various places/callbacks
    @synchronized(self.processList)
    {
        //first make sure its a new process
        // ->e.g. hasn't been detected/created by other callback/mechanism
        if(nil == [processList objectForKey:processID])
        {
            //init process info
            processInfo = [NSMutableDictionary dictionary];
            
            //name
            processInfo[@"name"] = [notification userInfo][@"NSApplicationName"];
            
            //app path
            processInfo[@"appPath"] = [notification userInfo][@"NSApplicationPath"];
        
            //create process
            process = [[Process alloc] initWithPid:[processID intValue] infoDictionary:processInfo];
            
            //dbg msg
            //logMsg(LOG_DEBUG, @"APPCALLBACK: inserting (app) process into process list");
            
            //trim list if needed
            if(self.processList.count >= PROCESS_LIST_MAX_SIZE)
            {
                //toss first (oldest) item
                [self.processList removeObjectForKey:[self.processList keyAtIndex:0]];
            }
            
            //insert process at end
            //TODO: WILL CRASH IF ARRAY ISN'T BIG ENOUGH!
            [self.processList insertObject:process forKey:processID atIndex:self.processList.count];
        }

    }//sync
    
    return;
}


//kick off thread to monitor
-(BOOL)monitor
{
    //return var
    BOOL bRet = NO;
    
    //init producer thread
    self.dtraceProducerThread = [[NSThread alloc] initWithTarget:self selector:@selector(produceOutput:) object:nil];
    
    //init consumer thread
    self.dtraceConsumerThread = [[NSThread alloc] initWithTarget:self selector:@selector(consumeOutput:) object:nil];
    
    //install dtrace probe
    if(YES != [self installDtraceProbe])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed into install dtrace probe");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"installed dtrace probe");
    
    //set dtrace options
    if(YES != [self setDtraceOptions])
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to set dtrace options");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"set dtrace options");
    
    //create an output pipe
    // ->allows code to read output from dtrace's probe
    if(YES != [self initOutputPipe])
    {
        //err msg
        logMsg(LOG_DEBUG, @"ERROR: failed to create output pipe");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"created output pipe");
    
    //start producer thread
    [self.dtraceProducerThread start];
    
    //start consumer thread
    [self.dtraceConsumerThread start];
    
    //register callback for (just) apps
    [self enableAppWatch];

    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//install the dtrace probe
// ->open dtrace, compile probe, install it
-(BOOL)installDtraceProbe
{
    //return var
    BOOL bRet = NO;
    
    //dtrace error msg
    int dtraceError = 0;
    
    //dtrace program
    dtrace_prog_t *dtraceProgram = NULL;
    
    //dtrace program info
    dtrace_proginfo_t dtraceProgramInfo = {0};
    
    //open dtrace handle
    self.dtraceHandle = dtrace_open(DTRACE_VERSION, 0, &dtraceError);
    if(NULL == self.dtraceHandle)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"ERROR: failed to get handle to dtrace (%s)", dtrace_errmsg(NULL, dtraceError)]);
        
        //bail
        goto bail;
    }
    
    //compile the dtrace probe
    dtraceProgram = dtrace_program_strcompile(self.dtraceHandle, dtraceProbe, DTRACE_PROBESPEC_NAME, 0, 0, NULL);
    if(NULL == dtraceProgram)
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to compile dtrace probe");
        
        //bail
        goto bail;
    }
    
    //install the probe
    if(-1 == dtrace_program_exec(self.dtraceHandle, dtraceProgram, &dtraceProgramInfo))
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: install dtrace probe");
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//set options for dtrace
-(BOOL)setDtraceOptions
{
    //return var
    BOOL bRet  = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"setting dtrace options");
    
    //set string (output) size
    // ->note: BUFFER_SIZE: 512
    if(-1 == dtrace_setopt(self.dtraceHandle, "strsize", "512"))
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to set 'strsize'");
        
        //bail
        goto bail;
    }
    
    //set buffer size
    if(-1 == dtrace_setopt(self.dtraceHandle, "bufsize", "4m"))
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to set 'bufsize'");
        
        //bail
        goto bail;
    }
    
    //set quite
    if(-1 == dtrace_setopt(self.dtraceHandle, "quiet", "true"))
    {
        //err msg
        logMsg(LOG_ERR, @"ERROR: failed to set 'quiet'");
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//create output pipe
-(BOOL)initOutputPipe
{
    //return var
    BOOL bRet = NO;
    
    //flags
    long flags = 0;

    //make em a pipe
    pipe(self->outputPipe);

    //get current flags
    flags = fcntl(self->outputPipe[0], F_GETFL);
    
    //update flags
    // ->non-blocking
    flags |= O_NONBLOCK;
    
    //update with new flags
    // ->makes pipe non-blocking
    if(-1 == fcntl(self->outputPipe[0], F_SETFL, flags))
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to make pipe non-blocking, (%d)", errno]);
        
        //bail
        goto bail;
    }

    //no errors
    bRet = YES;

//bail
bail:

    return bRet;
}


//read output from dtrace pipe
// ->parse and save
-(void)consumeOutput:(id)threadParam
{
    //input buffer
    char output[BUFFER_SIZE+1] = {0};
    
    //bytes read
    size_t bytesRead = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"process consumer thread, off and running");
    
    //tokenized output
    NSMutableArray* tokenizedOuput = nil;
    
    //process info dictionary
    NSMutableDictionary* processInfo = nil;

    //full path
    // ->needed as sometimes dtrace just reports 'tail', 'sed' etc
    NSString* fullPath = nil;
    
    //read/parse foreverz
    while(true)
    {
        //pool
        @autoreleasepool {
            
        //reset buffer
        memset(output, 0x0, BUFFER_SIZE);
        
        //read bytes from pipe
        // ->this is dtrace's output
        switch(bytesRead = read(self->outputPipe[0], output, BUFFER_SIZE))
        {
            //error or simply no data
            // (since pipe is non-blocking
            case -1:
            {
                //handle no data case
                // ->just sleep, then try again
                if(errno == EAGAIN)
                {
                    //sleep
                    sleep(PSLEEP_TIME);
                    
                    //bail
                    break;
                }
                //'real' error
                else
                {
                    //err msg
                    logMsg(LOG_ERR, [NSString stringWithFormat:@"read() failed with %d", errno]);
                    
                    //bail
                    goto cleanup;
                }
            }
                
            //pipe closed
            // TODO: use this to cause thead to bail? (e.g. when disabling blockblock)
            case 0:
            {
                //err msg
                logMsg(LOG_ERR, @"ERROR: pipe was closed...");
                
                //bail
                goto cleanup;
            }
                
            //got data
            // ->parse it
            default:
            {
                //split output on '###'
                tokenizedOuput = [self parseOutput:[NSMutableString stringWithUTF8String:output]];
                
                //parse output line-by-line
                // ->extract components and then place in dictionary
                for(NSString* item in tokenizedOuput)
                {
                    //convert from JSON string to dictionary
                    processInfo = [NSJSONSerialization JSONObjectWithData:[item dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:NULL];
                    
                    //sanity check
                    // ->make sure data was parsed ok
                    if(nil == processInfo)
                    {
                        //error, just skip
                        continue;
                    }
                    
                    //dbg msg
                    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"item: %@", item]);
                    
                    //sanity check output dictionary
                    // ->should contains pid, name, and path
                    if( (nil == processInfo[@"pid"]) ||
                        (nil == processInfo[@"uid"]) ||
                        (nil == processInfo[@"name"]) ||
                        (nil == processInfo[@"path"]) ||
                        (nil == processInfo[@"ppid"]) )
                    {
                        //err msg
                        logMsg(LOG_ERR, [NSString stringWithFormat:@"process dictionary appears incomplete: %@", processInfo]);
                        
                        //error, just skip
                        continue;
                    }
        
                    //dtrace sometimes just reports a short name
                    // ->try to find full path
                    if(YES == [processInfo[@"name"] isEqualToString:processInfo[@"path"]])
                    {
                        //get full path
                        // ->then, update path in info dictionary
                        fullPath = getFullPath(processInfo[@"pid"], processInfo[@"path"]);
                        if(nil != fullPath)
                        {
                            //dbg msg
                            //logMsg(LOG_ERR, [NSString stringWithFormat:@"updating short path (%@) with long path (%@)", processInfo[@"path"], fullPath]);
                            
                            //save
                            processInfo[@"path"] = fullPath;
                        }
                    }
                    
                    //handle (possibly) new process object creation
                    // ->sync'd, since this can happen in from various places/callbacks
                    @synchronized(self.processList)
                    {
                        //create new process
                        // ->but only if its new
                        if(nil == [processList objectForKey:processInfo[@"pid"]])
                        {
                            //create process object
                            Process * process = [[Process alloc] initWithPid:[processInfo[@"pid"] intValue] infoDictionary:processInfo];
                            
                            //dbg msg
                            //logMsg(LOG_ERR, [NSString stringWithFormat:@"DTRACE: inserting process into process list: %@", processInfo]);
                            
                            //trim list if needed
                            if(self.processList.count >= PROCESS_LIST_MAX_SIZE)
                            {
                                //toss first (oldest) item
                                [self.processList removeObjectForKey:[self.processList keyAtIndex:0]];
                            }
                            
                            //insert process at end
                            //TODO: WILL CRASH IF ARRAY ISN'T BIG ENOUGH!
                            [self.processList insertObject:process forKey:processInfo[@"pid"] atIndex:self.processList.count];
                        }
                        
                    }//sync
                    
                }
            }
                
        }//switch
            
        }//pool
        
    }//while(true)
  
//cleanup
cleanup:
    
    fprintf(stderr, "end of l00p\n");
    
    return;
}

//parse dtrace's output
// ->split on '###' and handle partial chunks
-(NSMutableArray*)parseOutput:(NSMutableString*)output
{
    //array of tokenized output
    // ->each member is JSON (pid, name, path)
    NSMutableArray* tokenizedOuput = nil;
    
    //strip off the first '###'
    if(YES == [output hasPrefix:@OUTPUT_TOKENIZER])
    {
        //remove '###'
        [output deleteCharactersInRange:NSMakeRange(0, @OUTPUT_TOKENIZER.length)];
    }
    
    //split the output!
    tokenizedOuput = [NSMutableArray arrayWithArray:[output componentsSeparatedByString:@OUTPUT_TOKENIZER]];
    
    //check if there was a previous chunk
    // ->if so, append first object to chunk...this should complete the chunk!
    if(nil != self.outputChunk)
    {
        //append
        self.outputChunk = [NSMutableString stringWithString:[outputChunk stringByAppendingString:tokenizedOuput.firstObject]];
        
        //remove the first (partial) chunk
        // ->if it wasn't completed here - not sure it ever will
        [tokenizedOuput removeObjectAtIndex:0x0];
        
        //check if chunk is now complete
        // ->ends with '}'
        if(YES == [self.outputChunk hasSuffix:@"}"])
        {
            //insert (add) it into start of tokenized array
            [tokenizedOuput insertObject:self.outputChunk atIndex:0];
        }
        
        //either way, nil out the partial chunk
        // ->if it wasn't completed by now - not sure it ever will
        self.outputChunk = nil;
    }
    
    //if the last object is a partial chunk
    // ->save it, hopefully next time will complete the check
    if(YES != [[tokenizedOuput lastObject] hasSuffix:@"}"])
    {
        //save partial chunk
        self.outputChunk = [tokenizedOuput lastObject];
        
        //remove it from tokenized output
        [tokenizedOuput removeLastObject];
    }
    
    return tokenizedOuput;
}


//produce dtrace output
-(void)produceOutput:(id)threadParam
{
    //file handle
    FILE *outputPipeHandle = NULL;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"process monitor producer thread: running"]);
    
    //get file handle to output pipe
    outputPipeHandle = fdopen(self->outputPipe[1], "a");
    if(NULL == outputPipeHandle)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"fdopen() failed with %d", errno]);
        
        //bail
        goto cleanup;
    }
    
    //dtrace go!
    if(0 != dtrace_go(self.dtraceHandle))
    {
        //err msg
        logMsg(LOG_ERR, @"dtrace_go() failed");
        
        //bail
        goto cleanup;
    }
    
    //forever
    // ->do dtrace work
    do
    {
        //pool
        @autoreleasepool {
            
        //nap
        dtrace_sleep(self.dtraceHandle);
        
        //work (ignoring result)
        // ->will produce output to stdout
        dtrace_work(self.dtraceHandle, outputPipeHandle, chew, chewrec, NULL);
        
        //flush it
        fflush(outputPipeHandle);
    
        }//pool
    
    } while(TRUE);
   
//cleanup
cleanup:
    
    ;
    
    return;
    
}

//TODO: shutdown function
// dtrace_close(g_dtp);
// close threads, etc
// close pipes~


@end

static int chew(const dtrace_probedata_t *data, void *arg)
{
    return DTRACE_CONSUME_THIS;
}

static int chewrec(const dtrace_probedata_t *data, const dtrace_recdesc_t *rec, void *arg)
{
    if(rec == NULL)
    {
        return DTRACE_CONSUME_NEXT;
    }
    if (rec->dtrd_action == DTRACEACT_EXIT)
    {
        return DTRACE_CONSUME_NEXT;
    }
    
    if(rec->dtrd_action == DTRACEACT_PRINTF)
    {
        return DTRACE_CONSUME_THIS;
    }
    return DTRACE_CONSUME_THIS;
}
