//
//  AudioEngine.h
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "fifo.h"

@interface AudioEngine : NSObject
{
@public
    mnFIFO toAudioThreadFifo;
    mnFIFO fromAudioThreadFifo;
}

@property (readonly) float peakLevel;

@property float toneFrequency;

+(AudioEngine*)sharedInstance;

-(void)start;

-(void)stop;

-(void)suspend;

-(void)resume;

-(void)update;

@end