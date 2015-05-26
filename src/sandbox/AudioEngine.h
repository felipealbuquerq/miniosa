//
//  AudioEngine.h
//  miniosa
//
//  Created by perarne on 5/26/15.
//  Copyright (c) 2015 Stuffmatic. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AudioEngine : NSObject

+(AudioEngine*)sharedInstance;

-(void)start;

-(void)stop;

-(void)suspend;

-(void)resume;

@end