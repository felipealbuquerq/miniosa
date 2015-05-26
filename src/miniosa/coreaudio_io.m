
#include <assert.h>

#include "coreaudio_util.h"
#include "coreaudio_io.h"
#include "miniosa.h"
#include "mem.h"

#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>


//Singleton instance
static mnInstance* s_instance = NULL;

#define MN_IOS_TEMP_BUFFER_SIZE_IN_FRAMES 2048

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

mnError mnInitialize(mnAudioInputCallback inputCallback,
                     mnAudioOutputCallback outputCallback,
                     void* callbackContext,
                     mnOptions* options)
{
    if (s_instance != NULL)
    {
        return MN_ALREADY_INITIALIZED;
    }
    
    //setup instance
    s_instance = MN_MALLOC(sizeof(mnInstance), "mnInstance");
    memset(s_instance, 0, sizeof(mnInstance));
    
    s_instance->requestedNumInputChannels = options->numberOfInputChannels;
    s_instance->requestedNumOutputChannels = options->numberOfOutputChannels;
    s_instance->requestedSampleRate = options->sampleRate;
    s_instance->requestedBufferSizeInFrames = 512;
    
    s_instance->audioInputCallback = inputCallback;
    s_instance->audioOutputCallback = outputCallback;
    s_instance->callbackContext = callbackContext;
    
    /**
     * Create the remote IO instance once.
     */
    //mnCreateRemoteIOInstance();
    
    /*
     * Initialize the audio session
     */
    mnInitAudioSession();
    
    /*
     * Activates audio session and starts RemoteIO unit if successful.
     */
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

    s_instance = NULL;
    
    return MN_NO_ERROR;
}

void mnAudioSessionInterruptionCallback(void *inClientData,  UInt32 inInterruptionState)
{
    if (inInterruptionState == kAudioSessionBeginInterruption)
    {
        //printf("* audio session interruption callback: begin interruption\n");
        mnSuspendAudio();
    }
    else if (inInterruptionState == kAudioSessionEndInterruption)
    {
        //printf("* audio session interruption callback: end interruption\n");
        mnResumeAudio();
    }
    else 
    {
        assert(0 && "unknown interruption state");
    }
    //mnDebugPrintAudioSessionInfo();
}


void mnInputAvailableChangeCallback(void *inUserData,
                              AudioSessionPropertyID inPropertyID,
                              UInt32 inPropertyValueSize,
                              const void *inPropertyValue)
{
    //printf("* input availability changed. availability=%d\n", (*(int*)inPropertyValue));
    //mnDebugPrintAudioSessionInfo();
}

OSStatus mnCoreAudioInputCallback(void *inRefCon,
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
            instance->audioInputCallback(numChannels, numFramesToMix, &(instance->inputScratchBuffer)[currFrame * numChannels]);
        }
        
        currFrame += numFramesToMix;
    }
    
    return noErr;
}

OSStatus mnCoreAudioOutputCallback(void *inRefCon,
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
            instance->audioOutputCallback(numChannels, numFramesToMix, instance->outputScratchBuffer);
        }

        mnFloatToInt16(s_instance->outputScratchBuffer,
                       &buffer[currFrame * numChannels],
                       numFramesToMix * numChannels);
        currFrame += numFramesToMix;
    }
    
    return noErr;
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

void mnAudioRouteChangeCallback(void *inUserData,
                              AudioSessionPropertyID inPropertyID,
                              UInt32 inPropertyValueSize,
                              const void *inPropertyValue)
{
    //printf("* audio route changed,\n");
    mnInstance* instance = (mnInstance*)inUserData;
    
    //get the old audio route name and the reason for the change
    CFDictionaryRef dict = inPropertyValue;
    CFStringRef oldRoute = 
        CFDictionaryGetValue(dict, CFSTR(kAudioSession_AudioRouteChangeKey_OldRoute));
    CFNumberRef reason = 
    CFDictionaryGetValue(dict, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
    int reasonNumber = -1;
    CFNumberGetValue(reason, CFNumberGetType(reason), &reasonNumber);
    
    //reason specific code
    switch (reasonNumber)
    {
        case kAudioSessionRouteChangeReason_Unknown: //0
        {
            //printf("kAudioSessionRouteChangeReason_Unknown\n");
            break;
        }   
        case kAudioSessionRouteChangeReason_NewDeviceAvailable: //1
        {
            //printf("kAudioSessionRouteChangeReason_NewDeviceAvailable\n");
            break;
        }
        case kAudioSessionRouteChangeReason_OldDeviceUnavailable: //2
        {
            //printf("kAudioSessionRouteChangeReason_OldDeviceUnavailable\n");
            break;
        }
        case kAudioSessionRouteChangeReason_CategoryChange: //3
        {
            //printf("kAudioSessionRouteChangeReason_CategoryChange\n");
            break;
        }   
        case kAudioSessionRouteChangeReason_Override: //4
        {
            //printf("kAudioSessionRouteChangeReason_Override\n");
            break;
        }
            // this enum has no constant with a value of 5
        case kAudioSessionRouteChangeReason_WakeFromSleep: //6
        {
            //printf("kAudioSessionRouteChangeReason_WakeFromSleep\n");
            break;
        }
        case kAudioSessionRouteChangeReason_NoSuitableRouteForCategory:
        {
            //printf("kAudioSessionRouteChangeReason_NoSuitableRouteForCategory\n");
            break;
        }
    }
    
    /* 
     From the Apple "Handling Audio Hardware Route Changes" docs:
     
     "One of the audio hardware route change reasons in iOS is 
     kAudioSessionRouteChangeReason_CategoryChange. In other words, 
     a change in audio session category is considered by the system—in 
     this context—to be a route change, and will invoke a route change 
     property listener callback. As a consequence, such a callback—if 
     it is intended to respond only to headset plugging and unplugging—should 
     explicitly ignore this type of route change."
     
     If kAudioSessionRouteChangeReason_CategoryChange is not ignored, we could get 
     an infinite loop because the audio session category is set below, which will in
     turn trigger kAudioSessionRouteChangeReason_CategoryChange and so on.
     */
    if (reasonNumber != kAudioSessionRouteChangeReason_CategoryChange)
    {
        /*
         * Deinit the remote io and set it up again depending on if input is available. 
         */
        UInt32 isAudioInputAvailable; 
        UInt32 size = sizeof(isAudioInputAvailable);
        OSStatus result = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, 
                                                  &size, 
                                                  &isAudioInputAvailable);
        mnEnsureNoAudioSessionError(result);
        
        mnStopAndDeinitRemoteIO();
        
        int numInChannels = isAudioInputAvailable != 0 ? s_instance->requestedNumInputChannels : 0;
        UInt32 sessionCategory = numInChannels == 0 ? kAudioSessionCategory_MediaPlayback : 
                                                      kAudioSessionCategory_PlayAndRecord;
        result = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
        mnEnsureNoAudioSessionError(result);
        
        if (numInChannels > 0)
        {
            int val = 1;
            result = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, 
                                             sizeof(val), 
                                             &val);
            mnEnsureNoAudioSessionError(result);
        }

        result = AudioSessionSetActive(true);
        mnEnsureNoAudioSessionError(result); //-12986 seems to mean that kAudioSessionCategory_PlayAndRecord was set and no input is available 
        
        mnInitAndStartRemoteIO();
    }
}

void mnServerDiedCallback(void *inUserData,
                        AudioSessionPropertyID inPropertyID,
                        UInt32 inPropertyValueSize,
                        const void *inPropertyValue)
{
    //printf("server died\n");
}

void mnInitAudioSession()
{
    OSStatus status = 0;
    
    /*
     * Initialize and activte audio session
     */
    status = AudioSessionInitialize(NULL, NULL, &mnAudioSessionInterruptionCallback, s_instance);
    if (status == kAudioSessionAlreadyInitialized)
    {
        //already initialized
    }
    else
    {
        mnEnsureNoAudioSessionError(status);
        assert(status == noErr);
    }
    
    /*
     UInt32 isOtherAudioPlaying = 0;
     UInt32 propertySize = sizeof(isOtherAudioPlaying);
     status = AudioSessionGetProperty(kAudioSessionProperty_OtherAudioIsPlaying, &propertySize, &isOtherAudioPlaying);
     assert(status == noErr);
     //printf("other audio playing = %d\n", isOtherAudioPlaying);
     */
    
    //check if audio input is available at all
    
    UInt32 inputAvailable; 
    int propertySize = sizeof(inputAvailable);
    status = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &propertySize, &inputAvailable);
    assert(status == noErr);
    
    if (inputAvailable == 0)
    {
        //This device does not support audio input at this point 
        //(this may change at any time, for example when connecting
        //a headset to an iPod touch).
    }
    
    UInt32 sessionCategory = inputAvailable == 0 ? kAudioSessionCategory_MediaPlayback : 
                                                   kAudioSessionCategory_PlayAndRecord;
    status = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
    mnEnsureNoAudioSessionError(status);
    
    int val = 1;
    status = AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryDefaultToSpeaker, 
                                     sizeof(val), 
                                     &val);
    
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioInputAvailable, 
                                             &mnInputAvailableChangeCallback,
                                             s_instance);
    mnEnsureNoAudioSessionError(status);
    
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, 
                                             mnAudioRouteChangeCallback, 
                                             s_instance);
    mnEnsureNoAudioSessionError(status);
    
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_ServerDied, 
                                             mnServerDiedCallback, 
                                             s_instance);
    mnEnsureNoAudioSessionError(status);
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

void mnSetASBD(AudioStreamBasicDescription* asbd, int numChannels, float sampleRate)
{
    memset(asbd, 0, sizeof(AudioStreamBasicDescription));
    assert(numChannels == 1 || numChannels == 2);
    asbd->mBitsPerChannel = 16;
    asbd->mBytesPerFrame = 2 * numChannels;
    asbd->mBytesPerPacket = asbd->mBytesPerFrame;
    asbd->mChannelsPerFrame = numChannels;
    asbd->mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd->mFormatID = kAudioFormatLinearPCM;
    asbd->mFramesPerPacket = 1;
    asbd->mSampleRate = sampleRate;
}



