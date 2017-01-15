//
//  AppDelegate.m
//  BlockBlock
//
//  Created by Patrick Wardle on 8/27/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Install.h"
#import "Control.h"
#import "Watcher.h"
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
@synthesize whiteList;
@synthesize controlObj;
@synthesize eventQueue;
@synthesize interProcComms;
@synthesize processMonitor;
@synthesize reportedWatchEvents;
@synthesize infoWindowController;
@synthesize errorWindowController;
@synthesize prefsWindowController;
@synthesize rememberedWatchEvents;
@synthesize statusBarMenuController;


//for testing
//@synthesize alertWindowController;


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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"applicationDidFinishLaunching: loaded in process %d as %d\n", getpid(), geteuid()]);
    #endif
    
    /* BEGIN: FOR TESTING ALERT WINDOW */
    /*
    
    //alloc/init
    alertWindowController = [[AlertWindowController alloc] initWithWindowNibName:@"AlertWindowController"];
    
    //configure alert window with data from daemon
    [alertWindowController configure:nil];
    
    alertWindowController.processHierarchy = @[@{@"name":@"1", @"index":@0, @"pid":@1},@{@"name":@"2", @"index":@1, @"pid":@2}, @{@"name":@"osxMalware", @"index":@2, @"pid":@74090}];
    
    //show (now configured), alert
    [alertWindowController showWindow:self];
    
    //center window
    [alertWindowController.window center];
    
    //make it key window
    [self.alertWindowController.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
    */
    
    /* END: FOR TESTING ALERT WINDOW */

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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: kicking off initial install...");
        #endif
        
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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"OS version: %@ is supported", [[NSProcessInfo processInfo] operatingSystemVersionString]]);
        #endif
        
        //display configure window w/ 'install' button
        // ->if user clicks 'install', install logic will begin
        [self displayConfigureWindow];
    }
    
    //otherwise handle action
    // ->actions include: finalize (auth'd) install, run as daemon, run as agent (ui)
    else if(0x2 == arguments.count)
    {
        //INSTALL (auth'd)
        // ->install, then start both launch daemon && agent
        if( (YES == [arguments[1] isEqualToString:ACTION_INSTALL]) ||
            (YES == [arguments[1] isEqualToString:CMD_INSTALL]) )
        {
            //installer should always exit (at end of this function)
            shouldExit = YES;
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: installing (and starting) BLOCKBLOCK");
            #endif
            
            //ui instance is calling waitpid
            // ->so briefly nap to give it time to enter that call...
            [NSThread sleepForTimeInterval:0.25f];
            
            //must be r00t
            if(0 != geteuid())
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching, r00t is required for install");
                
                //printf err if cmdline
                if(YES == [arguments[1] isEqualToString:CMD_INSTALL])
                {
                    //err msg
                    printf("ERROR: must be run as r00t to install\n\n");
                }
            
                //bail
                goto bail;
            }
            
            //init install object
            installObj = [[Install alloc] init];
            
            //install
            // ->move into /Library/BlockBlock, create launch daemon and agent, etc
            if(YES != [installObj install])
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching, installation failed");
                
                //printf() err if cmdline
                if(YES == [arguments[1] isEqualToString:CMD_INSTALL])
                {
                    //err msg
                    printf("ERROR: installation failed\n\n");
                }
                
                //bail
                goto bail;
            }
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: installed BLOCKBLOCK, now will start!");
            #endif
            
            //start launch daemon
            if(YES != [controlObj startDaemon])
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching, starting BLOCKBLOCK (daemon) failed");
                
                //printf() err if cmdline
                if(YES == [arguments[1] isEqualToString:CMD_INSTALL])
                {
                    //err msg
                    printf("ERROR: failed to start launch daemon\n\n");
                }
                
                //bail
                goto bail;
            }
            
            //start all launch agents
            for(NSDictionary* installedLaunchAgent in [Install existingLaunchAgents])
            {
                //start launch agent
                if(YES != [controlObj startAgent:installedLaunchAgent[@"plist"] uid:installedLaunchAgent[@"uid"]])
                {
                    //err msg
                    logMsg(LOG_ERR, @"applicationDidFinishLaunching, starting BLOCKBLOCK (agent) failed");
                    
                    //printf() err if cmdline
                    if(YES == [arguments[1] isEqualToString:CMD_INSTALL])
                    {
                        //err msg
                        printf("ERROR: failed to start launch agent\n\n");
                    }
                    
                    //bail
                    goto bail;
                }
            }
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: started BLOCKBLOCK");
            #endif
            
            //printf() if cmdline
            if(YES == [arguments[1] isEqualToString:CMD_INSTALL])
            {
                //dbg msg
                printf("installed BLOCKBLOCK\n");
            }
            
            //no errors
            exitStatus = STATUS_SUCCESS;
            
        }//install
        
        //DAEMON
        // ->check for root, then invoke function to exec daemon logic
        else if(YES == [arguments[1] isEqualToString:ACTION_RUN_DAEMON])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: starting BLOCKBLOCK (daemon)");
            #endif
            
            //must be r00t
            if(0 != geteuid())
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching, r00t is required for block blocking (daemon)");
                
                //error, so exit
                shouldExit = YES;
                
                //bail
                goto bail;
            }
            
            //init dictionary for reported watch events
            reportedWatchEvents = [NSMutableDictionary dictionary];
            
            //load white-list
            whiteList = [NSMutableArray arrayWithContentsOfFile:WHITE_LIST_FILE];
            
            //init list for 'remembered' watch events
            rememberedWatchEvents = [NSMutableArray array];
            
            //init dictionary for orginal file contents
            orginals = [NSMutableDictionary dictionary];
            
            //load kext
            if(YES != [self.controlObj startKext])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"applicationDidFinishLaunching, failed to start %@", kextPath()]);
                
                //error, so exit
                shouldExit = YES;
                
                //bail
                goto bail;
            }
            
            //and run daemon logic
            // ->shouldn't error, and if it does, not much we can do
            [self startBlockBlocking_Daemon];
            
            //no errors
            exitStatus = STATUS_SUCCESS;

        }//daemon
        
        //AGENT (UI)
        // ->invoke function to exec agent logic
        else if(YES == [arguments[1] isEqualToString:ACTION_RUN_AGENT])
        {
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: starting BLOCKBLOCK (agent)");
            #endif
            
            //alloc/init prefs
            prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"PrefsWindow"];
            
            //register defaults
            [self.prefsWindowController registerDefaults];
            
            //load prefs
            [self.prefsWindowController loadPreferences];

            //check for updates
            // ->but only when user has not disabled that feature
            if(YES != self.prefsWindowController.disableUpdateCheck)
            {
                //after a minute
                //->check for updates in background
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
                {
                    //dbg msg
                    #ifdef DEBUG
                    logMsg(LOG_DEBUG, @"checking for update");
                    #endif
                    
                    //check
                    [self checkForUpdate];
                });
            }
            
            //when logging is enabled
            // ->open/create log file
            if(YES == self.prefsWindowController.enableLogging)
            {
                //init
                if(YES != initLogging())
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to init logging");
                }
            }
            
            //dbg log
            // ->and to file (if logging is enabled)
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"BlockBlock Agent initializing...");

            //and run
            // ->shouldn't error
            [self startBlockBlocking_Agent];
            
            //no errors
            exitStatus = STATUS_SUCCESS;

        }//agent
        
        //UNINSTALL (UI)
        // ->just show 'uninstall BlockBlock' window
        else if(YES == [arguments[1] isEqualToString:ACTION_UNINSTALL_UI])
        {
            //don't exit
            shouldExit = NO;
            
            //make foreground so it has an dock icon, etc
            transformProcess(kProcessTransformToForegroundApplication);
            
            //display configure window w/ 'install' button
            // ->if user clicks 'install', install logic will begin
            [self displayConfigureWindow];
            
            //no errors
            exitStatus = STATUS_SUCCESS;
            
        }//uninstall (UI)
        
        //UNINSTALL (auth'd)
        else if( (YES == [arguments[1] isEqualToString:ACTION_UNINSTALL]) ||
                 (YES == [arguments[1] isEqualToString:CMD_UNINSTALL]) )
        {
            //should always exit
            shouldExit = YES;
            
            //dbg msg
            #ifdef DEBUG
            logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: uninstalling BLOCKBLOCK");
            #endif
            
            //ui instance is calling waitpid
            // ->so briefly nap to give it time to enter that call...
            if(YES != [arguments[1] isEqualToString:CMD_UNINSTALL])
            {
                //sleep
                [NSThread sleepForTimeInterval:0.25f];
            }
        
            //init uninstall
            // ->kick off uninstall logic
            if(YES != [self initUninstall])
            {
                //err msg
                logMsg(LOG_ERR, @"applicationDidFinishLaunching, failed to init uninstall");
                
                //printf() err if cmdline
                if(YES == [arguments[1] isEqualToString:CMD_UNINSTALL])
                {
                    //err msg
                    printf("ERROR: failed to stop/uninstall BLOCKBLOCK\n");
                }
                
                //bail
                goto bail;
            }
            
            //printf() if cmdline
            else if(YES == [arguments[1] isEqualToString:CMD_UNINSTALL])
            {
                //dmg msg
                printf("uninstalled BLOCKBLOCK\n");
            }
            
            //no errors
            exitStatus = STATUS_SUCCESS;
            
        }//uninstall (r00t)
        
        //invalid args
        else
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"%@ is an invalid argument", arguments[1]]);
            
            //should always exit
            shouldExit = YES;

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
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"manually exiting %d", shouldExit]);
        #endif
        
        //good bye!
        exit(exitStatus);
    }
    
    return;
}

//init uninstall object
// ->then invoke uninstall logic
-(BOOL)initUninstall
{
    //ret var
    BOOL bUninstalled = NO;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"applicationDidFinishLaunching: uninstalling BLOCKBLOCK");
    #endif
    
    //must be r00t
    if(0 != geteuid())
    {
        //err msg
        logMsg(LOG_ERR, @"applicationDidFinishLaunching, r00t is required for uninstall");
        
        //bail
        goto bail;
    }
    
    //uninstall
    // ->pass in no, saying this wasn't invoked via installer 
    if(YES != [[[Uninstall alloc] init] uninstall:NO])
    {
        //err msg
        logMsg(LOG_ERR, @"applicationDidFinishLaunching, uninstallation failed");
        
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
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"startBlockBlocking_Daemon: starting BLOCKBLOCK Daemon");
    #endif
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current user: %@", getCurrentConsoleUser()]);
    #endif
    
    //create/init watcher
    watcher = [[Watcher alloc] init];
    
    //init event queue
    eventQueue = [[Queue alloc] init];
    
    //load white-list item
    self.whiteList = [NSMutableArray arrayWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:WHITE_LIST_FILE]];
    if(nil == self.whiteList)
    {
        //no items yet
        whiteList = [NSMutableArray array];
    }
    
    //enable IPC notification for daemon
    [interProcComms enableNotification:RUN_INSTANCE_DAEMON];
    
    //create/init process monitor
    processMonitor = [[ProcessMonitor alloc] init];
    
    //start monitoring processes
    // ->loads kext and record process creation events
    [processMonitor monitor];
    
    //start file watching
    // ->monitors 'auto-run' locations
    [watcher watch];
    
    return;
}

//AGENT METHOD
// ->check for update
-(void)checkForUpdate
{
    //version string
    NSMutableString* versionString = nil;
    
    //alloc string
    versionString = [NSMutableString string];
    
    //check if available version is newer
    // ->show update window
    if(YES == isNewVersion(versionString))
    {
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", versionString]);
        #endif
        
        //new version!
        // ->show update popup on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //alloc/init about window
            infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
            
            //configure
            [self.infoWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", versionString] buttonTitle:@"update"];
            
            //center window
            [[self.infoWindowController window] center];
            
            //show it
            [self.infoWindowController showWindow:self];
            
        });
    }

    //no new version
    // ->just (debug) log msg
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no updates available");
    }
    
    return;
}

//AGENT METHOD
//exec agent logic
// ->init status bar and enable IPC
-(void)startBlockBlocking_Agent
{
    //current user
    NSDictionary* currentUser = nil;
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"startBlockBlocking_Agent: starting BLOCKBLOCK agent");
    #endif
    
    //wait till user logs in
    // ->otherwise bad things happen when trying to connect to the window server/status bar
    do
    {
        //get current user
        currentUser = getCurrentConsoleUser();
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"current user: %@", currentUser]);
        #endif
        
        //wait till target user is logged in
        if( (nil != currentUser) &&
            (getuid() == [currentUser[@"uid"] unsignedIntValue]) )
        {
            //yay
            break;
        }
        
        //dbg msg
        #ifdef DEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"waiting for user to log in: %d vs %d", [currentUser[@"uid"] unsignedIntValue], getuid()]);
        #endif
        
        //nap for 5 seconds
        [NSThread sleepForTimeInterval:5.0f];
        
    } while(YES);
    
    //dbg msg
    #ifdef DEBUG
    logMsg(LOG_DEBUG, @"user logged in/UI session ok!");
    #endif
    
    //enable IPC notification for agent
    [self.interProcComms enableNotification:RUN_INSTANCE_AGENT];
    
    //setup status bar
    // ->makes icon appear, etc
    [self loadStatusBar];
    
    //register
    // ->delay to allow daemon to get up and running :)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^
    {
        //register agent
        [self.interProcComms registerAgent];
    });
    
    return;
}

//display configuration window
-(void)displayConfigureWindow
{
    //configure window
    ConfigureWindowController* configureWindowController = nil;

    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //display it
    // ->call this first to so that outlets are connected (not nil)
    [configureWindowController display];
    
    return;
}

//initialize status menu bar
-(void)loadStatusBar
{
    //alloc/load nib
    statusBarMenuController = [[StatusBarMenu alloc] init];

    //init menu
    [self.statusBarMenuController setupStatusItem];
    
    return;
}

@end
