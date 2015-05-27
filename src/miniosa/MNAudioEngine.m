//
//  AudioEngine.m
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import "MNAudioEngine.h"

#define kSampleRate 44100

static int instanceCount = 0;

@implementation MNAudioEngine

-(id)initWithInputCallback:(mnAudioInputCallback)inputCallback
            outputCallback:(mnAudioOutputCallback)outputCallback
           callbackContext:(void*)context
                   options:(mnOptions*)optionsPtr
{
    self = [super init];
    
    if (instanceCount > 0) {
        return nil;
    }
    
    if (self) {
        instanceCount++;
        options = optionsPtr;
        audioInputCallback = inputCallback;
        audioOutputCallback = outputCallback;
        callbackContext = context;
    }
    
    return self;
}

-(void)start
{
    mnStart(audioInputCallback, audioOutputCallback, callbackContext, options);
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