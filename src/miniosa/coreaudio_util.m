
#include <assert.h>
#include <AVFoundation/AVFoundation.h>
#include <AudioUnit/AudioUnit.h>

#include "coreaudio_util.h"

void mnEnsureNoAudioUnitError(OSStatus result)
{
    switch (result)
    {
        case kAudioUnitErr_InvalidProperty:
            assert(0 && "kAudioUnitErr_InvalidProperty");
            break;
        case kAudioUnitErr_InvalidParameter:
            assert(0 && "kAudioUnitErr_InvalidParameter");
            break;
        case kAudioUnitErr_InvalidElement:
            assert(0 && "kAudioUnitErr_InvalidElement");
            break;
        case kAudioUnitErr_NoConnection:
            assert(0 && "kAudioUnitErr_NoConnection");
            break;
        case kAudioUnitErr_FailedInitialization:
            assert(0 && "kAudioUnitErr_FailedInitialization");
            break;
        case kAudioUnitErr_TooManyFramesToProcess:
            assert(0 && "kAudioUnitErr_TooManyFramesToProcess");
            break;
        case kAudioUnitErr_InvalidFile:
            assert(0 && "kAudioUnitErr_InvalidFile");
            break;
        case kAudioUnitErr_FormatNotSupported:
            assert(0 && "kAudioUnitErr_FormatNotSupported");
            break;
        case kAudioUnitErr_Uninitialized:
            assert(0 && "kAudioUnitErr_Uninitialized");
            break;
        case kAudioUnitErr_InvalidScope:
            assert(0 && "kAudioUnitErr_InvalidScope");
            break;
        case kAudioUnitErr_PropertyNotWritable:
            assert(0 && "kAudioUnitErr_PropertyNotWritable");
            break;
        case kAudioUnitErr_CannotDoInCurrentContext:
            assert(0 && "kAudioUnitErr_CannotDoInCurrentContext");
            break;
        case kAudioUnitErr_InvalidPropertyValue:
            assert(0 && "kAudioUnitErr_InvalidPropertyValue");
            break;
        case kAudioUnitErr_PropertyNotInUse:
            assert(0 && "kAudioUnitErr_PropertyNotInUse");
            break;
        case kAudioUnitErr_Initialized:
            assert(0 && "kAudioUnitErr_Initialized");
            break;
        case kAudioUnitErr_InvalidOfflineRender:
            assert(0 && "kAudioUnitErr_InvalidOfflineRender");
            break;
        case kAudioUnitErr_Unauthorized:
            assert(0 && "kAudioUnitErr_Unauthorized");
            break;
        default:
            assert(result == noErr);
            break;
    }
}

void mnEnsureNoAudioSessionError(OSStatus result)
{
    switch (result)
    {
        case kAudioSessionNotActiveError:
            assert(0 && "kAudioSessionNotActiveError");
            break;
        case kAudioSessionNotInitialized:
            assert(0 && "kAudioSessionNotInitialized");
            break;
        case kAudioSessionAlreadyInitialized:
            assert(0 && "kAudioSessionAlreadyInitialized");
            break;
        case kAudioSessionInitializationError:
            assert(0 && "kAudioSessionInitializationError");
            break;
        case kAudioSessionUnsupportedPropertyError:
            assert(0 && "kAudioSessionUnsupportedPropertyError");
            break;
        case kAudioSessionBadPropertySizeError:
            assert(0 && "kAudioSessionBadPropertySizeError");
            break;
        case kAudioServicesNoHardwareError:
            assert(0 && "kAudioServicesNoHardwareError");
            break;
        case kAudioSessionNoCategorySet:
            assert(0 && "kAudioSessionNoCategorySet");
            break;
        case kAudioSessionIncompatibleCategory:
            assert(0 && "kAudioSessionIncompatibleCategory");
            break;
        case kAudioSessionUnspecifiedError:
            assert(0 && "kAudioSessionUnspecifiedError");
            break;
        default:
            assert(result == noErr);
            break;
    }
}

void mnDebugPrintAudioSessionInfo()
{
    NSString* category = [AVAudioSession sharedInstance].category;
    int numOutChannels = [AVAudioSession sharedInstance].outputNumberOfChannels;
    int numInChannels = [AVAudioSession sharedInstance].inputNumberOfChannels;
    
    printf("    Audio session info:\n");
    printf("        category %s\n", [category UTF8String]);
    printf("        n in ch  %d\n", numInChannels);
    printf("        n out ch %d\n", numOutChannels);
}

void mnDebugPrintRemoteIOInfo(AudioUnit audioUnit)
{
    AudioStreamBasicDescription outFmt;
    UInt32 sz = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input,
                         0,
                         &outFmt,
                         &sz);
    
    AudioStreamBasicDescription inFmt;
    sz = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty(audioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         1,
                         &inFmt,
                         &sz);
    
    printf("    Remote IO info:\n");
    printf("        Input bits/channel %ld\n", inFmt.mBitsPerChannel);
    printf("        Input bytes/frame %ld\n", inFmt.mBytesPerFrame);
    printf("        Input bytes/packet %ld\n", inFmt.mBytesPerPacket);
    printf("        Input channels/frame %ld\n", inFmt.mChannelsPerFrame);
    printf("        Input format flags %ld\n", inFmt.mFormatFlags);
    printf("        Input format ID %ld\n", inFmt.mFormatID);
    printf("        Input frames per packet %ld\n", inFmt.mFramesPerPacket);
    printf("        Input sample rate %lf\n", inFmt.mSampleRate);
    printf("\n");
    printf("        Output bits/channel %ld\n", outFmt.mBitsPerChannel);
    printf("        Output bytes/frame %ld\n", outFmt.mBytesPerFrame);
    printf("        Output bytes/packet %ld\n", outFmt.mBytesPerPacket);
    printf("        Output channels/frame %ld\n", outFmt.mChannelsPerFrame);
    printf("        Output format flags %ld\n", outFmt.mFormatFlags);
    printf("        Output format ID %ld\n", outFmt.mFormatID);
    printf("        Output frames per packet %ld\n", outFmt.mFramesPerPacket);
    printf("        Output sample rate %f\n", outFmt.mSampleRate);
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