//
//  MNAudioEngine.h
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "miniosa.h"

@interface MNAudioEngine : NSObject
{
@private
    mnAudioInputCallback audioInputCallback;
    mnAudioOutputCallback audioOutputCallback;
    BOOL useDefaultOptions;
    mnOptions options;
    void* callbackContext;
}

-(id)initWithInputCallback:(mnAudioInputCallback)inputCallback
            outputCallback:(mnAudioOutputCallback)outputCallback
           callbackContext:(void*)context
                   options:(mnOptions*)options;

-(void)start;

-(void)stop;

-(void)suspend;

-(void)resume;

@end