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

#import <Foundation/Foundation.h>
@import AVFoundation;


/**
 录音完成的回调
 @param path 录音路径
 @param duration 录音时长
 */
typedef void (^recordCompletion)(NSString *path,NSInteger duration);

/**
 录音 音量
 @param progress 音量
 */
typedef void (^audioPowerChange)(CGFloat progress);

@interface EMAudioRecorderUtil : NSObject

// 音量值变化
@property (nonatomic, copy) audioPowerChange audioPower;
// 录音开始时间
@property (nonatomic, strong) NSDate *recorderStartDate;
// 录音结束时间
@property (nonatomic, strong) NSDate *recorderEndDate;

// 单利
+ (instancetype)record;

// 当前是否正在录音
- (BOOL)isRecording;

// 开始录音
- (void)start;

// 停止录音
- (void)stop:(recordCompletion)complete;

// 暂停
- (void)pause;

// 继续
-(void)resume;

// 取消录音
- (void)cancle;

@end
