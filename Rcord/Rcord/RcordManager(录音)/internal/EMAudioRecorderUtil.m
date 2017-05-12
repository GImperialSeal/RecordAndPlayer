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

#import "EMAudioRecorderUtil.h"
#import "DemoErrorCode.h"
#import "EMVoiceConverter.h"
@import UIKit;
#define kRecordAudioFile @"myRecord.caf"

static EMAudioRecorderUtil *audioRecorderUtil = nil;

@interface EMAudioRecorderUtil () <AVAudioRecorderDelegate>

@property (nonatomic,strong) AVAudioRecorder *audioRecorder;//音频录音机

@property (nonatomic, strong) NSDictionary *recordSetting;

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, copy) recordCompletion didFinishRecordBlock;

@end

@implementation EMAudioRecorderUtil

#pragma mark - record
- (void)start{
    
    if (![self emCheckMicrophoneAvailability]) {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"" message:@"获取麦克风权限失败" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:@"", nil];
        [alert show];
        return;
    }
    
    if (![self.audioRecorder isRecording]) {
        [self setAudioSession:AVAudioSessionCategoryRecord active:YES];
        self.recorderStartDate = [NSDate date];
        [self.audioRecorder record];//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
        self.timer.fireDate=[NSDate distantPast];
    }else{
        [self cancle];
    }
}

- (void)pause{
    if ([self.audioRecorder isRecording]) {
        [self.audioRecorder pause];
        self.timer.fireDate=[NSDate distantFuture];
    }
}

- (void)resume{
    [self start];
}

- (void)stop:(recordCompletion)complete{
    self.timer.fireDate = [NSDate distantFuture];
    self.recorderEndDate = [NSDate date];
    if([_recorderEndDate timeIntervalSinceDate:_recorderStartDate] < 1.0){
        // 如果录音时间较短，延迟1秒停止录音（iOS中，如果快速开始，停止录音，UI上会出现红条,为了防止用户又迅速按下，UI上需要也加一个延迟，长度大于此处的延迟时间，不允许用户循序重新录音。PS:研究了QQ和微信，就这么玩的,聪明）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.audioRecorder stop];
            [self.audioRecorder deleteRecording];
            [self setAudioSession:AVAudioSessionCategoryAmbient active:NO];
        });
        return ;
    }else{
        [self.audioRecorder stop];
        self.didFinishRecordBlock = complete;
        [self setAudioSession:AVAudioSessionCategoryAmbient active:NO];
    }
}

- (void)cancle{
    [self.audioRecorder stop];
    [self.audioRecorder deleteRecording];
}

- (BOOL)isRecording{
    return [self.audioRecorder isRecording];
}


#pragma mark - Private
+(EMAudioRecorderUtil *)record{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audioRecorderUtil = [[self alloc] init];
    });
    return audioRecorderUtil;
}

-(instancetype)init{
    if (self = [super init]) {
        
    }
    
    return self;
}




/**
 *  设置音频会话
 */
-(void)setAudioSession:(NSString *)category active:(BOOL)active{
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    //设置为播放和录音状态，以便可以在录制完之后播放录音
    [audioSession setCategory:category error:nil];
    [audioSession setActive:YES error:nil];
}

/**
 *  取得录音文件保存路径
 *
 *  @return 录音文件路径
 */
-(NSURL *)getSavePath{
    NSString *urlStr=[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    urlStr=[urlStr stringByAppendingPathComponent:kRecordAudioFile];
    NSLog(@"file path:%@",urlStr);
    NSURL *url=[NSURL fileURLWithPath:urlStr];
    return url;
}

/**
 *  取得录音文件设置
 *
 *  @return 录音设置
 */
-(NSDictionary *)getAudioSetting{
    NSMutableDictionary *dicM=[NSMutableDictionary dictionary];
    //设置录音格式
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    //设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [dicM setObject:@(8000) forKey:AVSampleRateKey];
    //设置通道,这里采用单声道
    [dicM setObject:@(1) forKey:AVNumberOfChannelsKey];
    //每个采样点位数,分为8、16、24、32
    [dicM setObject:@(8) forKey:AVLinearPCMBitDepthKey];
    //是否使用浮点数采样
    [dicM setObject:@(YES) forKey:AVLinearPCMIsFloatKey];
    //....其他设置等
    return dicM;
}

/**
 *  获得录音机对象
 *
 *  @return 录音机对象
 */
-(AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //创建录音文件保存路径
        NSURL *url=[self getSavePath];
        //创建录音格式设置
        NSDictionary *setting=[self getAudioSetting];
        //创建录音机
        NSError *error=nil;
        _audioRecorder=[[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate=self;
        _audioRecorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}


/**
 *  录音声波监控定制器
 *
 *  @return 定时器
 */
-(NSTimer *)timer{
    if (!_timer) {
        _timer=[NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES];
    }
    return _timer;
}

/**
 *  录音声波状态设置
 */
-(void)audioPowerChange{
    [self.audioRecorder updateMeters];//更新测量值
    float power= [self.audioRecorder averagePowerForChannel:0];//取得第一个通道的音频，注意音频强度范围时-160到0
    CGFloat progress=(1.0/160.0)*(power+160.0);
    
       if (self.audioPower) {
        self.audioPower(progress);
    }
}
#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder
                           successfully:(BOOL)flag{
    if (self.didFinishRecordBlock) {
        
        NSString *path = [[recorder url] path];
        
        if (path && flag) {
            //录音格式转换，从wav转为amr
            NSString *amrFilePath = [[path stringByDeletingPathExtension]
                                     stringByAppendingPathExtension:@"amr"];
            BOOL convertResult = [self convertWAV:path toAMR:amrFilePath];
            if (convertResult) {
                // 删除录的wav
                NSFileManager *fm = [NSFileManager defaultManager];
                [fm removeItemAtPath:path error:nil];
            }
            self.didFinishRecordBlock(amrFilePath,(int)[self.recorderEndDate timeIntervalSinceDate:self.recorderStartDate]);
        }else{
            assert(flag);
        }
    }
}



- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error{
    assert(error);
    if (self.didFinishRecordBlock) {
        self.didFinishRecordBlock(nil, 0);
    }
}


#pragma mark - 判读麦克风是否可用
- (BOOL)emCheckMicrophoneAvailability{
    __block BOOL ret = NO;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([session respondsToSelector:@selector(requestRecordPermission:)]) {
        [session performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            ret = granted;
        }];
    } else {
        ret = YES;
    }
    
    return ret;
}


#pragma mark - 格式转换

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

@end
