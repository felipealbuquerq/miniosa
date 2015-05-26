
/*! \file */

#ifndef MN_COREAUDIO_IO_H
#define MN_COREAUDIO_IO_H

#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudioTypes.h>

#include "miniosa.h"

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */
    
    typedef struct {
        AudioStreamBasicDescription outputFormat;
        AudioStreamBasicDescription inputFormat;
        /** The Remote I/O unit */
        AudioComponentInstance auComponentInstance;
        /** A buffer list for storing input samples. */
        AudioBufferList inputBufferList;
        /** The size in bytes of the input sample buffer. */
        int inputBufferByteSize;
        
        float* inputScratchBuffer;
        float* outputScratchBuffer;
        
        int requestedBufferSizeInFrames;
        int bufferSizeInFrames;
        
        float requestedSampleRate;
        float sampleRate;
        int requestedNumInputChannels;
        int numInputChannels;
        int requestedNumOutputChannels;
        int numOutputChannels;
        
        mnAudioInputCallback audioInputCallback;
        mnAudioOutputCallback audioOutputCallback;
        void* callbackContext;
    } mnInstance;
    
    mnError mnInitialize(mnAudioInputCallback inputCallback,
                         mnAudioOutputCallback outputCallback,
                         void* callbackContext,
                         mnOptions* options);
    
    mnError mnDeinitialize();
    
    
    /**
     * The callback for processing a new buffer of input samples.
     */
    OSStatus mnCoreAudioInputCallback(void *inRefCon,
                                      AudioUnitRenderActionFlags *ioActionFlags,
                                      const AudioTimeStamp *inTimeStamp,
                                      UInt32 inBusNumber,
                                      UInt32 inNumberFrames,
                                      AudioBufferList *ioData);
    
    /**
     * The callback for rendering a new buffer of output samples.
     */
    OSStatus mnCoreAudioOutputCallback(void *inRefCon,
                                       AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp,
                                       UInt32 inBusNumber,
                                       UInt32 inNumberFrames,
                                       AudioBufferList *ioData);
    
    /** Creates the singleton remote I/O unit instance. */
    void mnCreateRemoteIOInstance(void);
    
    /**
     * Stops and uninitializes the remote I/O unit.
     */
    void mnStopAndDeinitRemoteIO(void);
    
    /**
     * Initializes and starts the remote I/O unit.
     */
    void mnInitAndStartRemoteIO(void);
    
    /**
     * Initializes the AVAudioSession.
     */
    void mnInitAudioSession(void);
    
    void mnSuspendAudio(void);
    
    /**
     * Returns non-zero if successful, zero otherwise.
     */
    int mnResumeAudio(void);
    
    /**
     * Called when the audio session gets interrupted.
     */
    void mnAudioSessionInterruptionCallback(void *inClientData,  UInt32 inInterruptionState);
    
    /**
     * Called when audio input availability changes.
     */
    void mnInputAvailableChangeCallback(void *inUserData,
                                        AudioSessionPropertyID inPropertyID,
                                        UInt32 inPropertyValueSize,
                                        const void *inPropertyValue);
    
    /**
     * Called when the audio route changes.
     */
    void mnAudioRouteChangeCallback(void *inUserData,
                                    AudioSessionPropertyID inPropertyID,
                                    UInt32 inPropertyValueSize,
                                    const void *inPropertyValue);
    
    
    /**
     *
     */
    void mnServerDiedCallback(void *inUserData,
                              AudioSessionPropertyID inPropertyID,
                              UInt32 inPropertyValueSize,
                              const void *inPropertyValue);
    
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


#endif //MN_COREAUDIO_IO_H
