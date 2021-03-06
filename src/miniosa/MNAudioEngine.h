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

#import <AVFoundation/AVFoundation.h>

/**
 * Audio engine options.
 */
typedef struct {
    float sampleRate;
    int numberOfInputChannels;
    int numberOfOutputChannels;
    int bufferSizeInFrames;
} MNOptions;

/**
 * A callback for receiving input audio buffers.
 * @param numChannels The number of input channels.
 * @param numFrames The number of input frames.
 * @param samples The input sample buffer. Samples are interleaved, so sample for
 * channel i of frame j is at \c samples[j * numChannels + i].
 * @param callbackContext A user specified pointer.
 */
typedef void (*mnAudioInputCallback)(int numChannels,
                                     int numFrames,
                                     const float* samples,
                                     void* callbackContext);

/**
 * A callback for rendering output audio buffers.
 * @param numChannels The number of output channels.
 * @param numFrames The number of output frames.
 * @param samples The target output buffer Samples are interleaved, so sample for 
 * channel i of frame j is at \c samples[j * numChannels + i].
 * @param callbackContext A user specified pointer.
 */
typedef void (*mnAudioOutputCallback)(int numChannels,
                                      int numFrames,
                                      float* samples,
                                      void* callbackContext);

/**
 *
 */
@interface MNAudioEngine : NSObject<AVAudioSessionDelegate>

/**
 * If the user has not granted the app access to the microphone, an
 * alert view is shown if starting the audio engine with input enabled. These properties
 * allow customization of this alert view. If not set, sensible default values are used.
 */
@property NSString* micPermissionAlertTitle;
@property NSString* micPermissionAlertMessage;
@property NSString* micPermissionAlertButtonText;

/**
 * Creates a new audio engine instance.
 * @param inputCallback A callback for receiving input audio data. Ignored if NULL.
 * @param outputCallback A callback for rendering output audio data. Ignored if NULL.
 * @param callbackContext A pointer to pass to \c inputCallback and \c outputCallback.
 * @param options Optional audio I/O options.
 */
-(id)initWithInputCallback:(mnAudioInputCallback)inputCallback
            outputCallback:(mnAudioOutputCallback)outputCallback
           callbackContext:(void*)context
                   options:(MNOptions*)options;

-(void)start;

-(void)stop;

-(void)suspend;

-(void)resume;

@end