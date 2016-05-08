//
//  Utilities.m
//  RansomWhere
//
//  Created by Patrick Wardle on 10/31/14.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppReceipt.h"
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

//determine if there is a new version
// -1, YES or NO
BOOL isNewVersion(NSMutableString* versionString)
{
    //flag
    BOOL newVersionExists = NO;
    
    //installed version
    NSString* installedVersion = nil;
    
    //latest version
    NSString* latestVersion = nil;
    
    //get installed version
    installedVersion = getDaemonVersion();
    
    //get latest version
    // ->will query internet (bb's website)
    latestVersion = getLatestVersion();
    if(nil == latestVersion)
    {
        //bail
        goto bail;
    }
    
    //save version
    [versionString setString:latestVersion];
    
    //set version flag
    // ->YES/NO based on version comparision
    newVersionExists = (NSOrderedAscending == [installedVersion compare:latestVersion options:NSNumericSearch]);
    
//bail
bail:
    
    return newVersionExists;
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
    if(nil == versionData)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"failed to load version data from %@", PRODUCT_VERSION_URL]);
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"downloaded version info: %@",  [[NSString alloc] initWithData:versionData encoding:NSUTF8StringEncoding]]);
    #endif
    
    //convert JSON to dictionary
    versionDictionary = [NSJSONSerialization JSONObjectWithData:versionData options:0 error:nil];
    if(nil == versionDictionary)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"failed serialized downloaded version data (into JSON)");
        #endif
        
        //bail
        goto bail;
    }
    
    //extract latest version
    latestVersion = versionDictionary[@"latestVersion"];
    if(nil == latestVersion)
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"failed to extract 'latestVersion' from downloaded version data");
        #endif
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"latest version: %@", latestVersion]);
    #endif
    
//bail
bail:
    
    return latestVersion;
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
    
    //app path
    NSString* appPath = nil;
    
    //app binary
    NSString* appBinary = nil;
    
    //output from system profiler task
    NSData* taskOutput = nil;
    
    //serialized task output
    NSArray* serializedOutput = nil;
    
    //internal apps/binaries
    NSMutableArray* internalBinaries = nil;
    
    //alloc array for installed apps
    installedApplications = [NSMutableArray array];
    
    //alloc array internal apps
    internalBinaries = [NSMutableArray array];
    
    //exec system profiler
    taskOutput = execTask(SYSTEM_PROFILER, @[@"SPApplicationsDataType", @"-xml",  @"-detailLevel", @"mini"]);
    if(nil == taskOutput)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to exec system profiler");
        
        //bail
        goto bail;
    }
    
    //serialize output to array
    serializedOutput = [NSPropertyListSerialization propertyListWithData:taskOutput options:kNilOptions format:NULL error:NULL];
    if(nil == serializedOutput)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to serialize output from system profiler");
        
        //bail
        goto bail;
    }
    
    //wrap to parse
    // ->grab list of installed apps from '_items' key
    //   also enumerate any internal apps (login items, etc.)
    @try
    {
        //save
        for(NSDictionary* installedApp in serializedOutput[0][@"_items"])
        {
            //grab app path
            appPath = [installedApp objectForKey:@"path"];
            if(nil == appPath)
            {
                //skip
                continue;
            }
            
            //get app's binary
            appBinary = findAppBinary(appPath);
            if(nil == appBinary)
            {
                //skip
                continue;
            }
            
            //add to list
            [installedApplications addObject:appBinary];
            
            //also add any internal/child apps in app bundle
            [installedApplications addObjectsFromArray:enumerateInternalApps(appPath)];
        }
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

//get all internal apps of an app
// ->login items, helper apps in frameworks, etc
NSMutableArray* enumerateInternalApps(NSString* parentApp)
{
    //internal apps
    NSMutableArray* internalApps = nil;
    
    //directory enumerator
    NSDirectoryEnumerator* enumerator = nil;
    
    //current file
    NSString* currentFile = nil;
    
    //full path
    NSString* fullPath = nil;
    
    //app binary
    NSString* appBinary = nil;
    
    //alloc
    internalApps = [NSMutableArray array];
    
    //init directory enumerator
    enumerator = [[NSFileManager defaultManager] enumeratorAtPath:parentApp];
    
    //iterate over all files looking for any .apps
    // ->weird loop stuff needs for autorelease memory stuffz
    while(YES)
    {
        //pool
        @autoreleasepool {
            
        //grab next file
        currentFile = [enumerator nextObject];
        if(nil == currentFile)
        {
            //all done
            break;
        }
        
        //create full path
        fullPath = [parentApp stringByAppendingPathComponent:currentFile];
        
        //for now
        // ->only process applications
        if(YES != [fullPath hasSuffix:@".app"])
        {
            //ignore
            continue;
        }
        
        //get app's binary
        appBinary = findAppBinary(fullPath);
        if(nil == appBinary)
        {
            //ignore
            continue;
        }
        
        //save
        [internalApps addObject:appBinary];

        }//pool
    
    }//while(YES)
    
    return internalApps;
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

//load or unload the launch daemon via '/bin/launchctl'
void controlLaunchItem(NSUInteger action, NSString* plist)
{
    //action string
    // ->passed to launchctl
    NSString* actionString = nil;
    
    //set action string: load
    if(DAEMON_LOAD == action)
    {
        //load
        actionString = @"load";
    }
    //set action string: unload
    else
    {
        //unload
        actionString = @"unload";
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"invoking %@ with %@ %@ ", LAUNCHCTL, actionString, plist]);
    
    //control launch item
    // ->and check
    execTask(LAUNCHCTL, @[actionString, plist]);
    
    return;
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

//verify the receipt
// ->check bundle ID, app version, and receipt's hash
BOOL verifyReceipt(NSBundle* appBundle, AppReceipt* receipt)
{
    //flag
    BOOL verified = NO;
    
    //guid
    NSData* guid = nil;
    
    //hash data
    NSMutableData *digestData = nil;
    
    //hash buffer
    unsigned char digestBuffer[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //check guid
    guid = getGUID();
    if(nil == guid)
    {
        //bail
        goto bail;
    }
    
    //create data obj
    digestData = [NSMutableData data];
    
    //add guid to data obj
    [digestData appendData:guid];
    
    //add receipt's 'opaque value' to data obj
    [digestData appendData:receipt.opaqueValue];
    
    //add receipt's bundle id data to data obj
    [digestData appendData:receipt.bundleIdentifierData];
    
    //CHECK 1:
    // ->app's bundle ID should match receipt's bundle ID
    if(YES != [receipt.bundleIdentifier isEqualToString:appBundle.bundleIdentifier])
    {
        //bail
        goto bail;
    }
    
    //CHECK 2:
    // ->app's version should match receipt's version
    if(YES != [receipt.appVersion isEqualToString:appBundle.infoDictionary[@"CFBundleShortVersionString"]])
    {
        //bail
        goto bail;
    }
    
    //CHECK 3:
    // ->verify receipt's hash (UUID)
    
    //init SHA 1 hash
    CC_SHA1(digestData.bytes, (CC_LONG)digestData.length, digestBuffer);
    
    //check for hash match
    if(0 != memcmp(digestBuffer, receipt.receiptHash.bytes, CC_SHA1_DIGEST_LENGTH))
    {
        //hash check failed
        goto bail;
    }
    
    //happy
    verified = YES;
    
//bail
bail:
    
    return verified;
}

//get GUID (really just computer's MAC address)
// ->from Apple's 'Get the GUID in OS X' (see: 'Validating Receipts Locally')
NSData* getGUID()
{
    //status var
    __block kern_return_t kernResult = -1;
    
    //master port
    __block mach_port_t  masterPort = 0;
    
    //matching dictionar
    __block CFMutableDictionaryRef matchingDict = NULL;
    
    //iterator
    __block io_iterator_t iterator = 0;
    
    //service
    __block io_object_t service = 0;
    
    //registry property
    __block CFDataRef registryProperty = NULL;
    
    //guid (MAC addr)
    static NSData* guid = nil;
    
    //once token
    static dispatch_once_t onceToken = 0;
    
    //only init guid once
    dispatch_once(&onceToken,
    ^{
    
        //get master port
        kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
        if(KERN_SUCCESS != kernResult)
        {
            //bail
            goto bail;
        }
        
        //get matching dictionary for 'en0'
        matchingDict = IOBSDNameMatching(masterPort, 0, "en0");
        if(NULL == matchingDict)
        {
            //bail
            goto bail;
        }
        
        //get matching services
        kernResult = IOServiceGetMatchingServices(masterPort, matchingDict, &iterator);
        if(KERN_SUCCESS != kernResult)
        {
            //bail
            goto bail;
        }
        
        //iterate over services, looking for 'IOMACAddress'
        while((service = IOIteratorNext(iterator)) != 0)
        {
            //parent
            io_object_t parentService = 0;
            
            //get parent
            kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService);
            if(KERN_SUCCESS == kernResult)
            {
                //release prev
                if(NULL != registryProperty)
                {
                    //release
                    CFRelease(registryProperty);
                }
                
                //get registry property for 'IOMACAddress'
                registryProperty = (CFDataRef) IORegistryEntryCreateCFProperty(parentService, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);
                
                //release parent
                IOObjectRelease(parentService);
            }
            
            //release service
            IOObjectRelease(service);
        }
        
        //release iterator
        IOObjectRelease(iterator);
        
        //convert guid to NSData*
        // ->also release registry property
        if(NULL != registryProperty)
        {
            //convert
            guid = [NSData dataWithData:(__bridge NSData *)registryProperty];
            
            //release
            CFRelease(registryProperty);
        }
        
    //bail
    bail:
        
        ;
       
    });//only once
    
    return guid;
}

//determine if file is signed with Apple Dev ID/cert
BOOL isSignedDevID(NSString* binary)
{
    //flag
    BOOL signedOK = NO;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //signing reqs
    SecRequirementRef requirementRef = NULL;
    
    //status
    OSStatus status = -1;
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:binary]), kSecCSDefaultFlags, &staticCode);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple generic'
    status = SecRequirementCreateWithString(CFSTR("anchor apple generic"), kSecCSDefaultFlags, &requirementRef);
    if( (noErr != status) ||
        (requirementRef == NULL) )
    {
        //bail
        goto bail;
    }
    
    //check if file is signed w/ apple dev id by checking if it conforms to req string
    status = SecStaticCodeCheckValidity(staticCode, kSecCSDefaultFlags, requirementRef);
    if(noErr != status)
    {
        //bail
        // ->just means app isn't signed by apple dev id
        goto bail;
    }
    
    //ok, happy
    // ->file is signed by Apple Dev ID
    signedOK = YES;
    
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
    
    return signedOK;
}

//get the signing info of a file
NSDictionary* extractSigningInfo(NSString* path)
{
    //info dictionary
    NSMutableDictionary* signingStatus = nil;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //status
    OSStatus status = !STATUS_SUCCESS;
    
    //signing information
    CFDictionaryRef signingInformation = NULL;
    
    //cert chain
    NSArray* certificateChain = nil;
    
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on chert
    CFStringRef commonName = NULL;
    
    //flags
    SecCSFlags csFlags = kSecCSDefaultFlags;
    
    //init signing status
    signingStatus = [NSMutableDictionary dictionary];
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    
    //save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //check signature
    status = SecStaticCodeCheckValidity(staticCode, csFlags, NULL);
    
    //(re)save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //if file is signed
    // ->grab signing id and signing authorities
    if(STATUS_SUCCESS == status)
    {
        //grab signing authorities
        status = SecCodeCopySigningInformation(staticCode, kSecCSDefaultFlags|kSecCSSigningInformation, &signingInformation);
        
        //sanity check
        if(STATUS_SUCCESS != status)
        {
            //err msg
            NSLog(@"OBJECTIVE-SEE ERROR: SecCodeCopySigningInformation() failed on %@ with %d", path, status);
            
            //bail
            goto bail;
        }
        
        //grab signing ID
        signingStatus[KEY_SIGNATURE_IDENTIFIER] = [(__bridge NSDictionary*)signingInformation objectForKey:(__bridge NSString*)kSecCodeInfoIdentifier];
        
        //signed by Apple proper?
        signingStatus[KEY_SIGNING_IS_APPLE] = [NSNumber numberWithBool:isAppleBinary(path)];
        
        //not signed by Apple proper
        // ->check if from official app store
        if(YES != [signingStatus[KEY_SIGNING_IS_APPLE] boolValue])
        {
            //from app store?
            signingStatus[KEY_SIGNING_IS_APP_STORE] = [NSNumber numberWithBool:fromAppStore(path)];
        }
    }
    
    //init array for certificate names
    signingStatus[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //get cert chain
    certificateChain = [(__bridge NSDictionary*)signingInformation objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    
    //handle case there is no cert chain
    // ->adhoc? (/Library/Frameworks/OpenVPN.framework/Versions/Current/bin/openvpn-service)
    if(0 == certificateChain.count)
    {
        //set
        [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:@"signed, but no signing authorities (adhoc?)"];
    }
    
    //got cert chain
    // ->add each to list
    else
    {
        //get name of all certs
        for(index = 0; index < certificateChain.count; index++)
        {
            //extract cert
            certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
            
            //get common name
            status = SecCertificateCopyCommonName(certificate, &commonName);
            
            //skip ones that error out
            if( (STATUS_SUCCESS != status) ||
               (NULL == commonName))
            {
                //skip
                continue;
            }
            
            //save
            [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:(__bridge NSString*)commonName];
            
            //release name
            CFRelease(commonName);
        }
    }
    
//bail
bail:
    
    //free signing info
    if(NULL != signingInformation)
    {
        //free
        CFRelease(signingInformation);
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
    }
    
    return signingStatus;
}

//determine if a file is from the app store
// ->gotta be signed w/ Apple Dev ID & have valid app receipt
BOOL fromAppStore(NSString* path)
{
    //flag
    BOOL appStoreApp = NO;
    
    //app receipt
    AppReceipt* appReceipt = nil;
    
    //path to app bundle
    // ->just have binary
    NSBundle* appBundle = nil;
    
    //find app bundle from binary
    // ->likely not an application if this fails
    appBundle = findAppBundle(path);
    if(nil == appBundle)
    {
        //bail
        goto bail;
    }
    
    //first make sure its signed with an Apple Dev ID
    if(YES != isSignedDevID(path))
    {
        //bail
        goto bail;
    }
    
    //init
    // ->will parse/decode, etc
    appReceipt = [[AppReceipt alloc] init:appBundle];
    if(nil == appReceipt)
    {
        //bail
        goto bail;
    }
    
    //verify
    if(YES != verifyReceipt(appBundle, appReceipt))
    {
        //bail
        goto bail;
    }
    
    //happy
    // ->app is signed w/ dev ID & it receipt is solid
    appStoreApp = YES;

//bail
bail:
    
    return appStoreApp;
}

//given a bundle
// ->find its executable
NSString* findAppBinary(NSString* appPath)
{
    //binary
    NSString* binary = nil;
    
    //bundle
    NSBundle* bundle = nil;
    
    //load app bundle
    bundle = [NSBundle bundleWithPath:appPath];
    if(nil == bundle)
    {
        //bail
        goto bail;
    }
        
    //grab full path to app's binary
    binary = bundle.executablePath;
    if(nil == binary)
    {
        //bail
        goto bail;
    }
    
//bail
bail:

    return binary;
}


//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* binaryPath)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = binaryPath;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //check for match
        // ->binary path's match
        if( (nil != appBundle) &&
           (YES == [appBundle.executablePath isEqualToString:binaryPath]))
        {
            //all done
            break;
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
    //scan until we get to root
    // ->of course, loop will be exited if app info dictionary is found/loaded
    } while( (nil != appPath) &&
            (YES != [appPath isEqualToString:@"/"]) &&
            (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
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
    
    //when monte carlo pi error is above 0.5
    // ->gotta have low chi square as well
    if( ([results[@"montecarlo"] doubleValue] > 0.5) &&
        ([results[@"chisquare"] doubleValue] > 500) )
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

//check if binary's signing auth has been whitelisted
BOOL isInWhiteList(NSArray* signingAuths)
{
    //flag
    BOOL isWhiteListed = NO;
    
    //whitelisted apps
    static NSSet* whiteList = nil;
    
    //once token
    static dispatch_once_t onceToken = 0;
    
    //only init whitelist just once
    dispatch_once(&onceToken,
    ^{
        
        //load whitelisted apps
        whiteList = loadSet(WHITE_LIST_FILE);
        
    });//only once
    
    //check each signing auth
    for(NSString* signingAuth in signingAuths)
    {
        //check
        if(YES == [whiteList containsObject:signingAuth])
        {
            //found!
            isWhiteListed = YES;
            
            //done
            break;
        }
    }
    
    return isWhiteListed;
}

//check if binary has been graylisted
// ->based on binaries code signing ID
BOOL isInGrayList(NSString* signingID)
{
    //flag
    BOOL isGrayListed = NO;
    
    //graylisted apps
    static NSSet* grayList = nil;
    
    //once token
    static dispatch_once_t onceToken = 0;
    
    //only init graylist just once
    dispatch_once(&onceToken,
    ^{
      
        //load graylisted apps
        grayList = loadSet(WHITE_LIST_FILE);
      
    });//only once
    
    //check if graylist'd
    isGrayListed = [grayList containsObject:signingID];
    
    return isGrayListed;
}

//load a file into an NSSet
NSSet* loadSet(NSString* filePath)
{
    //array
    NSArray* array = nil;
    
    //set
    NSSet* set = nil;
    
    //load file into array
    array = [NSArray arrayWithContentsOfFile:filePath];
    if(nil == array)
    {
        //bail
        goto bail;
    }
    
    //convert to set
    set = [NSSet setWithArray:array];
    
//bail
bail:
    
    return set;
}


