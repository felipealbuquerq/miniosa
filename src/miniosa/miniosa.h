
/*! \file */

#ifndef MN_MINIOSA_H
#define MN_MINIOSA_H

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */
    
    typedef enum {
        MN_NO_ERROR = 0,
        MN_ALREADY_INITIALIZED = 1,
        MN_NOT_INITIALIZED = 2,
        MN_FAILED_TO_ACTIVATE_SESSION = 3,
        MN_FAILED_TO_DEACTIVATE_SESSION = 4
    } mnError;
    
    typedef struct {
        float sampleRate;
        int numberOfInputChannels;
        int numberOfOutputChannels;
        int bufferSizeInFrames;
    } mnOptions;
    
    typedef void (*mnAudioInputCallback)(int numChannels, int numFrames, const float* samples, void* callbackContext);
    
    typedef void (*mnAudioOutputCallback)(int numChannels, int numFrames, float* samples, void* callbackContext);
    
    /**
     * Initializes and starts the audio system.
     */
    mnError mnStart(mnAudioInputCallback inputCallback,
                    mnAudioOutputCallback outputCallback,
                    void* callbackContext,
                    mnOptions* options);
    
    /**
     * Stops and shuts down the audio system.
     */
    mnError mnStop();
    
    /**
     * Suspends the audio system. You may want to call this when
     * the app enters background mode.
     */
    mnError mnSuspend();
    
    /**
     * Resumes the audio system. You may want to call this when
     * the app returns from background mode.
     */
    mnError mnResume();
    
#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif //MN_HOST_IOS_H
