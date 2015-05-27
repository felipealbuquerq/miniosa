//
//  AudioEngine.m
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import "MNAudioEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#define kHasShownMicPermissionPromptSettingsKey @"kHasShownMicPermissionPromptSettingsKey"
static int instanceCount = 0;

@interface MNAudioEngine()

@property UIAlertView* micPermissionErrorAlert;

@end

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
        }
        else {
            mnOptions_setDefaults(&options);
        }
        
        audioInputCallback = inputCallback;
        audioOutputCallback = outputCallback;
        callbackContext = context;
        
        self.micPermissionErrorAlert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                  message:@"You have not given permission to access the microphone. Go to the settings menu to fix this."
                                                                 delegate:nil
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles:nil];
    }
    
    return self;
}

-(void)dealloc
{
    instanceCount--;
}

-(void)showMicrophonePermissionErrorMessage
{
    if (!hasShownMicPermissionErrorDialog) {
        hasShownMicPermissionErrorDialog = YES;
        [self.micPermissionErrorAlert show];
    }
}

-(void)startAudio
{
    mnStart(audioInputCallback, audioOutputCallback, callbackContext, &options);
}

-(void)start
{
    BOOL micNeeded = options.numberOfInputChannels > 0;
    
    if (micNeeded) {
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        
        if ([audioSession respondsToSelector:@selector(recordPermission)]) {
            //iOS8 permission flow
            
            if (audioSession.recordPermission == AVAudioSessionRecordPermissionGranted) {
                //we're good to go
                [self startAudio];
            }
            else if (audioSession.recordPermission == AVAudioSessionRecordPermissionDenied) {
                //the user has denied the app to use the mic. show an error message
                [self showMicrophonePermissionErrorMessage];
            }
            else if (audioSession.recordPermission == AVAudioSessionRecordPermissionUndetermined) {
                //the user has not yet made a decision. show prompt
                [audioSession requestRecordPermission:^(BOOL granted) {
                    [self startAudio];
                }];
            }
        }
        else {
            //iOS7 permission flow
            [audioSession requestRecordPermission:^(BOOL granted) {
                if (!granted && [[NSUserDefaults standardUserDefaults] boolForKey:kHasShownMicPermissionPromptSettingsKey]) {
                    [self showMicrophonePermissionErrorMessage];
                }
                
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kHasShownMicPermissionPromptSettingsKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                [self startAudio];
            }];
        }
    }
    else {
        [self startAudio];
    }
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