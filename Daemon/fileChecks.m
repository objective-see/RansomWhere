//
//  fileChecks.c
//  Daemon
//
//  Created by Patrick Wardle on 1/21/26.
//  Copyright © 2026 Objective-See. All rights reserved.
//

@import OSLog;

#import "fileChecks.h"
#import "3rdParty/ent/ent.h"

//log handle
extern os_log_t logHandle;

//determine if a file is encrypted
// ->high entropy and
//   a) very low pi error
//   b) low pi error and low chi square
BOOL isEncrypted(NSString* path)
{
    //flag
    BOOL encrypted = NO;
    
    //test results
    NSMutableDictionary* results = nil;
    
    //do computations
    // ->entropy, chi square, and monte carlo pi error
    results = testFile(path);
    if(nil == results)
    {
        //bail
        goto bail;
    }

    //dbg msg
    #ifdef DEBUG
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"encryption results for %@: %@", path, results]);
    #endif
    
    //ignore image files
    // ->looks for well known headers at start of file
    if( (nil != results[@"header"]) &&
        (YES == isImage(results[@"header"])) )
    {
        #ifdef DEBUG
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"file is an image; %#x", *(unsigned int*)[results[@"header"] bytes]]);
        #endif
        
        //ignore
        goto bail;
    }
    
    //ignore gzipped files
    // tar/gz doesn't support password protect, so can't be abused
    if( (nil != results[@"header"]) &&
        (YES == isGzip(results[@"header"])) )
    {
        #ifdef DEBUG
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"file is an gz; %#x", *(unsigned int*)[results[@"header"] bytes]]);
        #endif
        
        //ignore
        goto bail;
    }
    
    //encrypted files have super high entropy
    // ->so ignore files that have 'low' entropy
    if([results[@"entropy"] doubleValue] < 7.95)
    {
        //ignore
        goto bail;
    }
    
    //monte carlo pi error gotta be less than 1.5%
    if([results[@"montecarlo"] doubleValue] > 1.5)
    {
        //ignore
        goto bail;
    }
    
    //when monte carlo pi error is above 0.5
    // ->gotta have low chi square as well
    if( ([results[@"montecarlo"] doubleValue] > 0.5) &&
        ([results[@"chisquare"] doubleValue] > 400) )
    {
        //ignore
        goto bail;
    }
    
    //encrypted file!
    // file as very low pi error, or, lowish pi error *and* low chi square
    encrypted = YES;
   
//bail
bail:
    
    //TODO: remove
    os_log_debug(logHandle, "isEncrypted %{public}@: entropy=%{public}@ chi=%{public}@ pi=%{public}@ header=%{public}@",
        path, results[@"entropy"], results[@"chisquare"], results[@"montecarlo"],
        results[@"header"] ? @"yes" : @"no");
    

    return encrypted;
}

//examines header for image signatures (e.g. 'GIF87a')
// ->see: https://en.wikipedia.org/wiki/List_of_file_signatures for image signatures
BOOL isImage(NSData* header) {

    //first 4 bytes
    unsigned int magic = *(unsigned int*)header.bytes;
    
    //check for magic (4-byte) header values
    if( (MAGIC_PNG == magic) ||
        (MAGIC_JPG == magic) ||
        (MAGIC_JPEG == magic) ||
        (MAGIC_GIF == magic) ||
        (MAGIC_ICNS == magic) ||
        (MAGIC_TIFF == magic) )
    {
        return YES;
    }
    
    return NO;
}


//examines header for gzip signature
// ->for gzip, this is 0x1f 0x8b 0x08
BOOL isGzip(NSData* header) {

    //first 3 bytes
    unsigned char* magic = (unsigned char*)header.bytes;
    
    //check for magic header value
    if( (magic[0] == 0x1F) &&
        (magic[1] == 0x8B) &&
        (magic[2] == 0x08) )
    {
        return YES;
    }
    
    return NO;
}
