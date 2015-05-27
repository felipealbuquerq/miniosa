
/*! \file */

#ifndef MN_INSTANCE_H
#define MN_INSTANCE_H

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
        
    mnError mnInstance_initialize(mnInstance* instance,
                                  mnAudioInputCallback inputCallback,
                                  mnAudioOutputCallback outputCallback,
                                  void* callbackContext,
                                  mnOptions* options);
    
    mnError mnInstance_deinitialize(mnInstance* instance);
    
    mnError mnInstance_suspend(mnInstance* instance);
    
    mnError mnInstance_resume(mnInstance* instance);
    
    void mnInstance_createAndStartRemoteIOInstance(mnInstance* instance);
    
    void mnInstance_stopAndDestroyRemoteIOInstance(mnInstance* instance);

#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif //MN_INSTANCE_H
