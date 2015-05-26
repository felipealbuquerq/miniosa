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
#define kFIFOCapacity 100

typedef struct {
    float value;
} Event;

void audioInputCallback(int numChannels, int numFrames, const float* samples, void* callbackContext)
{
    AudioEngine* audioEngine = (__bridge AudioEngine*)callbackContext;
    
    float peak = 0;
    for (int i = 0; i < numFrames; i++) {
        const float value = fabsf(samples[i * numChannels]);
        if (value > peak)
        {
            peak = value;
        }
    }
    
    Event e;
    e.value = peak;
    mnFIFO_push(&audioEngine->fromAudioThreadFifo, &e);
    
}

void audioOutputCallback(int numChannels, int numFrames, float* samples, void* callbackContext)
{
    AudioEngine* audioEngine = (__bridge AudioEngine*)callbackContext;
    
    static float frequency = 0.0f;
    
    while (!mnFIFO_isEmpty(&audioEngine->toAudioThreadFifo))
    {
        Event event;
        mnFIFO_pop(&audioEngine->toAudioThreadFifo, &event);
        frequency = event.value;
    }
    
    static float phase = 0.0f;
    
    float channelPhase = 0.0f;
    
    for (int c = 0; c < numChannels; c++)
    {
        channelPhase = phase;
        
        for (int i = 0; i < numFrames; i++)
        {
            samples[i * numChannels + c] = sinf(channelPhase) / 2.0;
            channelPhase += (2.0f * M_PI * frequency / (float)kSampleRate);
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
        self.toneFrequency = 440.0f;
        mnFIFO_init(&toAudioThreadFifo, kFIFOCapacity, sizeof(Event));
        mnFIFO_init(&fromAudioThreadFifo, kFIFOCapacity, sizeof(Event));
    }
    
    return self;
}

-(void)update
{
    while (!mnFIFO_isEmpty(&fromAudioThreadFifo))
    {
        Event event;
        mnFIFO_pop(&fromAudioThreadFifo, &event);
        _peakLevel = event.value;
    }
    
    Event event;
    event.value = self.toneFrequency;
    mnFIFO_push(&toAudioThreadFifo, &event);
    
    printf("peak level is %f\n", self.peakLevel);
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