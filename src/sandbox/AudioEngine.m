//
//  AudioEngine.m
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import "AudioEngine.h"
#import "miniosa.h"

#define kSampleRate 44100

void audioInputCallback(int numChannels, int numFrames, const float* samples)
{
    float peak = 0;
    for (int i = 0; i < numFrames; i++) {
        const float value = fabsf(samples[i * numChannels]);
        if (value > peak)
        {
            peak = value;
        }
    }
    
    //printf("peak %f\n", peak);
}

void audioOutputCallback(int numChannels, int numFrames, float* samples)
{
    static float phase = 0.0f;
    
    float channelPhase = 0.0f;
    
    for (int c = 0; c < numChannels; c++)
    {
        channelPhase = phase;
        
        for (int i = 0; i < numFrames; i++)
        {
            samples[i * numChannels + c] = sinf(channelPhase) / 2.0;
            channelPhase += (2.0f * M_PI * 440.0 / (float)kSampleRate);
        }
    }
    
    phase = channelPhase;
    phase = fmodf(phase, 2.0f * M_PI);
}

@implementation AudioEngine


+(AudioEngine*)sharedInstance
{
    static AudioEngine *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

-(id)init
{
    self = [super init];
    
    if (self) {
        
    }
    
    return self;
}

-(void)start
{
    mnOptions options;
    options.sampleRate = kSampleRate;
    options.numberOfInputChannels = 1;
    options.numberOfOutputChannels = 2;
    mnStart(audioInputCallback, audioOutputCallback, (__bridge void*)self, &options);
}

-(void)stop
{
    mnStop();
}

-(void)suspend
{
    mnSuspend();
}

-(void)resume
{
    mnResume();
}


@end