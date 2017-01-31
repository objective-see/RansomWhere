//
//  VirusTotal.m
//  BlockBlock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "VirusTotal.h"
#import "AppDelegate.h"

@implementation VirusTotal

//thread function
// ->runs in the background to get virus total info about items
-(BOOL)queryVT:(NSString*)type items:(NSMutableArray*)items
{
    //flag
    BOOL gotResponse = NO;
    
    //file attributes
    NSDictionary* attributes = nil;
    
    //item data
    NSMutableDictionary* itemData = nil;
    
    //list of vt items
    NSMutableArray* vtItems = nil;
    
    //VT query URL
    NSURL* queryURL = nil;
    
    //vt response
    NSDictionary* response = nil;
    
    //alloc
    vtItems = [NSMutableArray array];

    //init query URL
    queryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", VT_QUERY_URL, VT_API_KEY]];
    
    //iterate over all hashes
    // ->create item dictionary (JSON), and add it to list
    for(NSMutableDictionary* item in items)
    {
        //alloc item data
        itemData = [NSMutableDictionary dictionary];
        
        //sanity check
        if( (nil == item[@"path"]) ||
            (nil == item[@"name"]) ||
            (nil == item[@"hash"]) )
        {
            //ignore
            continue;
        }
        
        //get file attributes
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:item[@"path"] error:nil];
        
        //auto start location
        itemData[@"autostart_location"] = type;
        
        //set item name
        itemData[@"autostart_entry"] = item[@"name"];
        
        //set item path
        itemData[@"image_path"] = item[@"path"];
        
        //set hash
        itemData[@"hash"] = item[@"hash"];
        
        //set creation time
        if(nil != attributes)
        {
            //set
            itemData[@"creation_datetime"] = attributes.fileCreationDate.description;
        }
        //set unknown
        else
        {
            //set
            itemData[@"creation_datetime"] = @"unknown";
        }
        
        //add item info to list
        [vtItems addObject:itemData];
    }
    
    //make query to VT
    response = [self postRequest:queryURL parameters:vtItems];
    if(nil == response)
    {
        //bail
        goto bail;
    }
    
    //got response
    gotResponse = YES;
    
    //process all results
    // ->save VT result dictionary into item
    for(NSDictionary* result in response[VT_RESULTS])
    {
        //find all items that match
        for(NSMutableDictionary* item in items)
        {
            //for matches, save vt info
            if(YES == [result[@"hash"] isEqualToString:item[@"hash"]])
            {
                //save
                item[@"vtInfo"] = result;
                
                //next
                break;
            }
        }
    }
    
//bail:
bail:
    
    return gotResponse;
}

//make the (POST)query to VT
-(NSDictionary*)postRequest:(NSURL*)url parameters:(id)params
{
    //results
    NSDictionary* results = nil;
    
    //request
    NSMutableURLRequest *request = nil;
    
    //post data
    // ->JSON'd items
    NSData* postData = nil;
    
    //error var
    NSError* error = nil;
    
    //data from VT
    NSData* vtData = nil;
    
    //response (HTTP) from VT
    NSURLResponse* httpResponse = nil;

    //alloc/init request
    request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    //set user agent
    [request setValue:VT_USER_AGENT forHTTPHeaderField:@"User-Agent"];
    
    //serialize JSON
    if(nil != params)
    {
        //convert items to JSON'd data for POST request
        // ->wrap since we are serializing JSON
        @try
        {
            //convert items
            postData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:&error];
            if(nil == postData)
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to convert paramters %@, to JSON (%@)", params, error]);
                
                //bail
                goto bail;
            }
            
        }
        //bail on exceptions
        @catch(NSException *exception)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to convert paramters %@, to JSON (%@)", params, exception]);
            
            //bail
            goto bail;
        }
        
        //set content type
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        //set content length
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-length"];
        
        //add POST data
        [request setHTTPBody:postData];
    }
    
    //set method type
    [request setHTTPMethod:@"POST"];
    
    //send request
    // ->synchronous, so will block
    vtData = [NSURLConnection sendSynchronousRequest:request returningResponse:&httpResponse error:&error];
    
    //sanity check(s)
    if( (nil == vtData) ||
        (nil != error) ||
        (200 != (long)[(NSHTTPURLResponse *)httpResponse statusCode]) )
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to query VirusTotal (%@, %@)", error, httpResponse]);
    
        //bail
        goto bail;
    }
    
    //serialize response into NSData obj
    // ->wrap since we are serializing JSON
    @try
    {
        //serialized
        results = [NSJSONSerialization JSONObjectWithData:vtData options:kNilOptions error:nil];
    }
    //bail on any exceptions
    @catch (NSException *exception)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"converting response %@ to JSON threw %@", vtData, exception]);
        
        //bail
        goto bail;
    }
    
    //sanity check
    if(nil == results)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to convert response %@ to JSON", vtData]);
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return results;
}

@end
