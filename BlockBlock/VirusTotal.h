//
//  VirusTotal.h
//  BlockBlock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

//query url
#define VT_QUERY_URL @"https://www.virustotal.com/partners/sysinternals/file-reports?apikey="

//requery url
#define VT_REQUERY_URL @"https://www.virustotal.com/vtapi/v2/file/report"

//rescan url
#define VT_RESCAN_URL @"https://www.virustotal.com/vtapi/v2/file/rescan"

//submit url
#define VT_SUBMIT_URL @"https://www.virustotal.com/vtapi/v2/file/scan"

//api key
#define VT_API_KEY @"233f22e200ca5822bd91103043ccac138b910db79f29af5616a9afe8b6f215ad"

//user agent
#define VT_USER_AGENT @"VirusTotal"

//query count
#define VT_MAX_QUERY_COUNT 25

//results
#define VT_RESULTS @"data"

//results response code
#define VT_RESULTS_RESPONSE @"response_code"

//result url
#define VT_RESULTS_URL @"permalink"

//result hash
#define VT_RESULT_HASH @"hash"

//results positives
#define VT_RESULTS_POSITIVES @"positives"

//results total
#define VT_RESULTS_TOTAL @"total"

//results scan id
#define VT_RESULTS_SCANID @"scan_id"



@interface VirusTotal : NSObject
{
    
}

/* METHODS */

//thread function
// ->runs in the background to get virus total info about a plugin's items
-(BOOL)queryVT:(NSString*)type items:(NSMutableArray*)items;

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url parameters:(id)params;

@end
