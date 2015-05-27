
#include <assert.h>

#include "coreaudio_util.h"
#include "audiosession.h"
#include "miniosa.h"
#include "mem.h"
#include "instance.h"

#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>

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
    mnInstance* instance = (mnInstance*)inRefCon;
    
    instance->inputBufferList.mBuffers[0].mDataByteSize = instance->inputBufferByteSize;
    //fill the already allocated input buffer list with samples
    OSStatus status;
    status = AudioUnitRender(instance->auComponentInstance,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &instance->inputBufferList);
    assert(status == 0);
    
    const int numChannels = instance->inputBufferList.mBuffers[0].mNumberChannels;
    short* buffer = (short*) instance->inputBufferList.mBuffers[0].mData;
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
                       instance->inputScratchBuffer,
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
        
        mnFloatToInt16(instance->outputScratchBuffer,
                       &buffer[currFrame * numChannels],
                       numFramesToMix * numChannels);
        currFrame += numFramesToMix;
    }
    
    return noErr;
}

static void mnInstance_createRemoteIOInstance(mnInstance* instance)
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
                                                &instance->auComponentInstance);
    assert(status == noErr);
}


void mnInstance_createAndStartRemoteIOInstance(mnInstance* instance)
{
    //make sure the audio unit is not initialized more than once.
    //some of the operations below depend on the unit not being
    //initialized.
    mnInstance_stopAndDestroyRemoteIOInstance(instance);
    
    mnInstance_createRemoteIOInstance(instance);
    
    const int numInChannels = instance->requestedNumInputChannels;
    const int numOutChannels = instance->requestedNumOutputChannels;
    float sampleRate = instance->requestedSampleRate;
    
    const unsigned int OUTPUT_BUS_ID = 0;
    const unsigned int INPUT_BUS_ID = 1;
    
    OSStatus status = 0;
    
    /*Enable recording if requested*/
    if (numInChannels > 0)
    {
        UInt32 flag = 1;
        status = AudioUnitSetProperty(instance->auComponentInstance,
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
    Float32 preferredBufferDuration = instance->requestedBufferSizeInFrames / (float)instance->requestedSampleRate;
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferredBufferDuration error:&error];
    assert(!error);
    
    /*enable playback*/
    UInt32 flag = 1;
    status = AudioUnitSetProperty(instance->auComponentInstance,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  OUTPUT_BUS_ID,
                                  &flag,
                                  sizeof(flag));
    mnEnsureNoAudioUnitError(status);
    
    /*set up output audio format description*/
    mnSetASBD(&instance->outputFormat, numOutChannels, sampleRate);
    
    /*apply format to output*/
    status = AudioUnitSetProperty(instance->auComponentInstance,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS_ID,
                                  &instance->outputFormat,
                                  sizeof(instance->outputFormat));
    mnEnsureNoAudioUnitError(status);
    
    /*apply format to input if enabled*/
    if (numInChannels > 0)
    {
        mnSetASBD(&instance->inputFormat, numInChannels, sampleRate);
        
        status = AudioUnitSetProperty(instance->auComponentInstance,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      INPUT_BUS_ID,
                                      &instance->inputFormat,
                                      sizeof(instance->outputFormat));
        mnEnsureNoAudioUnitError(status);
        
        int maxSliceSize = 0;
        UInt32 s = sizeof(maxSliceSize);
        status = AudioUnitGetProperty(instance->auComponentInstance,
                                      kAudioUnitProperty_MaximumFramesPerSlice,
                                      kAudioUnitScope_Global,
                                      0,
                                      &maxSliceSize,
                                      &s);
        mnEnsureNoAudioUnitError(status);
        
        instance->inputBufferList.mNumberBuffers = 1;
        instance->inputBufferList.mBuffers[0].mNumberChannels = numInChannels;
        instance->inputBufferByteSize = 2 * numInChannels * maxSliceSize;
        instance->inputBufferList.mBuffers[0].mDataByteSize = instance->inputBufferByteSize;
        instance->inputBufferList.mBuffers[0].mData = MN_MALLOC(instance->inputBufferList.mBuffers[0].mDataByteSize, "inputBufferList sample data");
    }
    
    assert(status == noErr);
    
    AURenderCallbackStruct renderCallbackStruct;
    /*hook up the input callback*/
    if (numInChannels > 0)
    {
        renderCallbackStruct.inputProc = mnCoreAudioInputCallback;
        renderCallbackStruct.inputProcRefCon = instance;
        
        status = AudioUnitSetProperty(instance->auComponentInstance,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      OUTPUT_BUS_ID,
                                      &renderCallbackStruct,
                                      sizeof(renderCallbackStruct));
        mnEnsureNoAudioUnitError(status);
    }
    
    
    /*hook up the output callback*/
    renderCallbackStruct.inputProc = mnCoreAudioOutputCallback;
    renderCallbackStruct.inputProcRefCon = instance;
    
    status = AudioUnitSetProperty(instance->auComponentInstance,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  OUTPUT_BUS_ID,
                                  &renderCallbackStruct,
                                  sizeof(renderCallbackStruct));
    
    mnEnsureNoAudioUnitError(status);
    
    /*init audio unit*/
    status = AudioUnitInitialize(instance->auComponentInstance);
    //printf("status %d\n", status);
    mnEnsureNoAudioUnitError(status);
    
    /*start audio unit*/
    status = AudioOutputUnitStart(instance->auComponentInstance);
    //printf("status %d\n", status);
    mnEnsureNoAudioUnitError(status);
    
    instance->sampleRate = [AVAudioSession sharedInstance].sampleRate;
    instance->bufferSizeInFrames = [AVAudioSession sharedInstance].IOBufferDuration * instance->sampleRate;
    instance->numInputChannels = instance->inputFormat.mChannelsPerFrame;
    instance->numOutputChannels = instance->outputFormat.mChannelsPerFrame;
    instance->inputScratchBuffer = MN_MALLOC(MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES * sizeof(float) * instance->numInputChannels, "input scratch buffer");
    instance->outputScratchBuffer = MN_MALLOC(MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES * sizeof(float) * instance->numOutputChannels, "output scratch buffer");
}

void mnInstance_stopAndDestroyRemoteIOInstance(mnInstance* instance)
{
    if (instance->auComponentInstance)
    {
        OSStatus status = AudioOutputUnitStop(instance->auComponentInstance);
        assert(status == noErr);
        
        status = AudioUnitUninitialize(instance->auComponentInstance);
        assert(status == noErr);
        
        instance->auComponentInstance = NULL;
    }
    
    MN_FREE(instance->inputBufferList.mBuffers[0].mData);
    instance->inputBufferList.mBuffers[0].mData = NULL;
    
    MN_FREE(instance->inputScratchBuffer);
    instance->inputScratchBuffer = NULL;
    
    MN_FREE(instance->outputScratchBuffer);
    instance->outputScratchBuffer = NULL;
}

#pragma mark mnInstance API
mnError mnInstance_initialize(mnInstance* instance,
                              mnAudioInputCallback inputCallback,
                              mnAudioOutputCallback outputCallback,
                              void* callbackContext,
                              mnOptions* options)
{
    //create and configure instance
    mnOptions defaultOptions;
    defaultOptions.sampleRate = 44100;
    defaultOptions.numberOfInputChannels = 1;
    defaultOptions.numberOfOutputChannels = 2;
    defaultOptions.bufferSizeInFrames = 512;
    
    mnOptions* optionsToUse = options != NULL ? options : &defaultOptions;
    
    memset(instance, 0, sizeof(mnInstance));
    
    instance->requestedNumInputChannels = optionsToUse->numberOfInputChannels;
    instance->requestedNumOutputChannels = optionsToUse->numberOfOutputChannels;
    instance->requestedSampleRate = optionsToUse->sampleRate;
    instance->requestedBufferSizeInFrames = optionsToUse->bufferSizeInFrames;
    
    instance->audioInputCallback = inputCallback;
    instance->audioOutputCallback = outputCallback;
    instance->callbackContext = callbackContext;
    
    //initialize audio session, passing the instance as callback data
    mnInitAudioSession(instance);
    
    //start audio
    mnInstance_resume(instance);
    
    return MN_NO_ERROR;
}

mnError mnInstance_deinitialize(mnInstance* instance)
{
    mnInstance_stopAndDestroyRemoteIOInstance(instance);
    
    AudioComponentInstanceDispose(instance->auComponentInstance);
    
    MN_FREE(instance->inputScratchBuffer);
    MN_FREE(instance->outputScratchBuffer);
    
    MN_FREE(instance);

    return MN_NO_ERROR;
}

mnError mnInstance_suspend(mnInstance* instance)
{
    mnInstance_stopAndDestroyRemoteIOInstance(instance);
    NSError* error = nil;
    [[AVAudioSession sharedInstance] setActive:NO error:&error];
    if (error) {
        return MN_FAILED_TO_DEACTIVATE_SESSION;
    }
    
    return MN_NO_ERROR;
}

mnError mnInstance_resume(mnInstance* instance)
{
    NSError* error = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (error) {
        return MN_FAILED_TO_ACTIVATE_SESSION;
    }
    
    mnInstance_createAndStartRemoteIOInstance(instance);
    
    return MN_NO_ERROR;
}




