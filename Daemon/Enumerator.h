//
//  Enumerator.h
//  Daemon
//
//  Created by Patrick Wardle on 5/22/16.
//  Copyright © 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Enumerator : NSObject
{
    
}

/* PROPERTIES */

//enumerated binaries that need to be processes
@property(nonatomic, retain)NSMutableDictionary* bins2Process;

//processed binaries
@property(nonatomic, retain)NSMutableDictionary* binaryList;

//flag indicating processing is complete
@property BOOL processingComplete;

/* METHODS */

//enumerate all baselined/approved/running binaries
// ->adds/classfies them into bins2Process dictionary
-(void)enumerateBinaries;

//load list of apps installed at time of baseline
// ->first time; generate them (this might take a while)
-(BOOL)enumBaselinedApps;

//load all (persistent) 'user-approved' binaries
-(BOOL)enumApprovedBins;

//enumerate all currently running processes
-(BOOL)enumRunningProcs;

//generate binary object for all enumerated bins
// ->this is slow and CPU intensives, so run in background thread!
-(void)processBinaries;

@end
