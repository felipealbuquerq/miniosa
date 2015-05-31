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

#import "MNAudioEngine.h"
#import "fifo.h"

@protocol SimpleSineSynthDelegate <NSObject>

-(void)inputLevelChanged:(float)newLevel;

-(void)outputLevelChanged:(float)newLevel;

@end

/**
 * A primitive proof of concept sine wave synthesizer.
 */
@interface SimpleSineSynth : MNAudioEngine
{
@public
    mnFIFO toAudioThreadFifo;
    mnFIFO fromAudioThreadFifo;
    
    float targetToneFrequency;
    float smoothedToneFrequency;
    
    float targetToneAmplitude;
    float smoothedToneAmplitude;
    
    float smoothedInputPeakValue;
    float smoothedOutputPeakValue;
    
    float sinePhase;
}

+(SimpleSineSynth*)sharedInstance;

@property (readonly) float inputLevel;
@property (readonly) float outputLevel;
@property float toneFrequency;
@property float toneAmplitude;
@property (nonatomic, weak) id <SimpleSineSynthDelegate> delegate;

-(void)update;

@end