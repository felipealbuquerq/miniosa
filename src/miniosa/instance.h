#ifndef  MN_INSTANCE_H
#define  MN_INSTANCE_H

/*! \file */ 

#include "miniosa.h"
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

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

    
#ifdef __cplusplus
} //extern "C"
#endif /* __cplusplus */

#endif // MN_INSTANCE_H
