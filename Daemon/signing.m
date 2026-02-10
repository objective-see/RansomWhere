//
//  File: Signing.m
//  Project: RansomWhere
//
//  Created by: Patrick Wardle
//  Copyright:  2026 Objective-See
//

#import "consts.h"
#import "signing.h"
#import "utilities.h"

#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>

//get the signing info of a process (dynamic)
NSMutableDictionary* generateSigningInfo(Process* process)
{
    //status
    OSStatus status = !errSecSuccess;
    
    //info dictionary
    NSMutableDictionary* signingInfo = nil;
    
    //signing details
    CFDictionaryRef signingDetails = NULL;
    
    //signing authorities
    NSMutableArray* signingAuths = nil;
    
    //init signing status
    signingInfo = [NSMutableDictionary dictionary];
    
    //start with dynamic cs check
    signingDetails = dynamicCodeCheck(process.auditToken, signingInfo);
        
    //extract status
    status = [signingInfo[KEY_SIGNATURE_STATUS] intValue];
    
    //bail on any signing error(s)
    if(errSecSuccess != [signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //bail
        goto bail;
    }
    
    //extract code signing id
    if(nil != [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoIdentifier])
    {
        //extract/save
        signingInfo[KEY_SIGNATURE_IDENTIFIER] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoIdentifier];
    }
    
    //extract team signing id
    if(nil != [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoTeamIdentifier])
    {
        //extract/save
        signingInfo[KEY_SIGNATURE_TEAM_IDENTIFIER] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoTeamIdentifier];
    }
    
    //extract signing authorities
    signingAuths = extractSigningAuths((__bridge NSDictionary *)(signingDetails));
    if(0 != signingAuths.count)
    {
        //save
        signingInfo[KEY_SIGNATURE_AUTHORITIES] = signingAuths;
    }
    
bail:
    
    //free signing info
    if(NULL != signingDetails)
    {
        //free
        CFRelease(signingDetails);
        
        //unset
        signingDetails = NULL;
    }
    
    return signingInfo;
}

//extract signing info/check via dynamic code ref (process auth token)
CFDictionaryRef dynamicCodeCheck(NSData* auditToken, NSMutableDictionary* signingInfo)
{
    //status
    OSStatus status = !errSecSuccess;
    
    //dynamic code ref
    SecCodeRef dynamicCode = NULL;
    
    //signing details
    CFDictionaryRef signingDetails = NULL;
    
    //obtain dynamic code ref from (audit) token
    status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit:auditToken}), kSecCSDefaultFlags, &dynamicCode);
    if(errSecSuccess != status)
    {
        //set error
        signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
        //bail
        goto bail;
    }
    
    //validate code
    status = SecCodeCheckValidity(dynamicCode, kSecCSDefaultFlags, NULL);
    if(errSecSuccess != status)
    {
        //set error
        signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
        
        //bail
        goto bail;
    }
    
    //happily signed
    signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecSuccess];
    
    //extract signing info
    status = SecCodeCopySigningInformation(dynamicCode, kSecCSSigningInformation, &signingDetails);
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //cs flags
    signingInfo[KEY_SIGNING_FLAGS] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoStatus];
    
    //determine signer
    // apple, app store, dev id, adhoc, etc...
    signingInfo[KEY_SIGNATURE_SIGNER] = extractSigner(dynamicCode, signingInfo[KEY_SIGNING_FLAGS]);
        
    //set notarization status
    signingInfo[KEY_SIGNING_IS_NOTARIZED] = [NSNumber numberWithBool:isNotarized(dynamicCode, [signingInfo[KEY_SIGNING_FLAGS] intValue])];
    
    //extract signing info
    status = SecCodeCopySigningInformation(dynamicCode, kSecCSSigningInformation, &signingDetails);
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
bail:
    
    //free dynamic code
    if(NULL != dynamicCode)
    {
        //free
        CFRelease(dynamicCode);
        dynamicCode = NULL;
    }
    
    return signingDetails;
}

//check if notarized
// call this after other code checks
BOOL isNotarized(SecCodeRef dynamicCode, uint32_t csFlags) {
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //notarization requirement
    static SecRequirementRef notarizedReq = nil;
    
    //only once
    dispatch_once(&onceToken, ^{
        SecRequirementCreateWithString(CFSTR("notarized"), kSecCSDefaultFlags, &notarizedReq);
    });
    
    //sanity check
    if(!notarizedReq) {
        return NO;
    }
    
    //ad hoc binaries aren't notarized
    if(CS_ADHOC & csFlags) {
        return NO;
    }
    
    //gotta have hardened runtime to get notarized
    if(!(CS_RUNTIME & csFlags)){
        return NO;
    }
    
    return (errSecSuccess == SecCodeCheckValidity(dynamicCode, kSecCSDefaultFlags, notarizedReq));
}

//determine who signed item
NSNumber* extractSigner(SecCodeRef code, NSNumber* csFlags) {
    
    //"anchor apple"
    static SecRequirementRef isApple = nil;
    
    //"anchor apple generic"
    static SecRequirementRef isDevID = nil;
    
    //"Apple Mac OS Application Signing"
    static SecRequirementRef isAppStore = nil;
    
    //"Apple iPhone OS Application Signing"
    static SecRequirementRef isiOSAppStore = nil;
    
    //token
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        
        //init apple signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &isApple);
        
        //init dev id signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple generic"), kSecCSDefaultFlags, &isDevID);
        
        //init (macOS) app store signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple generic and certificate leaf [subject.CN] = \"Apple Mac OS Application Signing\""), kSecCSDefaultFlags, &isAppStore);
        
        //init (iOS) app store signing requirement
        SecRequirementCreateWithString(CFSTR("anchor apple generic and certificate leaf [subject.CN] = \"Apple iPhone OS Application Signing\""), kSecCSDefaultFlags, &isiOSAppStore);
    });
    
    //ad hoc
    if(CS_ADHOC & csFlags.unsignedIntValue) {
        return [NSNumber numberWithInt:ES_CS_VALIDATION_CATEGORY_LOCAL_SIGNING];
    }
    
    //"is apple" (proper)
    if(errSecSuccess == validateRequirement(code, isApple)) {
        //set signer to apple
        return [NSNumber numberWithInt:ES_CS_VALIDATION_CATEGORY_PLATFORM];
    }
    
    //"is app store"
    // note: this is more specific than dev id, so do it first
    if(errSecSuccess == validateRequirement(code, isAppStore)) {
        return [NSNumber numberWithInt:ES_CS_VALIDATION_CATEGORY_APP_STORE];
    }

    //"is dev id"
    if(errSecSuccess == validateRequirement(code, isDevID)) {
        return [NSNumber numberWithInt:ES_CS_VALIDATION_CATEGORY_DEVELOPER_ID];
    }
    
    //invalid(?)
    return [NSNumber numberWithInt:ES_CS_VALIDATION_CATEGORY_INVALID];
}

//validate a requirement
OSStatus validateRequirement(SecCodeRef code, SecRequirementRef requirement) {
    return SecCodeCheckValidity((SecCodeRef)code, kSecCSDefaultFlags, requirement);
}

//extract (names) of signing auths
NSMutableArray* extractSigningAuths(NSDictionary* signingDetails)
{
    //signing auths
    NSMutableArray* authorities = nil;
    
    //cert chain
    NSArray* certificateChain = nil;
    
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on cert
    CFStringRef commonName = NULL;
    
    //init array for certificate names
    authorities = [NSMutableArray array];
    
    //get cert chain
    certificateChain = [signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    if(0 == certificateChain.count)
    {
        //no certs
        goto bail;
    }
    
    //extract/save name of all certs
    for(index = 0; index < certificateChain.count; index++)
    {
        //reset
        commonName = NULL;
        
        //extract cert
        certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
        
        //get common name
        if( (errSecSuccess == SecCertificateCopyCommonName(certificate, &commonName)) &&
            (NULL != commonName) )
        {
            //save
            [authorities addObject:(__bridge id _Nonnull)(commonName)];
            
            //release
            CFRelease(commonName);
        }
    }
        
bail:
    
    return authorities;
}
