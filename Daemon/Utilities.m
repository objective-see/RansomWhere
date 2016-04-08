//
//  Utilities.m
//  RansomWhere
//
//  Created by Patrick Wardle on 10/31/14.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "3rdParty/ent/ent.h"

#import <syslog.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <OpenDirectory/OpenDirectory.h>
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <ApplicationServices/ApplicationServices.h>

//success
#define STATUS_SUCCESS 0

//get version of self
NSString* getDaemonVersion()
{
    return DAEMON_VERSION;
}

//enumerate all running processes
NSMutableArray* enumerateProcesses()
{
    //status
    int status = -1;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //processes
    NSMutableArray* processes = nil;
    
    //alloc array
    processes = [NSMutableArray array];
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    if(nil == pids)
    {
        //bail
        goto bail;
    }
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t));
    if(status < 0)
    {
        //err
        logMsg(LOG_ERR, [NSString stringWithFormat:@"OBJECTIVE-SEE ERROR: proc_listpids() failed with %d", status]);
        
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->save pid into return array
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //save each pid
        if(0 != pids[i])
        {
            //save
            [processes addObject:[NSNumber numberWithUnsignedInt:pids[i]]];
        }
    }
    
//bail
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    return processes;
}

//generate list of all installed applications
// ->done via system_profiler, w/ 'SPApplicationsDataType' flag
NSMutableArray* enumerateInstalledApps()
{
    //installed apps
    NSMutableArray* installedApplications = nil;
    
    //output from system profiler task
    NSData* taskOutput = nil;
    
    //serialized task output
    NSArray* serializedOutput = nil;
    
    //alloc array for installed apps
    installedApplications = [NSMutableArray array];
    
    //exec system profiler
    taskOutput = execTask(SYSTEM_PROFILER, @[@"SPApplicationsDataType", @"-xml",  @"-detailLevel", @"mini"]);
    if(nil == taskOutput)
    {
        //bail
        goto bail;
    }
    
    //serialize output to array
    serializedOutput = [NSPropertyListSerialization propertyListWithData:taskOutput options:kNilOptions format:NULL error:NULL];
    if(nil == serializedOutput)
    {
        //bail
        goto bail;
    }
    
    //wrap to parse
    // ->grab list of installed apps from '_items' key
    @try
    {
        //save
        installedApplications = serializedOutput[0][@"_items"];
    }
    @catch(NSException *exception)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to extract installed items from serialized application list");
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return installedApplications;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* taskPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);

    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        taskPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // ->try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ->ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        // ->at start of buffer
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // ->follows # of args (int) and is NULL-terminated
        taskPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
        
//bail
bail:
        
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
        
    return taskPath;
}


//get all user home directories
NSMutableArray* getUserHomeDirs()
{
    //installed users
    NSMutableArray* users = nil;
    
    //user home directories
    NSArray* userHomeDirectories = nil;
    
    //alloc
    users = [NSMutableArray array];
    
    //check all users
    // ->do any have the launch agent installed?
    for(ODRecord* userRecord in getUsers())
    {
        //extract home dirs
        userHomeDirectories = [userRecord valuesForAttribute:kODAttributeTypeNFSHomeDirectory error:NULL];
        
        //check if there is a home dir
        if(0 == [userHomeDirectories count])
        {
            //skip
            continue;
        }
        
        //also skip any that start with /var
        if(YES == [userHomeDirectories.firstObject hasPrefix:@"/var"])
        {
            //skip
            continue;
        }
        
        //add first directory
        [users addObject:userHomeDirectories.firstObject];
    }
    
    return users;

}

//get all users
NSMutableArray* getUsers()
{
    //users
    NSMutableArray* users = nil;
    
    //root node
    ODNode *root = nil;
    
    //user query
    ODQuery *userQuery = nil;
    
    //alloc
    users = [NSMutableArray array];
    
    //init root node
    root = [ODNode nodeWithSession:[ODSession defaultSession] name:@"/Local/Default" error:nil];
    
    //make query
    userQuery = [ODQuery queryWithNode:root forRecordTypes:kODRecordTypeUsers attribute:nil matchType:0 queryValues:nil returnAttributes:nil maximumResults:0 error:nil];
    
    //iterate over all users and save
    for(ODRecord* record in [userQuery resultsAllowingPartial:NO error:nil])
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"record: %@", record]);
        
        //save
        [users addObject:record];
    }
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"all users: %@", users]);
    
    return users;
}

//determine if a file is signed by Apple proper
BOOL isAppleBinary(NSString* path)
{
    //flag
    BOOL isApple = NO;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //signing reqs
    SecRequirementRef requirementRef = NULL;
    
    //status
    OSStatus status = -1;
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    if(STATUS_SUCCESS != status)
    {
        //err msg
        syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: SecStaticCodeCreateWithPath() failed on %s with %d", [path UTF8String], status);
        
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple'
    // (3rd party: 'anchor apple generic')
    status = SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &requirementRef);
    if( (STATUS_SUCCESS != status) ||
        (requirementRef == NULL) )
    {
        //err msg
        syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: SecRequirementCreateWithString() failed on %s with %d", [path UTF8String], status);
        
        //bail
        goto bail;
    }
    
    //check if file is signed by apple by checking if it conforms to req string
    // note: ignore 'errSecCSBadResource' as lots of signed apple files return this issue :/
    status = SecStaticCodeCheckValidity(staticCode, kSecCSDefaultFlags, requirementRef);
    if( (STATUS_SUCCESS != status) &&
        (errSecCSBadResource != status) )
    {
        //bail
        // ->just means app isn't signed by apple
        goto bail;
    }
    
    //ok, happy (SecStaticCodeCheckValidity() didn't fail)
    // ->file is signed by Apple
    isApple = YES;
    
//bail
bail:
    
    //free req reference
    if(NULL != requirementRef)
    {
        //free
        CFRelease(requirementRef);
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
    }
    
    return isApple;
}

/*
//get info about current logged in/active user
NSDictionary* getCurrentConsoleUser()
{
    //all users
    NSArray* allUsers = nil;
    
    //user info dictionary
    NSMutableDictionary* userInfo = nil;
    
    //user's name
    NSString* userName = nil;
    
    //user's uid
    uid_t userID = 0;
    
    //user's gid
    gid_t groupID = 0;
    
    //user's home directory
    NSString* userHomeDirectory = nil;
    
    //record data
    NSArray* recordData = nil;
    
    //get current user
    userName = (__bridge NSString *)(SCDynamicStoreCopyConsoleUser(NULL, &userID, &groupID));
    
    //sanity check
    if(NULL == userName)
    {
        //bail
        goto bail;
    }
    
    //treat "loginwindow" as no user
    if(YES == [userName isEqualToString:@"loginwindow"])
    {
        //bail
        goto bail;
    }
    
    //get all users
    // ->need user's home directory
    allUsers = getUsers();
    
    //iterate over all users till we find match
    for(ODRecord* userRecord in allUsers)
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"record: %@", userRecord]);
        
        //get current uid
        recordData = [userRecord valuesForAttribute:kODAttributeTypeUniqueID error:NULL];
        
        //check if there is a uid
        if(0 == [recordData count])
        {
            //skip
            continue;
        }
        
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"record class %@", [[recordData firstObject] className]]);
        
        //check for match
        if(userID == [[recordData firstObject] intValue])
        {
            //extract home dirs
            recordData = [userRecord valuesForAttribute:kODAttributeTypeNFSHomeDirectory error:NULL];
            
            //check if there is a home dir
            if(0 != [recordData count])
            {
                //save
                userHomeDirectory = [recordData firstObject];
                
                //done
                break;
            }
        }
    
    }
    
    //alloc
    userInfo = [NSMutableDictionary dictionary];
    
    //add name
    userInfo[@"name"] = userName;
    
    //add uid
    userInfo[@"uid"] = [NSNumber numberWithInt:userID];
    
    //add gid
    userInfo[@"gid"] = [NSNumber numberWithInt:groupID];
    
    //add user's home directory
    if(nil != userHomeDirectory)
    {
        //add
        userInfo[@"homeDirectory"] = userHomeDirectory;
    }
    
//bail
bail:
    
    //free user name
    if(NULL != userName)
    {
        //free
        CFRelease((CFStringRef)userName);
        userName = NULL;
    }

    return userInfo;
}
*/

/*

//get version
// ->either of self, or installed
NSString* getVersion(NSUInteger instance)
{
    //version
    NSString* currentVersion = nil;
    
    //info dictionary
    NSDictionary* infoDictionary = nil;
    
    //for current version
    // ->get info dictionary from main bundle
    if(VERSION_INSTANCE_SELF == instance)
    {
        //get info dictionary
        infoDictionary = [[NSBundle mainBundle] infoDictionary];
    }
    //for installed version
    // ->get info dictionary from loaded bundle
    else if(VERSION_INSTANCE_INSTALLED == instance)
    {
        //get info dictionary
        infoDictionary = getAppInfo(APPLICATION_PATH);
    }
    
    //extract version string
    // ->'CFBundleVersion'
    if(nil != infoDictionary)
    {
        //extract
        currentVersion = infoDictionary[@"CFBundleVersion"];
    }
    
    return currentVersion;
}

//query interwebz to get latest version
NSString* getLatestVersion()
{
    //version data
    NSData* versionData = nil;
    
    //version dictionary
    NSDictionary* versionDictionary = nil;
    
    //latest version
    NSString* latestVersion = nil;
    
    //get version from remote URL
    versionData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:PRODUCT_VERSION_URL]];
    
    //sanity check
    if(nil == versionData)
    {
        //bail
        goto bail;
    }
    
    //convert JSON to dictionary
    versionDictionary = [NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil];
    
    //sanity check
    if(nil == versionDictionary)
    {
        //bail
        goto bail;
    }
    
    //extract latest version
    latestVersion = versionDictionary[@"latestVersion"];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"latest version: %@", latestVersion]);
    
//bail
bail:
    
    return latestVersion;
}



//check if process is alive
BOOL isProcessAlive(pid_t processID)
{
    //ret var
    BOOL bIsAlive = NO;
    
    //signal status
    int signalStatus = -1;
    
    //send kill with 0 to determine if alive
    // -> see: http://stackoverflow.com/questions/9152979/check-if-process-exists-given-its-pid
    signalStatus = kill(processID, 0);
    
    //is alive?
    if( (0 == signalStatus) ||
       ( (0 != signalStatus) && (errno != ESRCH) ) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"agent (%d) is ALIVE", processID]);
        
        //alive!
        bIsAlive = YES;
    }
    
    return bIsAlive;
}
*/

//check if current OS version is supported
// ->for now, just...?
BOOL isSupportedOS()
{
    //support flag
    BOOL isSupported = NO;
    
    //OS version info
    NSDictionary* osVersionInfo = nil;
    
    //get OS version info
    osVersionInfo = getOSVersion();
    
    //sanity check
    if(nil == osVersionInfo)
    {
        //bail
        goto bail;
    }
    
    //gotta be OS X
    if(10 != [osVersionInfo[@"majorVersion"] intValue])
    {
        //err msg
        syslog(LOG_DEBUG, "%s\n", [NSString stringWithFormat:@"OS major version %@ not supported", osVersionInfo[@"majorVersion"]].UTF8String);
        
        //bail
        goto bail;
    }
    
    //gotta be OS X 10
    if([osVersionInfo[@"minorVersion"] intValue] < 9)
    {
        //err msg
        syslog(LOG_DEBUG, "%s\n", [NSString stringWithFormat:@"OS minor version %@ not supported", osVersionInfo[@"minor"]].UTF8String);
        
        //bail
        goto bail;
    }
    
    //OS version is supported
    isSupported = YES;
    
//bail
bail:
    
    return isSupported;
}

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive)
{
    //ret var
    BOOL bRet = NO;
    
    //owner dictionary
    NSDictionary* fileOwner = nil;
    
    //sub paths
    NSArray *subPaths = nil;
    
    //full path
    // ->for recursive
    NSString* fullPath = nil;
    
    //init permissions dictionary
    fileOwner = @{NSFileGroupOwnerAccountID:groupID, NSFileOwnerAccountID:ownerID};
    
    //set group/owner
    if(YES != [[NSFileManager defaultManager] setAttributes:fileOwner ofItemAtPath:path error:NULL])
    {
        //err msg
        //logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set ownership for %@ (%@)", path, fileOwner]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"set ownership for %@ (%@)", path, fileOwner]);
    
    //do it recursively
    if(YES == recursive)
    {
        //sanity check
        // ->make sure root starts with '/'
        if(YES != [path hasSuffix:@"/"])
        {
            //add '/'
            path = [NSString stringWithFormat:@"%@/", path];
        }
        
        //get all subpaths
        subPaths = [[NSFileManager defaultManager] subpathsAtPath:path];
        for(NSString *subPath in subPaths)
        {
            //init full path
            fullPath = [path stringByAppendingString:subPath];
            
            //set group/owner
            if(YES != [[NSFileManager defaultManager] setAttributes:fileOwner ofItemAtPath:fullPath error:NULL])
            {
                //err msg
                //logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set ownership for %@ (%@)", fullPath, fileOwner]);
                
                //bail
                goto bail;
            }
        }
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}

//get OS version
NSDictionary* getOSVersion()
{
    //os version info
    NSMutableDictionary* osVersionInfo = nil;

    //major v
    SInt32 majorVersion = 0;
    
    //minor v
    SInt32 minorVersion = 0;
    
    //alloc dictionary
    osVersionInfo = [NSMutableDictionary dictionary];
    
    //get major version
    if(STATUS_SUCCESS != Gestalt(gestaltSystemVersionMajor, &majorVersion))
    {
        //reset
        osVersionInfo = nil;
        
        //bail
        goto bail;
    }
    
    //get minor version
    if(STATUS_SUCCESS != Gestalt(gestaltSystemVersionMinor, &minorVersion))
    {
        //reset
        osVersionInfo = nil;
        
        //bail
        goto bail;
    }
    
    //set major version
    osVersionInfo[@"majorVersion"] = [NSNumber numberWithInteger:majorVersion];
    
    //set minor version
    osVersionInfo[@"minorVersion"] = [NSNumber numberWithInteger:minorVersion];
    
//bail
bail:
    
    return osVersionInfo;    
}

//exec a process and grab it's output
NSData* execTask(NSString* binaryPath, NSArray* arguments)
{
    //task
    NSTask *task = nil;
    
    //output pipe
    NSPipe *outPipe = nil;
    
    //read handle
    NSFileHandle* readHandle = nil;
    
    //output
    NSMutableData *output = nil;
    
    //init task
    task = [NSTask new];
    
    //init output pipe
    outPipe = [NSPipe pipe];
    
    //init read handle
    readHandle = [outPipe fileHandleForReading];
    
    //init output buffer
    output = [NSMutableData data];
    
    //set task's path
    [task setLaunchPath:binaryPath];
    
    //set task's args
    [task setArguments:arguments];
    
    //set task's output
    [task setStandardOutput:outPipe];
    
    //wrap task launch
    @try {
        
        //launch
        [task launch];
    }
    @catch(NSException *exception)
    {
        //err msg
        //syslog(LOG_ERR, "OBJECTIVE-SEE ERROR: taskExec(%s) failed with %s", [binaryPath UTF8String], [[exception description] UTF8String]);
        
        //bail
        goto bail;
    }
    
    //read in output
    while(YES == [task isRunning])
    {
        //accumulate output
        [output appendData:[readHandle readDataToEndOfFile]];
    }
    
    //grab any left over data
    [output appendData:[readHandle readDataToEndOfFile]];
    
//bail
bail:
    
    return output;
}

//set file type
// ->invokes 'file' cmd, the parses out result
NSString* determineFileType(NSString* path)
{
    //type
    NSString* type = nil;
    
    //results from 'file' cmd
    NSString* results = nil;
    
    //array of parsed results
    NSArray* parsedResults = nil;
    
    //exec 'file' to get file type
    results = [[NSString alloc] initWithData:execTask(FILE, @[path]) encoding:NSUTF8StringEncoding];
    if(nil == results)
    {
        //bail
        goto bail;
    }
    
    //parse results
    // ->format: <file path>: <file types>
    parsedResults = [results componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":\n"]];
    
    //sanity check
    // ->should be two items in array, <file path> and <file type>
    if(parsedResults.count < 2)
    {
        //bail
        goto bail;
    }
    
    //file type comes second
    // ->also trim whitespace
    type = [parsedResults[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
//bail
bail:
    
    return type;
}

//determine if a file is encrypted
// ->high entropy and
//   a) very low pi error
//   b) low pi error and low chi square
BOOL isEncrypted(NSString* path)
{
    //flag
    BOOL encrypted = NO;
    
    //test results
    NSMutableDictionary* results = nil;
    
    //do computations
    // ->entropy, chi square, and monte carlo pi error
    results = testFile(path);
    if(nil == results)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"encryption results for %@: %@", path, results]);
    #endif
    
    //ignore image files
    // ->looks for well known headers at start of file
    if( (nil != results[@"header"]) &&
        (YES == isAnImage(results[@"header"])) )
    {
        //ignore
        goto bail;
    }
    
    //encrypted files have super high entropy
    // ->so ignore files that have 'low' entropy
    if([results[@"entropy"] doubleValue] < 7.95)
    {
        //ignore
        goto bail;
    }
    
    //monte carlo pi error gotta be less than 1.5%
    if([results[@"montecarlo"] doubleValue] > 1.5)
    {
        //ignore
        goto bail;
    }
    
    //monte carlo pi error gotta above 0.5
    // ->gotta have low chi square as well
    if( ([results[@"montecarlo"] doubleValue] > 0.5) &&
        ([results[@"montecarlo"] doubleValue] > 500) )
    {
        //ignore
        goto bail;
    }
    
    //encrypted file!
    // ->file as very low pi error, or, lowish pi error *and* low chi square
    encrypted = YES;
   
//bail
bail:

    return encrypted;
}

//examines header for image signatures (e.g. 'GIF87a')
// ->see: https://en.wikipedia.org/wiki/List_of_file_signatures for image signatures
BOOL isAnImage(NSData* header)
{
    //flag
    BOOL isImage = NO;
    
    //header bytes as 4byte int
    unsigned int magic = 0;
    
    //init with first 4 bytes of header
    magic = *(unsigned int*)header.bytes;
    
    //check for magic (4-byte) header values
    if( (MAGIC_PNG == magic) ||
        (MAGIC_JPG == magic) ||
        (MAGIC_GIF == magic) ||
        (MAGIC_ICNS == magic) ||
        (MAGIC_TIFF == magic) )
    {
        //set flag
        isImage = YES;
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return isImage;
}



