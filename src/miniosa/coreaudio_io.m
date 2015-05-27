
#include <assert.h>

#include "coreaudio_util.h"
#include "coreaudio_io.h"
#include "miniosa.h"
#include "mem.h"
#include "instance.h"

#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>


//Singleton instance
static mnInstance* s_instance = NULL;

#define MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES 2048

#pragma mark Buffer conversion helpers

/**
 * Converts a buffer of floats to a buffer of signed shorts. The floats are assumed
 * to be in the range [-1, 1].
 * @param sourceBuffer The buffer containing the values to convert.
 * @param targetBuffer The buffer to write converted samples to.
 * @param size The size of the source and target buffers.
 */
static inline void mnFloatToInt16(float* sourceBuffer, short* targetBuffer, int size)
{
    assert(sourceBuffer != NULL);
    assert(targetBuffer != NULL);
    
    int i = 0;
    while (i < size)
    {
        targetBuffer[i] = (short)(32767 * sourceBuffer[i]);
        i++;
    }
}

/**
 * Converts a buffer of signed short values to a buffer of floats
 * in the range [-1, 1].
 * @param sourceBuffer The buffer containing the values to convert.
 * @param targetBuffer The buffer to write converted samples to.
 * @param size The size of the source and target buffers.
 */
static inline void mnInt16ToFloat(short* sourceBuffer, float* targetBuffer, int size)
{
    assert(sourceBuffer != NULL);
    assert(targetBuffer != NULL);
    
    int i = 0;
    while (i < size)
    {
        targetBuffer[i] = (float)(sourceBuffer[i] / 32768.0);
        i++;
    }
}

#pragma mark Audio buffer callbacks

static OSStatus mnCoreAudioInputCallback(void *inRefCon,
                                         AudioUnitRenderActionFlags *ioActionFlags,
                                         const AudioTimeStamp *inTimeStamp,
                                         UInt32 inBusNumber,
                                         UInt32 inNumberFrames,
                                         AudioBufferList *ioData)
{
    s_instance->inputBufferList.mBuffers[0].mDataByteSize = s_instance->inputBufferByteSize;
    //fill the already allocated input buffer list with samples
    OSStatus status;
    status = AudioUnitRender(s_instance->auComponentInstance,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &s_instance->inputBufferList);
    assert(status == 0);
    
    
    mnInstance* instance = (mnInstance*)inRefCon;
    
    const int numChannels = s_instance->inputBufferList.mBuffers[0].mNumberChannels;
    short* buffer = (short*) s_instance->inputBufferList.mBuffers[0].mData;
    int currFrame = 0;
    while (currFrame < inNumberFrames)
    {
        int numFramesToMix = inNumberFrames - currFrame;
        if (numFramesToMix > MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES)
        {
            numFramesToMix = MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES;
        }
        
        /*Convert input buffer samples to floats*/
        mnInt16ToFloat(&buffer[currFrame * numChannels],
                       s_instance->inputScratchBuffer,
                       numFramesToMix * numChannels);
        
        /*Pass the converted buffer to the instance*/
        if (instance->audioInputCallback)
        {
            instance->audioInputCallback(numChannels, numFramesToMix, &(instance->inputScratchBuffer)[currFrame * numChannels], instance->callbackContext);
        }
        
        currFrame += numFramesToMix;
    }
    
    return noErr;
}

static OSStatus mnCoreAudioOutputCallback(void *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData)
{
    //#define KWL_DEBUG_CA_DEADLINE
#ifdef KWL_DEBUG_CA_DEADLINE
    static double prevDelta = 0.0;
    static double ht = 0.0;
    double delta = inTimeStamp->mSampleTime - ht;
    ht = inTimeStamp->mSampleTime;
    if (delta > inNumberFrames && prevDelta > 0.0)
    {
        printf("missed deadline, time since prev callback: %f samples, curr buffer size %d samples\n", delta, inNumberFrames);
        //mnDebugPrintAudioSessionInfo();
        //mnDebugPrintRemoteIOInfo();
    }
    prevDelta = delta;
#endif
    
    mnInstance* instance = (mnInstance*)inRefCon;
    
    const int numChannels = ioData->mBuffers[0].mNumberChannels;
    short* buffer = (short*) ioData->mBuffers[0].mData;
    int currFrame = 0;
    while (currFrame < inNumberFrames)
    {
        int numFramesToMix = inNumberFrames - currFrame;
        if (numFramesToMix > MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES)
        {
            numFramesToMix = MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES;
        }
        
        /*prepare a new buffer*/
        if (instance->audioOutputCallback)
        {
            instance->audioOutputCallback(numChannels, numFramesToMix, instance->outputScratchBuffer, instance->callbackContext);
        }
        
        mnFloatToInt16(s_instance->outputScratchBuffer,
                       &buffer[currFrame * numChannels],
                       numFramesToMix * numChannels);
        currFrame += numFramesToMix;
    }
    
    return noErr;
}

mnError mnInitialize(mnAudioInputCallback inputCallback,
                     mnAudioOutputCallback outputCallback,
                     void* callbackContext,
                     mnOptions* options)
{
    if (s_instance != NULL)
    {
        return MN_ALREADY_INITIALIZED;
    }
    
    //create and configure instance
    mnOptions defaultOptions;
    defaultOptions.sampleRate = 44100;
    defaultOptions.numberOfInputChannels = 1;
    defaultOptions.numberOfOutputChannels = 2;
    defaultOptions.bufferSizeInFrames = 512;
    
    mnOptions* optionsToUse = options != NULL ? options : &defaultOptions;
    
    s_instance = MN_MALLOC(sizeof(mnInstance), "mnInstance");
    memset(s_instance, 0, sizeof(mnInstance));
    
    s_instance->requestedNumInputChannels = optionsToUse->numberOfInputChannels;
    s_instance->requestedNumOutputChannels = optionsToUse->numberOfOutputChannels;
    s_instance->requestedSampleRate = optionsToUse->sampleRate;
    s_instance->requestedBufferSizeInFrames = optionsToUse->bufferSizeInFrames;
    
    s_instance->audioInputCallback = inputCallback;
    s_instance->audioOutputCallback = outputCallback;
    s_instance->callbackContext = callbackContext;
    
    //initialize audio session
    mnInitAudioSession();
    
    //start audio
    mnResumeAudio();
    
    return MN_NO_ERROR;
}

mnError mnDeinitialize()
{
    if (s_instance == NULL)
    {
        return MN_NOT_INITIALIZED;
    }
    
    mnStopAndDeinitRemoteIO();
    
    AudioComponentInstanceDispose(s_instance->auComponentInstance);
    
    MN_FREE(s_instance->inputScratchBuffer);
    MN_FREE(s_instance->outputScratchBuffer);
    
    MN_FREE(s_instance);

    s_instance = NULL;
    
    return MN_NO_ERROR;
}

void mnStopAndDeinitRemoteIO()
{
    if (s_instance->auComponentInstance)
    {
        OSStatus status = AudioOutputUnitStop(s_instance->auComponentInstance);
        assert(status == noErr);
    
        status = AudioUnitUninitialize(s_instance->auComponentInstance);
        assert(status == noErr);
    
        s_instance->auComponentInstance = NULL;
    }
    
    MN_FREE(s_instance->inputBufferList.mBuffers[0].mData);
    s_instance->inputBufferList.mBuffers[0].mData = NULL;
    
    MN_FREE(s_instance->inputScratchBuffer);
    s_instance->inputScratchBuffer = NULL;
    
    MN_FREE(s_instance->outputScratchBuffer);
    s_instance->outputScratchBuffer = NULL;
}

void mnCreateRemoteIOInstance()
{
    /*create audio component description*/
    AudioComponentDescription auDescription;
    
    auDescription.componentType          = kAudioUnitType_Output;
    auDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
    auDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    auDescription.componentFlags         = 0;
    auDescription.componentFlagsMask     = 0;
    
    /*get a component reference*/
    AudioComponent auComponent = AudioComponentFindNext(NULL, &auDescription);
    
    /*get the actual instance*/
    OSStatus status = AudioComponentInstanceNew(auComponent,
                                                &s_instance->auComponentInstance);
    assert(status == noErr);
}



void mnInitAndStartRemoteIO()
{
	//make sure the audio unit is not initialized more than once.
	//some of the operations below depend on the unit not being
	//initialized.
    mnStopAndDeinitRemoteIO();
    
    mnCreateRemoteIOInstance();
    
    const int numInChannels = s_instance->requestedNumInputChannels;
    const int numOutChannels = s_instance->requestedNumOutputChannels;
    float sampleRate = s_instance->requestedSampleRate;
    
    const unsigned int OUTPUT_BUS_ID = 0;
    const unsigned int INPUT_BUS_ID = 1;
    
    OSStatus status = 0;
    
    /*Enable recording if requested*/
    if (numInChannels > 0)
    {
        UInt32 flag = 1;
        status = AudioUnitSetProperty(s_instance->auComponentInstance,
                                      kAudioOutputUnitProperty_EnableIO, 
                                      kAudioUnitScope_Input, 
                                      INPUT_BUS_ID,
                                      &flag, 
                                      sizeof(flag));
        mnEnsureNoAudioUnitError(status);
    }
    
    NSError* error = nil;
    
    /* set sample rate */
    [[AVAudioSession sharedInstance] setPreferredSampleRate:sampleRate error:&error];
    assert(!error);
    
    /*set buffer size. */
    Float32 preferredBufferDuration = s_instance->requestedBufferSizeInFrames / (float)s_instance->requestedSampleRate;
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferredBufferDuration error:&error];
    assert(!error);
    
    /*enable playback*/    
    UInt32 flag = 1;
    status = AudioUnitSetProperty(s_instance->auComponentInstance,
                                  kAudioOutputUnitProperty_EnableIO, 
                                  kAudioUnitScope_Output, 
                                  OUTPUT_BUS_ID,
                                  &flag, 
                                  sizeof(flag));
    mnEnsureNoAudioUnitError(status);
    
    /*set up output audio format description*/
    mnSetASBD(&s_instance->outputFormat, numOutChannels, sampleRate);
    
    /*apply format to output*/
    status = AudioUnitSetProperty(s_instance->auComponentInstance,
                                  kAudioUnitProperty_StreamFormat, 
                                  kAudioUnitScope_Input, 
                                  OUTPUT_BUS_ID, 
                                  &s_instance->outputFormat,
                                  sizeof(s_instance->outputFormat));
    mnEnsureNoAudioUnitError(status);
    
    /*apply format to input if enabled*/
    if (numInChannels > 0)
    {
        mnSetASBD(&s_instance->inputFormat, numInChannels, sampleRate);
        
        status = AudioUnitSetProperty(s_instance->auComponentInstance,
                                      kAudioUnitProperty_StreamFormat, 
                                      kAudioUnitScope_Output, 
                                      INPUT_BUS_ID, 
                                      &s_instance->inputFormat,
                                      sizeof(s_instance->outputFormat));
        mnEnsureNoAudioUnitError(status);
        
        int maxSliceSize = 0;
        UInt32 s = sizeof(maxSliceSize);
		status = AudioUnitGetProperty(s_instance->auComponentInstance,
                                      kAudioUnitProperty_MaximumFramesPerSlice, 
                                      kAudioUnitScope_Global, 
                                      0, 
                                      &maxSliceSize, 
                                      &s);
        mnEnsureNoAudioUnitError(status);
        
        s_instance->inputBufferList.mNumberBuffers = 1;
        s_instance->inputBufferList.mBuffers[0].mNumberChannels = numInChannels;
        s_instance->inputBufferByteSize = 2 * numInChannels * maxSliceSize;
        s_instance->inputBufferList.mBuffers[0].mDataByteSize = s_instance->inputBufferByteSize;
        s_instance->inputBufferList.mBuffers[0].mData = MN_MALLOC(s_instance->inputBufferList.mBuffers[0].mDataByteSize, "inputBufferList sample data");
    }
    
    assert(status == noErr);
    
    AURenderCallbackStruct renderCallbackStruct;
    /*hook up the input callback*/
    if (numInChannels > 0)
    {
        renderCallbackStruct.inputProc = mnCoreAudioInputCallback;
        renderCallbackStruct.inputProcRefCon = s_instance;
        
        status = AudioUnitSetProperty(s_instance->auComponentInstance,
                                      kAudioOutputUnitProperty_SetInputCallback, 
                                      kAudioUnitScope_Global, 
                                      OUTPUT_BUS_ID, 
                                      &renderCallbackStruct, 
                                      sizeof(renderCallbackStruct));
        mnEnsureNoAudioUnitError(status);
    }
    
    
    /*hook up the output callback*/
    renderCallbackStruct.inputProc = mnCoreAudioOutputCallback;
    renderCallbackStruct.inputProcRefCon = s_instance;
    
    status = AudioUnitSetProperty(s_instance->auComponentInstance,
                                  kAudioUnitProperty_SetRenderCallback, 
                                  kAudioUnitScope_Global, 
                                  OUTPUT_BUS_ID,
                                  &renderCallbackStruct, 
                                  sizeof(renderCallbackStruct));
    
    mnEnsureNoAudioUnitError(status);
    
    /*init audio unit*/
    status = AudioUnitInitialize(s_instance->auComponentInstance);
    //printf("status %d\n", status);
    mnEnsureNoAudioUnitError(status);
    
    /*start audio unit*/
    status = AudioOutputUnitStart(s_instance->auComponentInstance);
    //printf("status %d\n", status);
    mnEnsureNoAudioUnitError(status);
    
    s_instance->sampleRate = [AVAudioSession sharedInstance].sampleRate;
    s_instance->bufferSizeInFrames = [AVAudioSession sharedInstance].IOBufferDuration * s_instance->sampleRate;
    s_instance->numInputChannels = s_instance->inputFormat.mChannelsPerFrame;
    s_instance->numOutputChannels = s_instance->outputFormat.mChannelsPerFrame;
    s_instance->inputScratchBuffer = MN_MALLOC(MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES * sizeof(float) * s_instance->numInputChannels, "input scratch buffer");
    s_instance->outputScratchBuffer = MN_MALLOC(MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES * sizeof(float) * s_instance->numOutputChannels, "output scratch buffer");

}



void mnSuspendAudio(void)
{
    mnStopAndDeinitRemoteIO();
    OSStatus result = AudioSessionSetActive(0);
    mnEnsureNoAudioSessionError(result);
}

int mnResumeAudio(void)
{
    OSStatus result = AudioSessionSetActive(1);
    if (result == noErr)
    {
        mnInitAndStartRemoteIO();
        return 1;
    }
    
    return 0;
}





