/************************************************************
 *  * EaseMob CONFIDENTIAL
 * __________________
 * Copyright (C) 2013-2014 EaseMob Technologies. All rights reserved.
 *
 * NOTICE: All information contained herein is, and remains
 * the property of EaseMob Technologies.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from EaseMob Technologies.
 */

#import "EMCDDeviceManager+Media.h"
#import "EMAudioPlayerUtil.h"
#import "EMAudioRecorderUtil.h"
#import "EMVoiceConverter.h"
#import "DemoErrorCode.h"

typedef NS_ENUM(NSInteger, EMAudioSession){
    EM_DEFAULT = 0,
    EM_AUDIOPLAYER,
    EM_AUDIORECORDER
};

@implementation EMCDDeviceManager (Media)
#pragma mark - AudioPlayer
// 播放音频
- (void)asyncPlayingWithPath:(NSString *)aFilePath
                  completion:(void(^)(NSError *error))completon{
    BOOL isNeedSetActive = YES;
    // 如果正在播放音频，停止当前播放。
    if([EMAudioPlayerUtil isPlaying]){
        [EMAudioPlayerUtil stopCurrentPlaying];
        isNeedSetActive = NO;
    }
    
    if (isNeedSetActive) {
        // 设置播放时需要的category
        [self setupAudioSessionCategory:EM_AUDIOPLAYER
                               isActive:YES];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *wavFilePath = [[aFilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"wav"];
    //如果转换后的wav文件不存在, 则去转换一下
    if (![fileManager fileExistsAtPath:wavFilePath]) {
        BOOL covertRet = [self convertAMR:aFilePath toWAV:wavFilePath];
        if (!covertRet) {
            if (completon) {
                completon([NSError errorWithDomain:NSLocalizedString(@"error.initRecorderFail", @"File format conversion failed")
                                              code:EMErrorFileTypeConvertionFailure
                                          userInfo:nil]);
            }
            return ;
        }
    }
    [EMAudioPlayerUtil asyncPlayingWithPath:wavFilePath
                                 completion:^(NSError *error)
     {
         [self setupAudioSessionCategory:EM_DEFAULT
                                isActive:NO];
         if (completon) {
             completon(error);
         }
     }];
}

// 停止播放
- (void)stopPlaying{
    [EMAudioPlayerUtil stopCurrentPlaying];
    [self setupAudioSessionCategory:EM_DEFAULT
                           isActive:NO];
}

- (void)stopPlayingWithChangeCategory:(BOOL)isChange{
    [EMAudioPlayerUtil stopCurrentPlaying];
    if (isChange) {
        [self setupAudioSessionCategory:EM_DEFAULT
                               isActive:NO];
    }
}

// 获取播放状态
- (BOOL)isPlaying{
    return [EMAudioPlayerUtil isPlaying];
}

#pragma mark - Private
-(NSError *)setupAudioSessionCategory:(EMAudioSession)session
                             isActive:(BOOL)isActive{
    BOOL isNeedActive = NO;
    if (isActive != _currActive) {
        isNeedActive = YES;
        _currActive = isActive;
    }
    NSError *error = nil;
    NSString *audioSessionCategory = nil;
    switch (session) {
        case EM_AUDIOPLAYER:
            // 设置播放category
            audioSessionCategory = AVAudioSessionCategoryPlayback;
            break;
        case EM_AUDIORECORDER:
            // 设置录音category
            audioSessionCategory = AVAudioSessionCategoryRecord;
            break;
        default:
            // 还原category
            audioSessionCategory = AVAudioSessionCategoryAmbient;
            break;
    }
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    // 如果当前category等于要设置的，不需要再设置
    if (![_currCategory isEqualToString:audioSessionCategory]) {
        [audioSession setCategory:audioSessionCategory error:nil];
    }
    if (isNeedActive) {
        BOOL success = [audioSession setActive:isActive
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:&error];
        if(!success || error){
            error = [NSError errorWithDomain:NSLocalizedString(@"error.initPlayerFail", @"Failed to initialize AVAudioPlayer")
                                        code:EMErrorInitFailure
                                    userInfo:nil];
            return error;
        }
    }
    _currCategory = audioSessionCategory;
    
    return error;
}

#pragma mark - Convert

- (BOOL)convertAMR:(NSString *)amrFilePath
             toWAV:(NSString *)wavFilePath
{
    BOOL ret = NO;
    BOOL isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:amrFilePath];
    if (isFileExists) {
        [EMVoiceConverter amrToWav:amrFilePath wavSavePath:wavFilePath];
        isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:wavFilePath];
        if (isFileExists) {
            ret = YES;
        }
    }
    
    return ret;
}

- (BOOL)convertWAV:(NSString *)wavFilePath
             toAMR:(NSString *)amrFilePath {
    BOOL ret = NO;
    BOOL isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:wavFilePath];
    if (isFileExists) {
        [EMVoiceConverter wavToAmr:wavFilePath amrSavePath:amrFilePath];
        isFileExists = [[NSFileManager defaultManager] fileExistsAtPath:amrFilePath];
        if (!isFileExists) {
            
        } else {
            ret = YES;
        }
    }
    
    return ret;
}

@end
