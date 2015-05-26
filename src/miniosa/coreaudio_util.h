
/*! \file */

#ifndef MN_COREAUDIO_UTIL_H
#define MN_COREAUDIO_UTIL_H

#include <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */
    
    /**
     * Generates a meaningful assert if the result of an audio unit operation
     * is not successful.
     * @param result The error code to check.
     */
    void mnEnsureNoAudioUnitError(OSStatus result);
    
    /**
     * Generates a meaningful assert if the result of an audio session operation
     * is not successful.
     * @param result The error code to check.
     */
    void mnEnsureNoAudioSessionError(OSStatus result);
    
    /**
     * Prints some info about the current audio session to the console.
     */
    void mnDebugPrintAudioSessionInfo();
    
    /**
     * Prints some info about the remote I/O unit to the console.
     */
    void mnDebugPrintRemoteIOInfo();
    
#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif //MN_COREAUDIO_UTIL_H
