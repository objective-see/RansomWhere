//
//  Process.m
//  BlockBlock
//
//  Created by Patrick Wardle on 10/26/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Process.h"
#import "FileSystemMonitor.h"
#import "Logging.h"
#import "Utilities.h"
#import "ProcessMonitor.h"


#import <libproc.h>


@implementation Process

//@synthesize pid;
@synthesize name;
@synthesize path;
@synthesize bundle;
@synthesize isApple;

//init w/ a pid
-(id)initWithPid:(pid_t)processID infoDictionary:(NSDictionary*)infoDictionary
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //save pid
        //self.pid = [NSNumber numberWithUnsignedInt:processID];
        
        //save process name
        if(nil != infoDictionary[@"name"])
        {
            //save name
            self.name = infoDictionary[@"name"];
        }
        
        //save process (binary) path
        if(nil != infoDictionary[@"path"])
        {
            //save path
            self.path = infoDictionary[@"path"];
        }
        
        //save process bundle
        // ->direct load via app path
        if(nil != infoDictionary[@"appPath"])
        {
            //load app bundle
            self.bundle = [NSBundle bundleWithPath:infoDictionary[@"appPath"]];
            
            //save path
            self.path = self.bundle.executablePath;
        }
        
        //when path still nil
        // ->try find it via helper function
        if(nil == self.path)
        {
            //get it
            // ->if this still fails bail
            self.path = getProcessPath(processID);
            if(nil == self.path)
            {
                //unset
                self = nil;
                
                //bail
                goto bail;
            }
        }
        
        //
        
        //TODO: handle nil path
        
        //TODO: no path, return nil? (but make sure caller's ok with nil, like don't put in dict!
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"INIT'ING process: %d/%@/%@", processID, infoDictionary, self]);
        
        
        //determine if binary belongs to OS X/Apple
        if(nil != self.path)
        {
            self.isApple = isAppleBinary(self.path);
        }
        
        
        /*
        //name still blank?
        // ->try to determine it
        if(nil == self.name)
        {
            //resolve name
            [self determineName];
        }
        
        //path still blank?
        // ->try to determine it
        if(nil == self.path)
        {
            //resolve name
            [self determinePath];
        }
    
        */
    }//init self

//bail
bail:
    
    return self;
}

/*
//try to determine name
// ->either from bundle or path's last component
-(void)determineName
{
    //try to get name from bundle
    // ->key 'CFBundleName'
    if(nil != self.bundle)
    {
        //extract name
        self.name = [self.bundle infoDictionary][@"CFBundleName"];
    }
    
    //no bundle/that fail
    // ->try from path, by grabbing last component
    if( (nil == self.name) &&
        (nil != self.path) )
    {
        //extract name
        self.name = [self.path lastPathComponent];
    }
    
    return;
}

//try to determine name
// ->either from bundle or via 'which'
-(void)determinePath
{
    //try to get path from bundle
    if(nil != self.bundle)
    {
        //logMsg(LOG_DEBUG, @"determining path from bundle");
        
        //extract path
        self.path = self.bundle.executablePath;
    }
    
    //try to get path from name
    // ->use 'which' helper function
    else if(nil != self.name)
    {
        //logMsg(LOG_DEBUG, @"determining path from name");
        
        //resolve
        self.path = which(self.name);
    }

    return;
}
*/

//for pretty printing
-(NSString *)description
{
    //pretty print
    return [NSString stringWithFormat: @"name=%@/path=%@/bundle=%@", self.name, self.path, self.bundle];
}


@end
