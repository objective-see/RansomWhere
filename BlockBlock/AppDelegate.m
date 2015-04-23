//
//  AppDelegate.m
//  BlockBlock
//
//  Created by Patrick Wardle on 8/27/14.
//  Copyright (c) 2014 Synack. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Install.h"
#import "Control.h"
#import "AlertView.h"
#import "Exception.h"
#import "Uninstall.h"
#import "Utilities.h"
#import "PluginBase.h"
#import "WatchEvent.h"
#import "AppDelegate.h"
#import "ProcessMonitor.h"


@implementation AppDelegate

@synthesize watcher;
@synthesize orginals;
@synthesize controlObj;
@synthesize eventQueue;
@synthesize interProcComms;
@synthesize processMonitor;
@synthesize reportedWatchEvents;
@synthesize infoWindowController;
@synthesize errorWindowController;

//TODO: double-check versioning checks
//TODO: watchDir for kext ->update!


//automatically invoked when app is loaded
// ->parse args to determine what action to take
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //args
    NSArray* arguments = nil;
    
    //installer object
    Install* installObj = nil;
    
    //flag to indicate process should exit
    BOOL shouldExit = NO;
    
    //exit status
    int exitStatus = -1;
    
    //first thing...
    // ->install exception handlers!
    installExceptionHandlers();
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"applicationDidFinishLaunching: loaded in process %d as %d\n", getpid(), geteuid()]);
    
    //grab args
    arguments = NSProcessInfo.processInfo.arguments;
    
    //init IPC object
    interProcComms = [[InterProcComms alloc] init];
    
    //init contol object
    controlObj = [[Control alloc] init];
    
    //when launched w/ no args (e.g. user downloaded, then double-clicked) or -psn (lion VM, wtf?)
    // ->begin install (kick off auth'd self with 'install' flag)
    if( (0x1 == arguments.count) ||
        ( (0x2 == arguments.count) && (YES == [arguments[1] hasPrefix:@"-psn"]) ))
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: kicking off initial install...");
        
        //make foreground so it has an dock icon, etc
        transformProcess(kProcessTransformToForegroundApplication);
        
        //check if OS is supported
        if(YES != isSupportedOS())
        {
            //alloc error window
            errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];
            
            //display it
            // ->call this first to so that outlets are connected (not nil)
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:@{KEY_ERROR_MSG:@"ERROR: unsupported OS", KEY_ERROR_SUB_MSG: [NSString stringWithFormat:@"OS X %@ is not supported", [[NSProcessInfo processInfo] operatingSystemVersionString]], KEY_ERROR_SHOULD_EXIT:[NSNumber numberWithBool:YES]}];
             
            //bail
            // ->won't exit, since want user to see window, then click 'close'
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"OS version: %@ is supported", [[NSProcessInfo processInfo] operatingSystemVersionString]]);
        
        //display configure window w/ 'install' button
        // ->if user clicks 'install', install logic will begin
        [self displayConfigureWindow:[NSString stringWithFormat:@"Install BLOCKBLOCK (v. %@)", getVersion(VERSION_INSTANCE_SELF)] action:ACTION_INSTALL_FLAG];
    }
    
    //otherwise handle action
    // ->actions include: finalize (auth'd) install, run as daemon, run as agent (ui)
    else if(0x2 == arguments.count)
    {
        //INSTALL (auth'd)
        // ->install, then start both launch daemon && agent
        if(YES == [arguments[1] isEqualToString:ACTION_INSTALL])
        {
            //installer should always exit (at end of this function)
            shouldExit = YES;
            
            //dbg msg
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: installing (and starting) BLOCKBLOCK");
            
            //ui instance is calling waitpid
            // ->so briefly nap to give it time to enter that call...
            [NSThread sleepForTimeInterval:0.25f];
            
            //must be r00t
            if(0 != geteuid())
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: r00t is required for install");
            
                //bail
                goto bail;
            }
            
            //init install object
            installObj = [[Install alloc] init];
            
            //install
            // ->move into /Applications, create launch daemon and agent, etc
            if(YES != [installObj install])
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: installation failed");
                
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: installed BLOCKBLOCK");
            
            //dbg msg
            logMsg(LOG_DEBUG, @"now starting daemon & agent");
           
            //check if daemon needs to be started
            if(YES == installObj.shouldStartDaemon)
            {
                //start launch daemon
                if(YES != [controlObj startDaemon])
                {
                    //err msg
                    logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: starting BLOCKBLOCK (daemon) failed");
                    
                    //stop it
                    [controlObj stopDaemon];
                    
                    //bail
                    goto bail;
                }
            }
            
            //start all launch agents
            for(NSString* installedLaunchAgent in installObj.installedLaunchAgents)
            {
                //start launch agent
                if(YES != [controlObj startAgent:installedLaunchAgent])
                {
                    //err msg
                    logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: starting BLOCKBLOCK (agent) failed");
                    
                    //stop it
                    [controlObj stopAgent:installedLaunchAgent];
                    
                    //bail
                    goto bail;
                }
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: started BLOCKBLOCK");
            
            //since the launch agent sends a mouse click to the icon in the status bar
            // ->sleep a bit, so that can succeed (will keep the UI from saying install is done/the mouse click going to another process/icon)
            [NSThread sleepForTimeInterval:1.5f];
            
            //no errors
            exitStatus = STATUS_SUCCESS;
            
        }//install
        
        //DAEMON
        // ->check for root, then invoke function to exec daemon logic
        if(YES == [arguments[1] isEqualToString:ACTION_RUN_DAEMON])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: starting BLOCKBLOCK (daemon)");
            
            //must be r00t
            if(0 != geteuid())
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: r00t is required for block blocking (daemon)");
                
                //error, so exit
                shouldExit = YES;
                
                //bail
                goto bail;
            }
            
            //init dictionary for reported watch events
            reportedWatchEvents = [NSMutableDictionary dictionary];
            
            //init dictionary for orginal file contents
            orginals = [NSMutableDictionary dictionary];
            
            //and run daemon logic
            // ->shouldn't error, and if it does, not much we can do
            [self startBlockBlocking_Daemon];
            
            //no errors
            exitStatus = STATUS_SUCCESS;

        }//daemon
        
        //AGENT (UI)
        // ->invoke function to exec agent logic
        if(YES == [arguments[1] isEqualToString:ACTION_RUN_AGENT])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: starting BLOCKBLOCK (agent)");
            
            //after a minute
            //->check for updates in background
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
            {
               //check
               [self checkForUpdate];
            });
            
            //and run
            // ->shouldn't error
            [self startBlockBlocking_Agent];
            
            //no errors
            exitStatus = STATUS_SUCCESS;

        }//agent
        
        //UNINSTALL (UI)
        else if(YES == [arguments[1] isEqualToString:ACTION_UNINSTALL_UI])
        {
            //don't exit
            shouldExit = NO;
            
            //make foreground so it has an dock icon, etc
            transformProcess(kProcessTransformToForegroundApplication);
            
            //display configure window w/ 'install' button
            // ->if user clicks 'install', install logic will begin
            [self displayConfigureWindow:[NSString stringWithFormat:@"Uninstall BLOCKBLOCK (v. %@)", getVersion(VERSION_INSTANCE_SELF)] action:ACTION_UNINSTALL_FLAG];
            
            //no errors
            exitStatus = STATUS_SUCCESS;
            
        }//uninstall
        
        
        //UNINSTALL
        else if(YES == [arguments[1] isEqualToString:ACTION_UNINSTALL])
        {
            //should always exit
            shouldExit = YES;
            
            //dbg msg
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: uninstalling BLOCKBLOCK");
            
            //ui instance is calling waitpid
            // ->so briefly nap to give it time to enter that call...
            [NSThread sleepForTimeInterval:0.25f];
            
            //init uninstall
            // ->kick off uninstall logic
            if(YES != [self initUninstall])
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: failed to init uninstall");
                
                //bail
                goto bail;
            }
            
            //no errors
            exitStatus = STATUS_SUCCESS;
            
        }//uninstall (r00t)
        
        //invalid args
        else
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"%@ is an invalid argument", arguments[1]]);

            //bail
            goto bail;
            
        }
    }//2 args

//bail
bail:
    
    //check if process should exit
    if(YES == shouldExit)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"manually exiting %d", shouldExit]);
        
        //good bye!
        exit(exitStatus);
    }
    
    return;
}

//make the instance of the uninstall process foreground
// ->then show the 'configure' window (w/ 'uninstall' button)
-(BOOL)initUninstall
{
    //ret var
    BOOL bUninstalled = NO;
    
    //unistall obj
    Uninstall* uninstallObj = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: uninstalling BLOCKBLOCK");
    
    //must be r00t
    if(0 != geteuid())
    {
        //err msg
        logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: r00t is required for uninstall");
        
        //bail
        goto bail;
    }
    
    //init install object
    uninstallObj = [[Uninstall alloc] init];
    
    //install
    // ->move into /Applications, create launch daemon and agent, etc
    if(YES != [uninstallObj uninstall])
    {
        //err msg
        logMsg(LOG_ERR, @"applicationDidFinishLaunching: ERROR: uninstallation failed");
        
        //bail
        goto bail;
    }
    
    //no errors
    bUninstalled = YES;
    
//bail
bail:
    
    return bUninstalled;
}

//exec daemon logic
// ->init watchers/queue/etc and enable IPC
-(void)startBlockBlocking_Daemon
{
    //dbg msg
    logMsg(LOG_DEBUG, @"startBlockBlocking_Daemon: starting BLOCKBLOCK Daemon");
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current user: %@", getCurrentConsoleUser()]);
    
    //create/init watcher
    watcher = [[Watcher alloc] init];
    
    //init event queue
    eventQueue = [[Queue alloc] init];
    
    //enable IPC notifcation for daemon
    [interProcComms enableNotification:RUN_INSTANCE_DAEMON];
    
    //create/init process monitor
    processMonitor = [[ProcessMonitor alloc] init];
    
    //start monitoring processes
    [processMonitor monitor];
    
    //start file watching
    // ->monitors 'auto-run' locations
    [watcher watch];
    
    /* for testing exception handling
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
     
        //int a = getpid();
        //int b = 0;
        
        //printf("results: %d\n", a/b);
    
    
        //NSMutableArray *a = [NSMutableArray array];
        //[a addObject:nil];
        
    });
    */
    
    return;
}

//AGENT METHOD
//check for update
-(void)checkForUpdate
{
    //installed version
    NSString* installedVersion = nil;
    
    //version data
    NSData* versionData = nil;
    
    //version dictionary
    NSDictionary* versionDictionary = nil;
    
    //latest version
    NSString* latestVersion = nil;
    
    //get installed version
    installedVersion = getAppVersion();
    
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
    
    //sanity check
    if(nil == latestVersion)
    {
        //bail
        goto bail;
    }
    
    //check if available version is newer
    // ->show update window
    if(NSOrderedAscending == [installedVersion compare:latestVersion options:NSNumericSearch])
    {
        //new version!
        // ->show update popup on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //alloc/init about window
            infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
            
            //configure
            [self.infoWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available", latestVersion] buttonTitle:@"update"];
            
            //center window
            [[self.infoWindowController window] center];
            
            //show it
            [self.infoWindowController showWindow:self];
            
            
        });
    }
    
//bail
bail:
    
    return;
}

//AGENT METHOD
//exec agent logic
// ->init status bar and enable IPC
-(void)startBlockBlocking_Agent
{
    //dbg msg
    logMsg(LOG_DEBUG, @"startBlockBlocking_Agent: starting BLOCKBLOCK agent");
    
    //enable IPC notifcation for agent
    [self.interProcComms enableNotification:RUN_INSTANCE_AGENT];
    
    //setup status bar
    // ->makes icon appear, etc
    [self loadStatusBar];
    
    //register
    // ->delay to allow daemon to get up and running :)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^
    {
        //register agent
        [self.interProcComms registerAgent];
    });
    
    return;
}

//display configuration window to w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(NSString*)windowTitle action:(NSUInteger)action
{
    //configure window
    ConfigureWindowController* configureWindowController = nil;

    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //init window title
    //windowTitle = [NSString stringWithFormat:@"Uninstall BLOCKBLOCK (v. %@)", getVersion(VERSION_INSTANCE_SELF)];
    
    //display it
    // ->call this first to so that outlets are connected (not nil)
    [configureWindowController display];
    
    //configure it
    [configureWindowController configure:windowTitle action:action];
    
    return;
}

//initialize status menu bar
-(void)loadStatusBar
{
    //contents of launch agent's plist
    // ->determines if popup should be shown
    NSMutableDictionary* plistContents = nil;
    
    //alloc/load nib
    self.statusBarMenuController = [[StatusBarMenu alloc] initWithWindowNibName:@"StatusBarMenu"];
    
    //ensure outlet connections are made (e.g. not NULL)
    [self.statusBarMenuController showWindow:self];
    
    //configure
    [self.statusBarMenuController configure];
    
    //get contents of 'Info.plist'
    plistContents = [NSMutableDictionary dictionaryWithContentsOfFile:launchAgentPlist(NSHomeDirectory())];
    
    //check if 'first time run' key is set
    // ->then automatically show popup, and update key (so not shown again)
    if( (nil != plistContents) &&
        (nil == plistContents[IS_FIRST_RUN]) )
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"first time! showing popup");
        
        //automatically show popover
        // ->after 1 second
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //show
            [self.statusBarMenuController showPopover];
        });
        
        //automatically hide popup if user has not
        // ->after 5 seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
           //hide
           [self.statusBarMenuController hidePopover];
        });
        
        //set key
        plistContents[IS_FIRST_RUN] = @"NO";
        
        //save to disk
        [plistContents writeToFile:launchAgentPlist(NSHomeDirectory()) atomically:YES];
        
    }
    //not the first time
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"not first time");
        
        //init menu
        [self.statusBarMenuController initMenu];
    }
    
    return;
}

@end
