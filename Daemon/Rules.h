//
//  file: Rules.h
//  project: RansomWhere? (launch daemon)
//  description: handles rules & actions such as add/delete (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//


#ifndef Rules_h
#define Rules_h

#import "consts.h"

@import OSLog;
@import Foundation;

@class Rule;

@interface Rules : NSObject {
    
}

/* PROPERTIES */

@property(nonatomic, retain)NSMutableDictionary* rules;


/* METHODS */

-(BOOL)load;
-(BOOL)save;
-(BOOL)delete:(NSString*)path;
-(NSInteger)find:(NSString*)path;
-(BOOL)add:(NSString*)key action:(NSNumber*)action;

@end

#endif /* Rules_h */
