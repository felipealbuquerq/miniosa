//
//  AudioEngine.m
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import "mem.h"
#import "MNAudioEngine.h"

#import <UIKit/UIKit.h>


#pragma mark Buffer conversion helpers

/**
 * Converts a buffer of floats to a buffer of signed shorts. The floats are assumed
 * to be in the range [-1, 1].
 * @param sourceBuffer The buffer containing the values to convert.
 * @param targetBuffer The buffer to write converted samples to.
 * @param size The size of the source and target buffers.
 */
static inline void mnFloatToInt16(const float* sourceBuffer, short* targetBuffer, int size)
{
    assert(sourceBuffer != NULL);
    assert(targetBuffer != NULL);
    
    int i = 0;
    while (i < size)
    {
        targetBuffer[i] = (short)(32767 * sourceBuffer[i]);
        i++;
    }
}

/**
 * Converts a buffer of signed short values to a buffer of floats
 * in the range [-1, 1].
 * @param sourceBuffer The buffer containing the values to convert.
 * @param targetBuffer The buffer to write converted samples to.
 * @param size The size of the source and target buffers.
 */
static inline void mnInt16ToFloat(const short* sourceBuffer, float* targetBuffer, int size)
{
    assert(sourceBuffer != NULL);
    assert(targetBuffer != NULL);
    
    int i = 0;
    while (i < size)
    {
        targetBuffer[i] = (float)(sourceBuffer[i] / 32768.0);
        i++;
    }
}

#pragma mark Core audio buffer callbacks
static OSStatus mnCoreAudioInputCallback(void *inRefCon,
                                         AudioUnitRenderActionFlags *ioActionFlags,
                                         const AudioTimeStamp *inTimeStamp,
                                         UInt32 inBusNumber,
                                         UInt32 inNumberFrames,
                                         AudioBufferList *ioData)
{
    CoreAudioCallbackContext* context = (CoreAudioCallbackContext*)inRefCon;
    
    context->inputBufferList.mBuffers[0].mDataByteSize = context->inputBufferSizeInBytes;
    //fill the already allocated input buffer list with samples
    OSStatus status;
    status = AudioUnitRender(context->remoteIOInstance,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             &context->inputBufferList);
    assert(status == 0);
    
    const int numChannels = context->inputBufferList.mBuffers[0].mNumberChannels;
    const short* sourceBuffer = (short*)context->inputBufferList.mBuffers[0].mData;
    
    //Convert input buffer samples to floats
    mnInt16ToFloat(sourceBuffer,
                   context->inputScratchBuffer,
                   inNumberFrames * numChannels);
    
    //Pass the converted buffer to the user
    if (context->inputCallback)
    {
        context->inputCallback(numChannels, inNumberFrames, context->inputScratchBuffer, context->userCallbackContext);
    }
    
    return noErr;
}

static OSStatus mnCoreAudioOutputCallback(void *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData)
{
    //#define KWL_DEBUG_CA_DEADLINE
#ifdef KWL_DEBUG_CA_DEADLINE
    static double prevDelta = 0.0;
    static double ht = 0.0;
    double delta = inTimeStamp->mSampleTime - ht;
    ht = inTimeStamp->mSampleTime;
    if (delta > inNumberFrames && prevDelta > 0.0)
    {
        printf("missed deadline, time since prev callback: %f samples, curr buffer size %d samples\n", delta, inNumberFrames);
        //mnDebugPrintAudioSessionInfo();
        //mnDebugPrintRemoteIOInfo();
    }
    prevDelta = delta;
#endif
    
    CoreAudioCallbackContext* context = (CoreAudioCallbackContext*)inRefCon;
    
    const int numChannels = ioData->mBuffers[0].mNumberChannels;
    
    //let the user render some audio
    if (context->outputCallback) {
        context->outputCallback(numChannels, inNumberFrames, context->outputScratchBuffer, context->userCallbackContext);
        
        //convert the float samples and copy them to the target buffer
        short* targetBuffer = (short*)ioData->mBuffers[0].mData;
        mnFloatToInt16(context->outputScratchBuffer,
                       targetBuffer,
                       inNumberFrames * numChannels);
    }
    
    return noErr;
}

#define kHasShownMicPermissionPromptSettingsKey @"kHasShownMicPermissionPromptSettingsKey"
static int instanceCount = 0;

@interface MNAudioEngine()

@property UIAlertView* micPermissionErrorAlert;

@end

@implementation MNAudioEngine

#pragma mark Lifecycle
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
        
        caCallbackContext.inputCallback = inputCallback;
        caCallbackContext.outputCallback = outputCallback;
        caCallbackContext.userCallbackContext = context;
        
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

#pragma mark Logging
-(void)logAudioSessionRouteChange:(NSString*)message
{
    NSLog(@"AVAudioSession route change: %@", message);
}

#pragma mark Microphone permission stuff
-(void)showMicrophonePermissionErrorMessage
{
    if (!hasShownMicPermissionErrorDialog) {
        hasShownMicPermissionErrorDialog = YES;
        [self.micPermissionErrorAlert show];
    }
}

#pragma mark Start/stop/resume/suspend
-(void)startAudio
{
    [self activateAudioSession];
    [self createRemoteIOInstance];
    [self startRemoteIOInstance];
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
    [self stopRemoteIOInstance];
    [self destroyRemoteIOInstance];
    [self deactivateAudioSession];
}

-(void)suspend
{
    [self stopRemoteIOInstance];
    [self deactivateAudioSession];
}

-(void)resume
{
    [self activateAudioSession];
    [self startRemoteIOInstance];
}

#pragma mark Remote IO

-(void)ensureNoAudioUnitError:(OSStatus)result
{
#ifdef DEBUG
    switch (result)
    {
        case kAudioUnitErr_InvalidProperty:
            assert(0 && "kAudioUnitErr_InvalidProperty");
            break;
        case kAudioUnitErr_InvalidParameter:
            assert(0 && "kAudioUnitErr_InvalidParameter");
            break;
        case kAudioUnitErr_InvalidElement:
            assert(0 && "kAudioUnitErr_InvalidElement");
            break;
        case kAudioUnitErr_NoConnection:
            assert(0 && "kAudioUnitErr_NoConnection");
            break;
        case kAudioUnitErr_FailedInitialization:
            assert(0 && "kAudioUnitErr_FailedInitialization");
            break;
        case kAudioUnitErr_TooManyFramesToProcess:
            assert(0 && "kAudioUnitErr_TooManyFramesToProcess");
            break;
        case kAudioUnitErr_InvalidFile:
            assert(0 && "kAudioUnitErr_InvalidFile");
            break;
        case kAudioUnitErr_FormatNotSupported:
            assert(0 && "kAudioUnitErr_FormatNotSupported");
            break;
        case kAudioUnitErr_Uninitialized:
            assert(0 && "kAudioUnitErr_Uninitialized");
            break;
        case kAudioUnitErr_InvalidScope:
            assert(0 && "kAudioUnitErr_InvalidScope");
            break;
        case kAudioUnitErr_PropertyNotWritable:
            assert(0 && "kAudioUnitErr_PropertyNotWritable");
            break;
        case kAudioUnitErr_CannotDoInCurrentContext:
            assert(0 && "kAudioUnitErr_CannotDoInCurrentContext");
            break;
        case kAudioUnitErr_InvalidPropertyValue:
            assert(0 && "kAudioUnitErr_InvalidPropertyValue");
            break;
        case kAudioUnitErr_PropertyNotInUse:
            assert(0 && "kAudioUnitErr_PropertyNotInUse");
            break;
        case kAudioUnitErr_Initialized:
            assert(0 && "kAudioUnitErr_Initialized");
            break;
        case kAudioUnitErr_InvalidOfflineRender:
            assert(0 && "kAudioUnitErr_InvalidOfflineRender");
            break;
        case kAudioUnitErr_Unauthorized:
            assert(0 && "kAudioUnitErr_Unauthorized");
            break;
        default:
            assert(result == noErr);
            break;
    }
#endif //DEBUG
}

-(void)setASBD:(AudioStreamBasicDescription*)asbd
              :(int)numChannels
              :(float)sampleRate
{
    memset(asbd, 0, sizeof(AudioStreamBasicDescription));
    assert(numChannels == 1 || numChannels == 2);
    asbd->mBitsPerChannel = 16;
    asbd->mBytesPerFrame = 2 * numChannels;
    asbd->mBytesPerPacket = asbd->mBytesPerFrame;
    asbd->mChannelsPerFrame = numChannels;
    asbd->mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd->mFormatID = kAudioFormatLinearPCM;
    asbd->mFramesPerPacket = 1;
    asbd->mSampleRate = sampleRate;
}

-(void)createRemoteIOInstance
{
    if (caCallbackContext.remoteIOInstance) {
        [self destroyRemoteIOInstance];
    }
    
    //create audio component description
    AudioComponentDescription auDescription;
    
    auDescription.componentType          = kAudioUnitType_Output;
    auDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
    auDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    auDescription.componentFlags         = 0;
    auDescription.componentFlagsMask     = 0;
    
    //get a component reference
    AudioComponent auComponent = AudioComponentFindNext(NULL, &auDescription);
    
    //get the actual instance
    OSStatus status = AudioComponentInstanceNew(auComponent, &caCallbackContext.remoteIOInstance);
    assert(status == noErr);
    
    //Get an upper limit on the number of frames that an audio callback
    //will request/provide. This number is used to allocate buffers.
    int maxNumberOfFramesPerSlice = 0;
    UInt32 s = sizeof(maxNumberOfFramesPerSlice);
    status = AudioUnitGetProperty(caCallbackContext.remoteIOInstance,
                                           kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global,
                                           0,
                                           &maxNumberOfFramesPerSlice,
                                           &s);
    [self ensureNoAudioUnitError:status];
    
    //enable input/output
    const int numInChannels = options.numberOfInputChannels;
    const int numOutChannels = options.numberOfOutputChannels;
    const float sampleRate = options.sampleRate;
    
    const unsigned int OUTPUT_BUS_ID = 0;
    const unsigned int INPUT_BUS_ID = 1;
    
    if (numOutChannels > 0)
    {
        //enable playback if requested
        UInt32 flag = 1;
        status = AudioUnitSetProperty(caCallbackContext.remoteIOInstance,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS_ID,
                                      &flag,
                                      sizeof(flag));
        [self ensureNoAudioUnitError:status];
        
        //Set output format
        AudioStreamBasicDescription outputFormat;
        [self setASBD:&outputFormat :numOutChannels :sampleRate];
        status = AudioUnitSetProperty(caCallbackContext.remoteIOInstance,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      OUTPUT_BUS_ID,
                                      &outputFormat,
                                      sizeof(outputFormat));
        [self ensureNoAudioUnitError:status];
        
        //Allocate buffer for storing float output values passed to the user
        caCallbackContext.outputScratchBuffer = MN_MALLOC(maxNumberOfFramesPerSlice * sizeof(float) * numInChannels, "output scratch buffer");
        
        //Hook up output callback
        AURenderCallbackStruct renderCallbackStruct;
        renderCallbackStruct.inputProc = mnCoreAudioOutputCallback;
        renderCallbackStruct.inputProcRefCon = &caCallbackContext;
        
        [self ensureNoAudioUnitError:AudioUnitSetProperty(caCallbackContext.remoteIOInstance,
                                                          kAudioUnitProperty_SetRenderCallback,
                                                          kAudioUnitScope_Global,
                                                          OUTPUT_BUS_ID,
                                                          &renderCallbackStruct,
                                                          sizeof(renderCallbackStruct))];
    }
    
    if (numInChannels > 0)
    {
        //Enable recording if requested
        UInt32 flag = 1;
        status = AudioUnitSetProperty(caCallbackContext.remoteIOInstance,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      INPUT_BUS_ID,
                                      &flag,
                                      sizeof(flag));
        [self ensureNoAudioUnitError:status];
    
        //Set input format
        AudioStreamBasicDescription inputFormat;
        [self setASBD:&inputFormat :numInChannels :sampleRate];
        
        status = AudioUnitSetProperty(caCallbackContext.remoteIOInstance,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      INPUT_BUS_ID,
                                      &inputFormat,
                                      sizeof(inputFormat));
        [self ensureNoAudioUnitError:status];
        
        //Allocate buffer containing raw input samples
        memset(&caCallbackContext.inputBufferList, 0, sizeof(AudioBufferList));
        caCallbackContext.inputBufferList.mNumberBuffers = 1;
        caCallbackContext.inputBufferList.mBuffers[0].mNumberChannels = numInChannels;
        caCallbackContext.inputBufferSizeInBytes = 2 * numInChannels * maxNumberOfFramesPerSlice;
        caCallbackContext.inputBufferList.mBuffers[0].mDataByteSize = caCallbackContext.inputBufferSizeInBytes;
        caCallbackContext.inputBufferList.mBuffers[0].mData = MN_MALLOC(caCallbackContext.inputBufferList.mBuffers[0].mDataByteSize, "inputBufferList sample data");
        
        //Allocate buffer for storing float input values passed to the user
        caCallbackContext.inputScratchBuffer = MN_MALLOC(maxNumberOfFramesPerSlice * sizeof(float) * numInChannels, "input scratch buffer");
        
        //Hook up input callback
        AURenderCallbackStruct renderCallbackStruct;
        renderCallbackStruct.inputProc = mnCoreAudioInputCallback;
        renderCallbackStruct.inputProcRefCon = &caCallbackContext;
        
        status = AudioUnitSetProperty(caCallbackContext.remoteIOInstance,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      OUTPUT_BUS_ID,
                                      &renderCallbackStruct,
                                      sizeof(renderCallbackStruct));
        [self ensureNoAudioUnitError:status];
        
    }
    
    assert(status == noErr);
    
    //Initialize the audio unit, which is now ready to start.
    [self ensureNoAudioUnitError:AudioUnitInitialize(caCallbackContext.remoteIOInstance)];
}

-(void)startRemoteIOInstance
{
    if (caCallbackContext.remoteIOInstance) {
        [self ensureNoAudioUnitError:AudioOutputUnitStart(caCallbackContext.remoteIOInstance)];
    }
}

-(void)stopRemoteIOInstance
{
    if (caCallbackContext.remoteIOInstance) {
        [self ensureNoAudioUnitError:AudioOutputUnitStop(caCallbackContext.remoteIOInstance)];
    }
}

-(void)destroyRemoteIOInstance
{
    if (caCallbackContext.remoteIOInstance) {
        //stop and destroy the instance
        [self stopRemoteIOInstance];
        [self ensureNoAudioUnitError:AudioUnitUninitialize(caCallbackContext.remoteIOInstance)];
        caCallbackContext.remoteIOInstance = NULL;
        
        //release buffers
        if (caCallbackContext.outputScratchBuffer) {
            MN_FREE(caCallbackContext.outputScratchBuffer);
            caCallbackContext.outputScratchBuffer = NULL;
        }
        
        if (caCallbackContext.inputScratchBuffer) {
            MN_FREE(caCallbackContext.inputScratchBuffer);
            caCallbackContext.inputScratchBuffer = NULL;
        }
        
        if (caCallbackContext.inputBufferList.mBuffers[0].mData) {
            MN_FREE(caCallbackContext.inputBufferList.mBuffers[0].mData);
            memset(&caCallbackContext.inputBufferList, 0, sizeof(AudioBufferList));
            caCallbackContext.inputBufferSizeInBytes = 0;
        }
    }
}

#pragma mark Audio session activation/deactivation

-(void)activateAudioSession
{
    [self deactivateAudioSession];
    
    NSError* error = nil;
    BOOL result = NO;
    
    AVAudioSession* audioSession = [AVAudioSession sharedInstance];
    
    if (audioSession.otherAudioPlaying) {
        //TODO: handle this case?
    }
    
    //Check if audio input is available.
    //Note: Input availability may change at any time, for
    //example when connecting a headset to an iPod touch.
    BOOL inputAvailable = audioSession.inputAvailable;
    
    //pick a suitable audio session category
    NSString* sessionCategory = inputAvailable == 0 ? AVAudioSessionCategoryPlayback : AVAudioSessionCategoryPlayAndRecord;
    result = [[AVAudioSession sharedInstance] setCategory:sessionCategory error:&error];
    if (!result) {
        NSLog(@"%@", [error localizedDescription]);
        assert(false);
    }
    
    //route audio output to the speaker instead of the receiver, even though input is enabled.
    if (sessionCategory == AVAudioSessionCategoryPlayAndRecord) {
        result = [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        if (!result) {
            NSLog(@"%@", [error localizedDescription]);
            assert(false);
        }
    }
    
    //set sample rate
    result = [[AVAudioSession sharedInstance] setPreferredSampleRate:options.sampleRate error:&error];
    if (!result) {
        NSLog(@"%@", [error localizedDescription]);
        assert(false);
    }
    
    //set buffer size (i.e latency)
    Float32 preferredBufferDuration = options.bufferSizeInFrames / (float)options.sampleRate;
    result = [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferredBufferDuration error:&error];
    if (!result) {
        NSLog(@"%@", [error localizedDescription]);
        assert(false);
    }
    
    //Hook up notifications for...
    
    //interruption
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionInterruptionHandler:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    
    //route change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionRouteChangeHandler:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    
    //server died
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionServerDiedHandler:)
                                                 name:AVAudioSessionMediaServicesWereLostNotification
                                               object:nil];
    
    //server reset
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioSessionServerResetHandler:)
                                                 name:AVAudioSessionMediaServicesWereResetNotification
                                               object:nil];
    
    result = [audioSession setActive:true error:&error];
    if (!result) {
        NSLog(@"%@", [error localizedDescription]);
        assert(false);
    }

}

-(void)deactivateAudioSession
{
    //stop subscribing to audio session notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSError* error = nil;
    BOOL result = [[AVAudioSession sharedInstance] setActive:NO
                                                       error:&error];
    if (!result) {
        NSLog(@"%@", error.localizedDescription);
    }
}

#pragma mark AVAudioSessionDelegate
/* notification for input become available or unavailable */
- (void)inputIsAvailableChanged:(BOOL)isInputAvailable
{
    
}

#pragma mark Audio session notifications
-(void)audioSessionInterruptionHandler:(NSNotification*)notification
{
    NSDictionary* info = [notification userInfo];
    
    NSNumber* interruptionType = [info objectForKey:AVAudioSessionInterruptionTypeKey];
    
    switch (interruptionType.intValue) {
        case AVAudioSessionInterruptionTypeBegan:
        {
            [self suspend];
            break;
        }
        case AVAudioSessionInterruptionTypeEnded:
        {
            [self resume];
            break;
        }
        default:
            break;
    }
}

-(void)audioSessionRouteChangeHandler:(NSNotification*)notification
{
    NSDictionary* info = [notification userInfo];
    
    NSNumber* reason = [info valueForKey:AVAudioSessionRouteChangeReasonKey];
    //NSString* previousRoute = [info valueForKey:AVAudioSessionRouteChangePreviousRouteKey];
    
    switch (reason.integerValue) {
        case AVAudioSessionRouteChangeReasonUnknown:
        {
            //The reason is unknown.
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonUnknown"];
            break;
        }
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        {
            //New device became available (e.g. headphones have been plugged in).
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonNewDeviceAvailable"];
            break;
        }
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        {
            //The old device became unavailable (e.g. headphones have been unplugged).
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonOldDeviceUnavailable"];
            break;
        }
            
        case AVAudioSessionRouteChangeReasonCategoryChange:
        {
            //The audio category has changed (e.g. AVAudioSessionCategoryPlayback has been changed to AVAudioSessionCategoryPlayAndRecord).
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonCategoryChange"];
            break;
        }

        case AVAudioSessionRouteChangeReasonOverride:
        {
            //The route has been overridden (e.g. category is AVAudioSessionCategoryPlayAndRecord and the output
            //has been changed from the receiver, which is the default, to the speaker).
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonOverride"];
            break;
        }
            
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
        {
            //The device woke from sleep.
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonWakeFromSleep"];
            break;
        }
            
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
        {
            //Returned when there is no route for the current category (for instance, the category is AVAudioSessionCategoryRecord
            //but no input device is available).
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory"];
            break;
        }
            
        case AVAudioSessionRouteChangeReasonRouteConfigurationChange:
        {
            //Indicates that the set of input and/our output ports has not changed, but some aspect of their
            //configuration has changed.  For example, a port's selected data source has changed.
            [self logAudioSessionRouteChange:@"AVAudioSessionRouteChangeReasonRouteConfigurationChange"];
            break;
        }
        default:
        {
            [self logAudioSessionRouteChange:@"UNKNOWN"];
            break;
        }
    }
    
    /*
     From the Apple "Handling Audio Hardware Route Changes" docs:
     
     "One of the audio hardware route change reasons in iOS is
     kAudioSessionRouteChangeReason_CategoryChange. In other words,
     a change in audio session category is considered by the system—in
     this context—to be a route change, and will invoke a route change
     property listener callback. As a consequence, such a callback—if
     it is intended to respond only to headset plugging and unplugging—should
     explicitly ignore this type of route change."
     
     If kAudioSessionRouteChangeReason_CategoryChange is not ignored, we could get
     an infinite loop because the audio session category is set below, which will in
     turn trigger kAudioSessionRouteChangeReason_CategoryChange and so on.
     */
    //TODO: figure out exactly what resons to respond to and how
    if (reason.integerValue != AVAudioSessionRouteChangeReasonCategoryChange &&
        reason.integerValue != AVAudioSessionRouteChangeReasonOverride)
    {
        [self stop];
        [self start];
    }
}

-(void)audioSessionServerDiedHandler:(NSNotification*)notification
{
    //See Technical Q&A QA1749.
    [self stop];
}

-(void)audioSessionServerResetHandler:(NSNotification*)notification
{
    //See Technical Q&A QA1749.
    [self start];
}

@end