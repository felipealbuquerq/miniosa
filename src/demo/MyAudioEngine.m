//
//  AudioEngine.m
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import "MyAudioEngine.h"

#define kSampleRate 44100
#define kFIFOCapacity 100

typedef struct {
    float value;
} Event;

#pragma mark Audio buffer callbacks
void inputBufferCallback(int numChannels, int numFrames, const float* samples, void* callbackContext)
{
    MyAudioEngine* audioEngine = (__bridge MyAudioEngine*)callbackContext;
    
    float smoothedPeak = audioEngine->smoothedPeakValue;
    float peak = 0;
    for (int i = 0; i < numFrames; i++) {
        const float value = fabsf(samples[i * numChannels]);
        
        const float a = value > smoothedPeak ? 0.1 : 0.99995;
        smoothedPeak = a * smoothedPeak + (1.0f - a) * value;
        
        if (value > peak)
        {
            peak = value;
        }
    }
    
    audioEngine->smoothedPeakValue = smoothedPeak;
    
    Event e;
    e.value = powf(smoothedPeak, 0.5);
    mnFIFO_push(&audioEngine->fromAudioThreadFifo, &e);
}

void outputBufferCallback(int numChannels, int numFrames, float* samples, void* callbackContext)
{
    MyAudioEngine* audioEngine = (__bridge MyAudioEngine*)callbackContext;
    
    while (!mnFIFO_isEmpty(&audioEngine->toAudioThreadFifo))
    {
        Event event;
        mnFIFO_pop(&audioEngine->toAudioThreadFifo, &event);
        audioEngine->targetToneFrequency = event.value;
    }
    
    const float targetFrequency = audioEngine->targetToneFrequency;
    static float phase = 0.0f;
    
    const float frequencySmoothing = 0.9995f;
    float channelPhase = 0.0f;
    float channelFrequency = 0.0;
    
    for (int c = 0; c < numChannels; c++)
    {
        channelFrequency = audioEngine->smoothedToneFrequency;
        channelPhase = phase;
        
        for (int i = 0; i < numFrames; i++)
        {
            samples[i * numChannels + c] = sinf(channelPhase) / 2.0;
            channelPhase += (2.0f * M_PI * channelFrequency / (float)kSampleRate);
            channelFrequency = frequencySmoothing * channelFrequency + (1.0f - frequencySmoothing) * targetFrequency;
        }
    }
    
    audioEngine->smoothedToneFrequency = channelFrequency;
    phase = channelPhase;
    phase = fmodf(phase, 2.0f * M_PI);
}

#pragma mark MyAudioEngine

@implementation MyAudioEngine

+(MyAudioEngine*)sharedInstance
{
    static MyAudioEngine *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(id)init
{
    MNOptions options;
    options.sampleRate = kSampleRate;
    options.numberOfInputChannels = 1;
    options.numberOfOutputChannels = 2;
    
    self = [super initWithInputCallback:inputBufferCallback
                         outputCallback:outputBufferCallback
                        callbackContext:(void*)self
                                options:&options];

    if (self) {
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
    
    [self.delegate inputLevelChanged:self.peakLevel];
}


@end