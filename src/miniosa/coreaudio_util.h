
/*! \file */

#ifndef MN_COREAUDIO_UTIL_H
#define MN_COREAUDIO_UTIL_H

#include <AudioToolbox/AudioToolbox.h>

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
    
    /**
     * Helper function that initializes an AudioStreamBasicDescription corresponding
     * to linear PCM with a given number of channels and a given sample rate
     * @param asbd The AudioStreamBasicDescription to initialize.
     * @param numChannels The number of channels.
     * @param sampleRate The sample rate.
     */
    void mnSetASBD(AudioStreamBasicDescription* asbd, int numChannels, float sampleRate);
    
#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif //MN_COREAUDIO_UTIL_H
