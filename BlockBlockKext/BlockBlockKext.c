//
//  BlockBlockKext.c
//  BlockBlockKext
//
//  Created by Patrick Wardle on 11/18/15.
//  Copyright © 2015 Objective-See. All rights reserved.
//

#include "Consts.h"

#include <sys/proc.h>
#include <sys/kauth.h>
#include <sys/vnode.h>
#include <sys/kern_event.h>
#include <libkern/libkern.h>

//apple does this
// ->see proc_internal.h
#define PROC_NULL (struct proc *)0

/* FUNCTIONS */

//start
// ->register kauth listener
kern_return_t start(kmod_info_t * ki, void *d);

//stop
// ->unregsiter kauth listener
kern_return_t stop(kmod_info_t *ki, void *d);

//kauth callback
// ->for KAUTH_FILEOP_EXEC events, broadcast process notifications to user-mode
//static int processExec(kauth_cred_t credential, void* idata, kauth_action_t action, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3);

//kauth callback
// ->for KAUTH_SCOPE_VNODE events, broadcast process notifications to user-mode
static int processExec(kauth_cred_t credential, void* idata, kauth_action_t action, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3);

/* GLOBALS */

//kauth listener
// ->scope KAUTH_SCOPE_FILEOP
kauth_listener_t kauthListener = NULL;

//kext's/objective-see's vendor id
u_int32_t objSeeVendorID = 0;

/* CODE */
/*
//kauth callback
// ->for KAUTH_FILEOP_EXEC events, broadcast process notifications to user-mode
static int processExec(kauth_cred_t credential, void* idata, kauth_action_t action, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3)
{
    //status var
    errno_t status = KERN_FAILURE;

    //chunk pointer
    char* chunkPointer = NULL;
    
    //path
    char path[MAXPATHLEN+1] = {0};
    
    //uid
    uid_t uid = -1;
    
    //pid
    pid_t pid = -1;
    
    //ppid
    pid_t ppid = -1;
    
    //kernel event message
    struct kev_msg kEventMsg = {0};
    
    //non-path size
    int nonPathSize = 0;
    
    //ignore all non exec events
    if(KAUTH_FILEOP_EXEC != action)
    {
        //bail
        goto bail;
    }
    
    //zero out path
    bzero(&path, sizeof(path));
    
    //path is arg1 (per sys/k_auth.h)
    // ->make copy, so broadcast to usermode works
    strncpy(path, (const char*)arg1, MAXPATHLEN);
    
    //get UID
    uid = kauth_getuid();
    
    //get pid
    pid = proc_selfpid();
    
    //get ppid
    ppid = proc_selfppid();
    
    //dbg msg
    DEBUG_PRINT(("BLOCKBLOCK KEXT: new process: %s %d/%d/%d\n", path, pid, ppid, uid));
    
    //calc non-path size
    // ->pid, uid, and ppid
    nonPathSize = sizeof(pid_t) + sizeof(uid_t) + sizeof(pid_t);

    //zero out kernel message
    bzero(&kEventMsg, sizeof(struct kev_msg));
    
    //set vendor code
    kEventMsg.vendor_code = objSeeVendorID;
    
    //set class
    kEventMsg.kev_class = KEV_ANY_CLASS;
    
    //set subclass
    kEventMsg.kev_subclass = KEV_ANY_SUBCLASS;
    
    //set event code
    kEventMsg.event_code = PROCESS_BEGAN_EVENT;
    
    //add pid
    kEventMsg.dv[0].data_length = sizeof(pid_t);
    kEventMsg.dv[0].data_ptr = &pid;
    
    //add uid
    kEventMsg.dv[1].data_length = sizeof(uid_t);
    kEventMsg.dv[1].data_ptr = &uid;
    
    //add ppid
    kEventMsg.dv[2].data_length = sizeof(pid_t);
    kEventMsg.dv[2].data_ptr = &ppid;

    //start at path
    // ->this works, since data before path is small enough to never chunk
    chunkPointer = path;
    
    //send all chunks
    // ->termination; end of string
    while(0x0 != *chunkPointer)
    {
        //add current offset of path
        kEventMsg.dv[3].data_ptr = chunkPointer;
        
        //set size
        // ->either string length (with NULL)
        //   or max size - pid, etc and extra for NULL!
        kEventMsg.dv[3].data_length = min((u_int)strlen(chunkPointer)+1, (MAX_MSG_SIZE - nonPathSize - 1));
        
        //broadcast msg to user-mode
        status = kev_msg_post(&kEventMsg);
        if(KERN_SUCCESS != status)
        {
            //err msg
            printf("BLOCKBLOCK KEXT ERROR: kev_msg_post() failed with %d\n", status);
            
            //bail
            goto bail;
        }
        
        //advance chunk pointer
        chunkPointer += kEventMsg.dv[3].data_length;
    
    }//while data to send...
    
//bail
bail:
    
    return KAUTH_RESULT_DEFER;
}
*/


//kauth callback
// ->for KAUTH_SCOPE_VNODE events, broadcast process notifications to user-mode
static int processExec(kauth_cred_t credential, void* idata, kauth_action_t action, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3)
{
    //status var
    errno_t status = KERN_FAILURE;
    
    //chunk pointer
    char* chunkPointer = NULL;
    
    //type
    enum vtype type = {0};
    
    //path length
    int pathLength = MAXPATHLEN;
    
    //path
    char path[MAXPATHLEN+1] = {0};
    
    //uid
    uid_t uid = -1;
    
    //pid
    int pid = -1;
    
    //proc
    proc_t proc = PROC_NULL;
    
    //ppid
    pid_t ppid = -1;
    
    //kernel event message
    struct kev_msg kEventMsg = {0};
    
    //non-path size
    int nonPathSize = 0;
    
    //get vnode type
    type = vnode_vtype((vnode_t)arg1);
    
    //ignore all non exec events
    if( (KAUTH_VNODE_EXECUTE != action) ||
        (type & VDIR) )
    {
        //bail
        goto bail;
    }
    
    //zero out path
    bzero(&path, sizeof(path));
    
    //get path
    vn_getpath((vnode_t)arg1, path, &pathLength);

    //get pid
    pid = vfs_context_pid((vfs_context_t)arg0);
    
    //get UID
    uid = kauth_cred_getuid(vfs_context_ucred((vfs_context_t)arg0));
    
    //get proc stuct for pid
    // ->allows us to get parent
    proc = proc_find(pid);
    if(PROC_NULL == proc)
    {
        //bail
        goto bail;
    }
    
    //get ppid
    ppid = proc_ppid(proc);
    
    //dbg msg
    DEBUG_PRINT(("BLOCKBLOCK KEXT: new process: %s %d/%d/%d\n", path, pid, ppid, uid));
    
    //calc non-path size
    // ->pid, uid, and ppid
    nonPathSize = sizeof(pid_t) + sizeof(uid_t) + sizeof(pid_t);
    
    //zero out kernel message
    bzero(&kEventMsg, sizeof(struct kev_msg));
    
    //set vendor code
    kEventMsg.vendor_code = objSeeVendorID;
    
    //set class
    kEventMsg.kev_class = KEV_ANY_CLASS;
    
    //set subclass
    kEventMsg.kev_subclass = KEV_ANY_SUBCLASS;
    
    //set event code
    kEventMsg.event_code = PROCESS_BEGAN_EVENT;
    
    //add pid
    kEventMsg.dv[0].data_length = sizeof(pid_t);
    kEventMsg.dv[0].data_ptr = &pid;
    
    //add uid
    kEventMsg.dv[1].data_length = sizeof(uid_t);
    kEventMsg.dv[1].data_ptr = &uid;
    
    //add ppid
    kEventMsg.dv[2].data_length = sizeof(pid_t);
    kEventMsg.dv[2].data_ptr = &ppid;
    
    //start at path
    // ->this works, since data before path is small enough to never chunk
    chunkPointer = path;
    
    //send all chunks
    // ->termination; end of string
    while(0x0 != *chunkPointer)
    {
        //add current offset of path
        kEventMsg.dv[3].data_ptr = chunkPointer;
        
        //set size
        // ->either string length (with NULL)
        //   or max size - pid, etc and extra for NULL!
        kEventMsg.dv[3].data_length = min((u_int)strlen(chunkPointer)+1, (MAX_MSG_SIZE - nonPathSize - 1));
        
        //broadcast msg to user-mode
        status = kev_msg_post(&kEventMsg);
        if(KERN_SUCCESS != status)
        {
            //err msg
            printf("BLOCKBLOCK KEXT ERROR: kev_msg_post() failed with %d\n", status);
            
            //bail
            goto bail;
        }
        
        //advance chunk pointer
        chunkPointer += kEventMsg.dv[3].data_length;
        
    }//while data to send...

    
//bail
bail:
    
    //release proc
    if(PROC_NULL != proc)
    {
        //release
        proc_rele(proc);
        
        //unset
        proc = PROC_NULL;
    }
    
    return KAUTH_RESULT_DEFER;
}

//start function, automatically invoked
// ->get vendor code, register KAuth listener, etc
kern_return_t start(kmod_info_t * ki, void *d)
{
    //status var
    kern_return_t status = KERN_FAILURE;
    
    //dbg msg
    DEBUG_PRINT(("BLOCKBLOCK KEXT: starting...\n"));
    
    /*
    //register listener
    // ->scope 'KAUTH_SCOPE_FILEOP'
    kauthListener = kauth_listen_scope(KAUTH_SCOPE_FILEOP, &processExec, NULL);
    if(NULL == kauthListener)
    {
        //err msg
        printf("BLOCKBLOCK KEXT ERROR: kauth_listen_scope('KAUTH_SCOPE_FILEOP',...) failed\n");
        
        //bail
        goto bail;
    }
    */
    
    //register listener
    // ->scope 'KAUTH_SCOPE_VNODE'
    kauthListener = kauth_listen_scope(KAUTH_SCOPE_VNODE, &processExec, NULL);
    if(NULL == kauthListener)
    {
        //err msg
        printf("BLOCKBLOCK KEXT ERROR: kauth_listen_scope('KAUTH_SCOPE_VNODE',...) failed\n");
        
        //bail
        goto bail;
    }
    
    //grab vendor id
    status = kev_vendor_code_find(OBJECTIVE_SEE_VENDOR, &objSeeVendorID);
    if(KERN_SUCCESS != status)
    {
        //err msg
        printf("BLOCKBLOCK KEXT ERROR: kev_vendor_code_find() failed to get vendor code (%#x)\n", status);
        
        //indicate failure
        status = KERN_FAILURE;
        
        //bail
        goto bail;
    }
    
    //happy
    status = KERN_SUCCESS;
    
//bail
bail:
    
    return status;
}

//stop function, automatically invoked
// ->should never get called in release mode
kern_return_t stop(kmod_info_t *ki, void *d)
{
    //status
    kern_return_t status = KERN_FAILURE;
    
    //unregister listener
    if(NULL != kauthListener)
    {
        //unregister
        kauth_unlisten_scope(kauthListener);
        
        //unset
        kauthListener = NULL;
    }
    
    //happy
    status = KERN_SUCCESS;
    
//bail
bail:
    
    return status;
    
}
