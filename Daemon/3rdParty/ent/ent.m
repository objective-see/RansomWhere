/*
	ENT  --  Entropy calculation and analysis of putative
		 random sequences.

        Designed and implemented by John "Random" Walker in May 1985.

	Multiple analyses of random sequences added in December 1985.

	Bit stream analysis added in September 1997.

	Terse mode output, getopt() command line processing,
	optional stdin input, and HTML documentation added in
	October 1998.
	
	Documentation for the -t (terse output) option added
	in July 2006.
	
	Replaced table look-up for chi square to probability
	conversion with algorithmic computation in January 2008.

	For additional information and the latest version,
	see http://www.fourmilab.ch/random/

*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <unistd.h>

#include "Consts.h"
#include "iso8859.h"
#include "randtest.h"

#import <Foundation/Foundation.h>

#define UPDATE  "January 28th, 2008"

#define FALSE 0
#define TRUE  1

#ifdef M_PI
#define PI	 M_PI
#else
#define PI	 3.14159265358979323846
#endif

extern double pochisq(const double ax, const int df);

//3 MB
#define READ_CHUNK 1024*1024*3

//test a file
// ->return a dictionary w/ entropy, chi square, and monte carlo pi 'error'
NSMutableDictionary* testFile(NSString* file)
{
    //test results
    NSMutableDictionary* results = nil;
    
    //file handle
    NSFileHandle *handle = nil;
    
    //file bytes
    NSData* fileData = nil;
    
    //file bytes
    const char* fileBytes = nil;
    
    //length
    NSUInteger length = 0;
    
    //entropy
    double ent = 0.0;
    
    //monte carlo pi
    double montepi = 0.0;
    
    //chi square
    double chisq = 0.0;
    
    //alloc dictionary
    results = [NSMutableDictionary dictionary];
    
    //init file handle
    handle = [NSFileHandle fileHandleForReadingAtPath:file];
    if(nil == handle)
    {
        //bail
        goto bail;
    }
    
    //read in up to 3MB of file
    fileData = [handle readDataOfLength:READ_CHUNK];
    if(nil == fileData)
    {
        //bail
        goto bail;
    }
    
    //grab bytes
    fileBytes = fileData.bytes;
    
    //get length
    length = fileData.length;
    
    //do rand tests
    // ->combined thread safe function
    rt_combo((void*)fileBytes, (int)length, &ent, &chisq, &montepi);
    
    //save entropy
    results[@"entropy"] = [NSNumber numberWithDouble:ent];
    
    //save chi square
    results[@"chisquare"] = [NSNumber numberWithDouble:chisq];
    
    //save monto carlo pi error
    results[@"montecarlo"] = [NSNumber numberWithDouble:100.0 * (fabs(PI - montepi) / PI)];
    
    //save bytes at start of file
    if(length > HEADER_SIZE)
    {
        //save
        results[@"header"] = [NSData dataWithBytes:fileBytes length:HEADER_SIZE];
    }

    /*
	printf("\nEntropy = %f bits per bytes\n", ent);
    printf("Chi square distribution is %1.2f\n", chisq);
    printf("Monte Carlo value for Pi is %1.9f (error %1.2f percent)\n\n", montepi, 100.0 * (fabs(PI - montepi) / PI));
    */
   
//bail
bail:
    
    //close handle
    if(nil != handle)
    {
        //close
        [handle closeFile];
        
        //unset
        handle = nil;
    }
    
	return results;
}
