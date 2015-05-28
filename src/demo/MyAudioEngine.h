//
//  MyAudioEngine.h
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//


#import "MNAudioEngine.h"
#import "fifo.h"

@interface MyAudioEngine : MNAudioEngine
{
@public
    mnFIFO toAudioThreadFifo;
    mnFIFO fromAudioThreadFifo;
}

+(MyAudioEngine*)sharedInstance;

@property (readonly) float peakLevel;
@property float toneFrequency;

-(void)update;

@end