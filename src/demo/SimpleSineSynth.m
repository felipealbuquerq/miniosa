/*
 The MIT License (MIT)
 
 Copyright (c) 2015 Per Gantelius
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#import "SimpleSineSynth.h"

#define kSampleRate 44100
#define kFIFOCapacity 100
typedef enum {
    EVENT_INPUT_LEVEL = 0,
    EVENT_OUTPUT_LEVEL = 1,
    EVENT_TONE_AMPLITUDE = 2,
    EVENT_TONE_FREQUENCY = 3

} EventType;

typedef struct {
    EventType type;
    float value;
} Event;

#pragma mark Audio buffer callbacks
void inputBufferCallback(int numChannels, int numFrames, const float* samples, void* callbackContext)
{
    SimpleSineSynth* audioEngine = (__bridge SimpleSineSynth*)callbackContext;
 
    float smoothedPeak = audioEngine->smoothedInputPeakValue;
    float peak = 0;
    for (int i = 0; i < numFrames; i++) {
        const float value = fabsf(samples[i * numChannels]);
        
        const float a = value > smoothedPeak ? 0.1 : 0.99995;
        smoothedPeak = a * smoothedPeak + (1.0f - a) * value;
        
        if (value > peak) {
            peak = value;
        }
    }
    
    audioEngine->smoothedInputPeakValue = smoothedPeak;
    
    //pass the smoothed peak value to the main thread.
    Event e;
    e.type = EVENT_INPUT_LEVEL;
    e.value = smoothedPeak;
    mnFIFO_push(&audioEngine->fromAudioThreadFifo, &e);
}

void outputBufferCallback(int numChannels, int numFrames, float* samples, void* callbackContext)
{
    SimpleSineSynth* audioEngine = (__bridge SimpleSineSynth*)callbackContext;
    
    while (!mnFIFO_isEmpty(&audioEngine->toAudioThreadFifo)) {
        Event event;
        mnFIFO_pop(&audioEngine->toAudioThreadFifo, &event);
        
        if (event.type == EVENT_TONE_AMPLITUDE) {
            audioEngine->targetToneAmplitude = event.value;
        }
        else if (event.type == EVENT_TONE_FREQUENCY) {
            audioEngine->targetToneFrequency = event.value;
        }
    }
    
    const float targetAmplitude = audioEngine->targetToneAmplitude;
    const float targetFrequency = audioEngine->targetToneFrequency;
    
    const float amplitudeSmoothing = 0.999f;
    const float frequencySmoothing = 0.9995f;
    

    for (int c = 0; c < numChannels; c++) {
        if (c == 0) {
            //render first channel
            float phase = audioEngine->sinePhase;
            float amplitude = audioEngine->smoothedToneAmplitude;
            float frequency = audioEngine->smoothedToneFrequency;
            float smoothedOutputLevel = audioEngine->smoothedOutputPeakValue;
            
            for (int i = 0; i < numFrames; i++) {
                const float value = amplitude * sinf(phase);
                
                const float a = value > smoothedOutputLevel ? 0.1 : 0.99995;
                smoothedOutputLevel = a * smoothedOutputLevel + (1.0f - a) * value;
                
                samples[i * numChannels + c] = value;
                
                phase += (2.0f * M_PI * frequency / (float)kSampleRate);
                
                frequency = frequencySmoothing * frequency +
                            (1.0f - frequencySmoothing) * targetFrequency;
                amplitude = amplitudeSmoothing * amplitude +
                            (1.0f - amplitudeSmoothing) * targetAmplitude;
            }
            
            audioEngine->smoothedToneAmplitude = amplitude;
            audioEngine->smoothedToneFrequency = frequency;
            audioEngine->sinePhase = fmodf(phase, 2.0f * M_PI);
            audioEngine->smoothedOutputPeakValue = smoothedOutputLevel;
            
            //pass the smoothed peak value to the main thread.
            Event e;
            e.type = EVENT_OUTPUT_LEVEL;
            e.value = smoothedOutputLevel;
            mnFIFO_push(&audioEngine->fromAudioThreadFifo, &e);
        }
        else {
            //copy rendered channel
            for (int i = 0; i < numFrames; i++) {
                samples[i * numChannels + c] = samples[i * numChannels];
            }
        }
    }
}

#pragma mark SimpleSineSynth

@implementation SimpleSineSynth

+(SimpleSineSynth*)sharedInstance
{
    static SimpleSineSynth *sharedInstance = nil;
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
    options.bufferSizeInFrames = 512;
    
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

-(void)dealloc
{
    mnFIFO_deinit(&toAudioThreadFifo);
    mnFIFO_deinit(&fromAudioThreadFifo);
}

-(void)update
{
    //process incoming level events
    while (!mnFIFO_isEmpty(&fromAudioThreadFifo)) {
        Event event;
        mnFIFO_pop(&fromAudioThreadFifo, &event);
        if (event.type == EVENT_INPUT_LEVEL) {
            _inputLevel = event.value;
        }
        else if (event.type == EVENT_OUTPUT_LEVEL) {
            _outputLevel = event.value;
        }
    }
    
    //send control events
    Event event;
    event.type = EVENT_TONE_FREQUENCY;
    event.value = self.toneFrequency;
    mnFIFO_push(&toAudioThreadFifo, &event);
    
    event.type = EVENT_TONE_AMPLITUDE;
    event.value = self.toneAmplitude;
    mnFIFO_push(&toAudioThreadFifo, &event);
    
    //notify delegate of level changes (powf for nicer falloff)
    [self.delegate inputLevelChanged:powf(self.inputLevel, 0.4f)];
    [self.delegate outputLevelChanged:powf(self.outputLevel, 0.4f)];
}


@end