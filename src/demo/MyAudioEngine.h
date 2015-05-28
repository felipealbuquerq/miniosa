//
//  MyAudioEngine.h
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//


#import "MNAudioEngine.h"
#import "fifo.h"

@protocol MyAudioEngineDelegate <NSObject>

-(void)inputLevelChanged:(float)newLevel;

@end

@interface MyAudioEngine : MNAudioEngine
{
@public
    mnFIFO toAudioThreadFifo;
    mnFIFO fromAudioThreadFifo;
    
    float smoothedToneFrequency;
    float targetToneFrequency;
    
    float smoothedPeakValue;
}

+(MyAudioEngine*)sharedInstance;

@property (readonly) float peakLevel;
@property float toneFrequency;
@property (nonatomic, weak) id <MyAudioEngineDelegate> delegate;

-(void)update;

@end