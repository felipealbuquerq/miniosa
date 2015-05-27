
#include <assert.h>

#include "audiosession.h"
#include "instance.h"

#pragma mark Audio session callbacks

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
        
        int numInChannels = isAudioInputAvailable != 0 ? instance->requestedNumInputChannels : 0;
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

#pragma mark Audio session initialization
void mnInitAudioSession(mnInstance* instance)
{
    OSStatus status = 0;
    
    /*
     * Initialize and activte audio session
     */
    status = AudioSessionInitialize(NULL, NULL, &mnAudioSessionInterruptionCallback, instance);
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
                                             instance);
    mnEnsureNoAudioSessionError(status);
    
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,
                                             mnAudioRouteChangeCallback,
                                             instance);
    mnEnsureNoAudioSessionError(status);
    
    status = AudioSessionAddPropertyListener(kAudioSessionProperty_ServerDied,
                                             mnServerDiedCallback,
                                             instance);
    mnEnsureNoAudioSessionError(status);
}