//
//  MNAudioEngine.h
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

typedef struct {
    float sampleRate;
    int numberOfInputChannels;
    int numberOfOutputChannels;
    int bufferSizeInFrames;
} MNOptions;

typedef void (*mnAudioInputCallback)(int numChannels, int numFrames, const float* samples, void* callbackContext);

typedef void (*mnAudioOutputCallback)(int numChannels, int numFrames, float* samples, void* callbackContext);

typedef struct {

    mnAudioInputCallback inputCallback;
    mnAudioOutputCallback outputCallback;
    void* userCallbackContext;
    AudioComponentInstance remoteIOInstance;
    /** A buffer list for storing input samples. */
    AudioBufferList inputBufferList;
    /** The size in bytes of the input sample buffer. */
    int inputBufferSizeInBytes;
    
    float* inputScratchBuffer;
    float* outputScratchBuffer;
} CoreAudioCallbackContext;


@interface MNAudioEngine : NSObject<AVAudioSessionDelegate>
{
@private
    MNOptions desiredOptions;
    BOOL hasShownMicPermissionErrorDialog;
    
    CoreAudioCallbackContext caCallbackContext;
}

-(id)initWithInputCallback:(mnAudioInputCallback)inputCallback
            outputCallback:(mnAudioOutputCallback)outputCallback
           callbackContext:(void*)context
                   options:(MNOptions*)options;

-(void)start;

-(void)stop;

-(void)suspend;

-(void)resume;

@end