//
//  kext.m
//  BlockBlock
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "kext.h"
#import "Utilities.h"
#import "WatchEvent.h"


//TODO: how to get info about kext since bundle doesn't give me any luv :/
//TODO: run pristene version of filemon (re-download?) and see if it get dirs (e.g. cp -r unsigned.kext)...and if not, email author!!
//TODO: test fs_usage

@implementation kext

-(id)initWithParams:(NSDictionary*)watchItemInfo
{
    //init super
    self = [super initWithParams:watchItemInfo];
    
    if(nil != self)
    {
        //dbg msg
        NSLog(@"init'ing %@ (%p)", NSStringFromClass([self class]), self);
        
        //do any other inits here
        
    }

    return self;
}


//take a closer look to make sure watch event is really one we care about
// for kext, only care about the creation of the .kext directory (not files under it)
// TODO: add support modifications of existing .kexts
// TODO: check for dir .kext in name!? (is this required to load? test!!)
-(BOOL)shouldIgnore:(WatchEvent*)watchEvent
{
    //flag
    BOOL shouldIgnore = YES;
    
    //stripped path
    NSString* strippedPath = nil;
    
    //final directory component
    NSString* finalDirComponent = nil;
    
    //candidate kext directory
    NSString* candidateKextDirectory = nil;
    
    //directory attributes
    NSDictionary* directoryAttributes = nil;
    
    //directory's creation time
    //NSDate* directoryCreationTime = nil;
    
    //directory's creation time
    NSDate* directoryModificationTime = nil;
    
    //check for create
    //TODO: do we need to do: &FSE_CREATE_FILE?
    if(FSE_CREATE_DIR == watchEvent.flags)
    {
        
        //since the actual .kext directory event might be missed
        // ->have some extra logic to take paths created within the .kext directory and back up to .kext
        
        /*
        //handle path's that aren't directly within the match path
        // ->e.g. /System/Library/Extensions/<blah>.kext/blah/
        if(YES != [watchEvent.match isEqualToString:[watchEvent.path stringByDeletingLastPathComponent]])
        {
            //init stripped path
            strippedPath = watchEvent.path;
            
            //scan back up
            // ->until the matched watch directory (e.g. /System/Library/Extensions/ is hit)
            do
            {
                //first save final directory component
                finalDirComponent = [[strippedPath pathComponents] lastObject];
                
                //then strip off final directory component
                strippedPath = [strippedPath stringByDeletingLastPathComponent];
                
                //dbg msg
                //NSLog(@"stripped path: %@", strippedPath);
                
                //is it (now) equal to matched watch path?
                // ->this is the top level directory (such as /System/Library/Extensions
                if(YES == [watchEvent.match isEqualToString:strippedPath])
                {
                    //re-add the directory
                    // ->this should be .kext/
                    candidateKextDirectory = [strippedPath stringByAppendingPathComponent:finalDirComponent];
                    
                    //dbg msg
                    NSLog(@"candidate kext: %@", candidateKextDirectory);
                    
                    //get .kext's attributes
                    directoryAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:candidateKextDirectory error:nil];
                    
                    //NSLog(@"dir attrs: %@", directoryAttributes);
                    
                    //get date when directory (.kext/) was created
                    //directoryCreationTime = [directoryAttributes objectForKey:NSFileCreationDate];
                    directoryModificationTime = [directoryAttributes objectForKey:NSFileModificationDate];
                    
                    NSLog(@"comparing %@ with %@", directoryModificationTime, [NSDate date]);
                    NSLog(@"result: %f", [[NSDate date] timeIntervalSinceDate:directoryModificationTime]);
                    
                    //compare with now
                    // ->want to know if its new (e.g. just created and thus should be blocked)
                    if([[NSDate date] timeIntervalSinceDate:directoryModificationTime] < 5.0)
                    {
                        //dbg msg
                        NSLog(@".kext dir looks new!");
                        
                        //it's new!
                        // ->don't ignore
                        shouldIgnore = NO;
                        
                        //update watch path
                        // ->since we really only care about the .kext directory
                        watchEvent.path = finalDirComponent;
                        
                        //done, so bail
                        break;
                    }
                    //too old
                    else
                    {
                        //dbg msg
                        NSLog(@"candidate kext directory looks too old");
                    }
                }
                
                //scan until path has been fully stripped (e.g. its just '/')
            } while(YES != [strippedPath isEqualToString:@"/"]);
        }
         
        */
        
        //top-level match
        //else
        //{
        //dbg msg
        NSLog(@"watchEvent.path %@ is OK as is", watchEvent.path);
            
        //
        shouldIgnore = NO;
        //}
        
    

        
        //NSLog(@"ok, CREATED: %@", watchEvent.path);
        
        //happy
        // ->don't ignore
        //shouldIgnore = NO;
        
        /*
        //check that path is directory
        if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:watchEvent.path isDirectory:&isDirectory]) &&
            (YES == isDirectory) )
        {
            //happy
            // ->don't ignore
            shouldIgnore = NO;
        }
        */
    }
    
    return shouldIgnore;
}


//for kext
// ->just delete entire kext directory
// TODO: sometimes events are missed

-(void)block:(WatchEvent*)watchEvent;
{
    //error
    NSError* error = nil;
    
    //dbg msg
    NSLog(@"PLUGIN %@: blocking %@", NSStringFromClass([self class]), watchEvent.path);
    
    //delete directory
    //TODO: this sometimes fails? WTF (doube copy and paste - testtt!)
    //TODO: this is ok is this fails - since it might just be a file-not-found-event...
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:watchEvent.path error:&error])
    {
        //err msg
        NSLog(@"ERROR: failed to delete %@ (%@)", watchEvent.path, error);
    }
    else
    {
        //dbg msg
        NSLog(@"BLOCKED OK");
    }
    
    return;
}

//TODO: initWithIconRef for iCONS (for apps)

//get the name of the kext
// note: manually load/parse Info.plist (instead of using bundle) since it might not be on disk yet...
-(NSString*)startupItemName:(WatchEvent*)watchEvent
{
    //name of kext
    NSString* kextName = nil;
    
    //max wait time
    float maxWait = 1.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    NSLog(@"extracting kext name for %@", watchEvent.path);
    
    //try to get name of kext
    // ->might have to try several time since Info.plist may not exist right away...
    do
    {
        //nap
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //load bundle
        // ->and see if name is available
        bundle = [NSBundle bundleWithPath:watchEvent.path];
        if( (nil != bundle) && (bundle.infoDictionary[@"CFBundleName"]) )
        {
            //save it
            kextName = bundle.infoDictionary[@"CFBundleName"];
            
            //got it, so bail
            break;
        }
        
        //inc
        currentWait += WAIT_INTERVAL;
        
    //while timeout isn't hit
    }while(currentWait < maxWait);
    
    //dbg msg
    NSLog(@"extracted name: %@", kextName);
    
    return kextName;
}

//get the binary of the kext
// DON'T RETURN NIL
//TODO: need to handle case where trigger is: /Users/patrick/Desktop/watchDir/unsigned.kext/Contents/Resources/en.lproj
-(NSString*)startupItemBinary:(WatchEvent*)watchEvent
{
    //name of kext
    NSString* kextBinary = nil;
    
    //max wait time
    float maxWait = 1.0f;
    
    //bundle
    NSBundle* bundle = nil;
    
    //current wait time
    float currentWait = 0.0f;
    
    //dbg msg
    NSLog(@"extracting kext binary for %@", watchEvent.path);

    //try to get name of kext
    // ->might have to try several time since bundle may not exist right away...
    do
    {
        //nap
        [NSThread sleepForTimeInterval:WAIT_INTERVAL];
        
        //load bundle
        // ->and see if name is available
        bundle = [NSBundle bundleWithPath:watchEvent.path];
        if( (nil != bundle) && (nil != bundle.executablePath) )
        {
            //save it
            kextBinary = bundle.executablePath;
            
            //got it, so bail
            break;
        }
        
        //inc
        currentWait += WAIT_INTERVAL;
        
        //while timeout isn't hit
    }while(currentWait < maxWait);
    
    //dbg msg
    NSLog(@"extracted name: %@", kextBinary);

    return kextBinary;
}
@end
