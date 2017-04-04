//
//  Utilities.m
//  RansomWhere (Installer)
//
//  Created by Patrick Wardle on 1/2/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

//start an NSTask
NSUInteger execTask(NSString* path, NSArray* arguments)
{
    //task object
    NSTask *task = nil;
    
    //task status
    NSUInteger taskStatus = -1;
    
    //make sure path exists
    // ->otherwise NSTask will throw an NSInvalidArgumentException error
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        //error
        logMsg(LOG_ERR, [NSString stringWithFormat:@"cannot exec NSTask since %@ was not found", path]);
        
        //bail
        goto bail;
    }
    
    //create task
    task = [[NSTask alloc] init];
    
    //set launch path
    // ->unzip binary
    [task setLaunchPath:path];
    
    //set args
    if(nil != arguments)
    {
        //set
        [task setArguments:arguments];
    }
    
    //exec task
    [task launch];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"waiting for task to exit");
    #endif
    
    //wait
    [task waitUntilExit];
    
    //get status
    taskStatus = [task terminationStatus];
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"task (%@) exited with %lu", path, (unsigned long)taskStatus]);
    #endif

//bail
bail:
    
    return taskStatus;
}

//get version
// ->either self, or installed version
NSString* getVersion(int instanceFlag)
{
    //version
    NSString* currentVersion = nil;
    
    //info dictionary
    NSDictionary* infoDictionary = nil;
    
    //get info dictionary
    infoDictionary = [[NSBundle mainBundle] infoDictionary];
    
    //extract version string
    // ->'CFBundleVersion'
    if(nil != infoDictionary)
    {
        //extract
        currentVersion = infoDictionary[@"CFBundleVersion"];
    }
    
    return currentVersion;
}

//is current OS version supported?
// ->for now, just OS X 10.10+
BOOL isSupportedOS()
{
    //support flag
    BOOL isSupported = NO;
    
    //OS version info
    NSDictionary* osVersionInfo = nil;
    
    //get OS version info
    osVersionInfo = getOSVersion();
    if(nil == osVersionInfo)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"OS version: %@", osVersionInfo]);
    #endif
    
    //gotta be OS X
    if(OS_MAJOR_VERSION_X != [osVersionInfo[@"majorVersion"] intValue])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"OS major version %@ not supported", osVersionInfo[@"majorVersion"]]);
        
        //bail
        goto bail;
    }
    
    //gotta be OS X at least lion (10.8)
    if([osVersionInfo[@"minorVersion"] intValue] < OS_MINOR_VERSION_LION)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"OS minor version %@ not supported", osVersionInfo[@"minor"]]);
        
        //bail
        goto bail;
    }
    
    //OS version is supported
    isSupported = YES;
    
//bail
bail:
    
    return isSupported;
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
    
    //bug fix v
    SInt32 fixVersion = 0;
    
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
    
    //get bug fix version
    if(STATUS_SUCCESS != Gestalt(gestaltSystemVersionBugFix, &fixVersion))
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
    
    //set bug fix version
    osVersionInfo[@"bugfixVersion"] = [NSNumber numberWithInteger:fixVersion];
    
//bail
bail:
    
    return osVersionInfo;
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
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set ownership for %@ (%@)", path, fileOwner]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"set ownership for %@ (%@)", path, fileOwner]);
    #endif
    
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
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set ownership for %@ (%@)", fullPath, fileOwner]);
                
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

//set permissions on a file
BOOL setFilePermissions(NSString* path, int permissions)
{
    //ret var
    BOOL bRet = NO;
    
    //error
    NSError* error = nil;
    
    //attributes
    NSDictionary* attributes = nil;
    
    //init attributes
    attributes = @{NSFilePosixPermissions:[NSNumber numberWithInt:permissions]};
    
    //set attributes
    if(YES != [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:path error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to set permmisions (%o) for %@", permissions, path]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    return bRet;
}


//get app's version
// ->extracted from Info.plist
NSString* getAppVersion()
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}
