//
//  AudioEngine.m
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import "MNAudioEngine.h"

static int instanceCount = 0;

@implementation MNAudioEngine

-(id)initWithInputCallback:(mnAudioInputCallback)inputCallback
            outputCallback:(mnAudioOutputCallback)outputCallback
           callbackContext:(void*)context
                   options:(mnOptions*)optionsPtr
{
    if (instanceCount > 0) {
        @throw [NSException exceptionWithName:@"MNAudioEngineException"
                                       reason:@"Attempting to create more than one MNAudioEngine instance"
                                     userInfo:nil];
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        instanceCount++;
        if (optionsPtr) {
            memcpy(&options, optionsPtr, sizeof(mnOptions));
            useDefaultOptions = NO;
        }
        else {
            useDefaultOptions = YES;
        }
        audioInputCallback = inputCallback;
        audioOutputCallback = outputCallback;
        callbackContext = context;
    }
    
    return self;
}

-(void)dealloc
{
    instanceCount--;
}

-(void)start
{
    mnStart(audioInputCallback, audioOutputCallback, callbackContext, useDefaultOptions ? NULL : &options);
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