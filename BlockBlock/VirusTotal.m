//
//  VirusTotal.m
//  BlockBlock
//
//  Created by Patrick Wardle on 3/8/15.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "VirusTotal.h"
#import "AppDelegate.h"

@implementation VirusTotal

//thread function
// ->runs in the background to get virus total info about items
-(void)queryVT:(NSString*)type items:(NSMutableArray*)items
{
    //file attributes
    NSDictionary* attributes = nil;
    
    //item data
    NSMutableDictionary* itemData = nil;
    
    //VT query URL
    NSURL* queryURL = nil;
    
    //results
    NSDictionary* results = nil;

    //alloc list for items
    items = [NSMutableArray array];
    
    //init query URL
    queryURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", VT_QUERY_URL, VT_API_KEY]];
    
    //iterate over all hashes
    // ->create item dictionary (JSON), and add it to list
    for(NSMutableDictionary* item in items)
    {
        //alloc item data
        itemData = [NSMutableDictionary dictionary];
        
        //get file attributes
        attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:item[@"path"] error:nil];
        
        //auto start location
        itemData[@"autostart_location"] = type;
        
        //set item name
        itemData[@"autostart_entry"] = [[item[@"path"] lastPathComponent] stringByDeletingPathExtension];
        
        //set item path
        itemData[@"image_path"] = item[@"path"];
        
        //set hash
        itemData[@"hash"] = item[@"hash"];
        
        //set creation time
        if(nil != attributes)
        {
            //set
            itemData[@"creation_datetime"] = [attributes objectForKey:NSFileCreationDate];
        }
        //set unknown
        else
        {
            itemData[@"creation_datetime"] = @"unknown";
        }
        
        //add item info to list
        [items addObject:itemData];
    }
    
    //make query to VT
    results = [self postRequest:queryURL parameters:items];
    if(nil != results)
    {
        //process results
        [self processResults:items results:results];
    }
    
    return;
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
            postData = [NSJSONSerialization dataWithJSONObject:params options:kNilOptions error:nil];
            if(nil == postData)
            {
                //err msg
                NSLog(@"OBJECTIVE-SEE ERROR: failed to convert request %@ to JSON", postData);
                
                //bail
                goto bail;
            }
            
        }
        //bail on exceptions
        @catch(NSException *exception)
        {
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
        NSLog(@"OBJECTIVE-SEE ERROR: failed to query VirusTotal (%@, %@)", error, httpResponse);
        
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
        NSLog(@"OBJECTIVE-SEE ERROR: converting response %@ to JSON threw %@", vtData, exception);
        
        //bail
        goto bail;
    }
    
    //sanity check
    if(nil == results)
    {
        //err msg
        NSLog(@"OBJECTIVE-SEE ERROR: failed to convert response %@ to JSON", vtData);
        
        //bail
        goto bail;
    }
    
//bail
bail:
    
    return results;
}



//process results
// ->save VT info into each File obj and all flagged files
-(void)processResults:(NSArray*)items results:(NSDictionary*)results
{
    //process all results
    // ->save VT result dictionary into File obj
    for(NSDictionary* result in results[VT_RESULTS])
    {
        //find all items that match
        // ->might be dupes, which is fine
        for(NSMutableDictionary* item in items)
        {
            
            //for matches, save vt info
            if(YES == [result[@"hash"] isEqualToString:item[@"hash"]])
            {
                //save
                item[@"vtInfo"] = result;
                
            }
        }
        
    }
    
    return;
}

@end
