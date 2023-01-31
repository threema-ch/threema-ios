//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "AudioRecorder.h"
#import "AppDelegate.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

#define kMaxRecordDuration 1800.0
#define kMaxSaveWaitTimeS 10.0

#define kRecordFileName @"recordAudio"
#define kRecordTmpFileName @"interrupted"

@interface AudioRecorder ()  <AVAudioRecorderDelegate>

@property NSURL *recordAudioUrl;
@property NSURL *tmpRecorderFile;
@property NSTimeInterval tmpFileDuration;

@property dispatch_semaphore_t sema;

@property BOOL interrupted;

@end

@implementation AudioRecorder

- (void)dealloc {
    [self stop];
    [self unregisterFromNotifications];
    
    [self cleanupFiles];
    
    // make sure delegate methods are not called anymore
    _recorder.delegate = nil;
}

- (void)start {
    [self cleanupFiles];
    
    [self registerForNotifications];
    [self startRecording];
}

- (void)stop {
    [self stopRecorder];
    
    [self unregisterFromNotifications];
    [self joinWithTmpFile];
}

- (void)startRecording {
    [self setupRecorder];
    
    if ([_recorder recordForDuration:kMaxRecordDuration]) {
        DDLogInfo(@"Recording");
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    }
}

- (void)stopRecorder {
    if (_recorder.recording) {
        [_recorder stop];
    }
}

- (NSURL *)audioURL {
    return [self recorderUrl];
}

- (void)cleanupFiles {
    /* ensure audio files are deleted */
    [[NSFileManager defaultManager] removeItemAtURL:_recordAudioUrl error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:_tmpRecorderFile error:nil];
    
    _recordAudioUrl = nil;
    _tmpRecorderFile = nil;
    _tmpFileDuration = 0;
}

- (NSURL *)tmpAudioUrlWithFileNamed:(NSString *)filename {
    NSURL *tmpDirUrl = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *url = [[tmpDirUrl URLByAppendingPathComponent:filename] URLByAppendingPathExtension: MEDIA_EXTENSION_AUDIO];
    
    DDLogInfo(@"fileURL: %@", [url path]);
    
    return url;
}

- (void)setupRecorder {
    NSError *error = nil;

    [self stopRecorder];

    _recordAudioUrl = [self tmpAudioUrlWithFileNamed:kRecordFileName];
    
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] initWithCapacity:10];
    [recordSettings setObject:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSettings setObject:[NSNumber numberWithFloat:22050.0] forKey: AVSampleRateKey];
    [recordSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    [recordSettings setObject:[NSNumber numberWithInt:32000] forKey:AVEncoderBitRateKey];
    [recordSettings setObject:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [recordSettings setObject:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    
    _recorder = [[AVAudioRecorder alloc] initWithURL:_recordAudioUrl settings:recordSettings error:&error];
    if (_recorder == nil) {
        DDLogError(@"Cannot create audio recorder: %@", error);
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        return;
    }
    
    _recorder.delegate = self;
}

- (NSURL *)recorderUrl {
    return _recordAudioUrl;
}

- (BOOL)recording {
    return _recorder.recording;
}

- (NSTimeInterval)currentTime {
    return _recorder.currentTime + _tmpFileDuration;
}


#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    DDLogInfo(@"Finished recording, successfully: %d", flag);
    
    if (_interrupted) {
        _interrupted = NO;
        return;
    } else {
        [self stop];
    
        [_delegate recorderDidFinish];
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    DDLogError(@"Encode error: %@", error);
}

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(avSessionInterrupted:)
               name:AVAudioSessionInterruptionNotification object:nil];
    [nc addObserver:self selector:@selector(applicationWillEnterForeground:)
               name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)unregisterFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)avSessionInterrupted:(NSNotification *)notification {
    NSNumber *interruptionType = [notification.userInfo objectForKey:@"AVAudioSessionInterruptionTypeKey"];
    DDLogInfo(@"AVAudioSessionInterruptionNotification: %d", interruptionType.intValue);
    if (interruptionType.intValue == AVAudioSessionInterruptionTypeBegan) {
        _interrupted = YES;
        _interruptedAndNotStarted = true;
        _tmpFileDuration = self.currentTime;
        [_recorder stop];
            
        [self saveToTmpFile];
    } else {
        _interruptedAndNotStarted = false;
        [self startRecording];
        
        [_delegate recorderResumedAfterInterrupt];
    }
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    if (_interruptedAndNotStarted == true) {
        _interruptedAndNotStarted = false;
        [self startRecording];
        [_delegate recorderResumedAfterInterrupt];
    }
}

- (void)saveToTmpFile {
    // Do we already have a temporary recording? If so, join it with the current one
    if (_tmpRecorderFile) {
        AVMutableComposition *composition = [AVMutableComposition composition];
        
        AVAsset *asset = [AVURLAsset URLAssetWithURL:_tmpRecorderFile options:nil];
        CMTime timeZero = CMTimeMake(0, asset.duration.timescale);
        CMTimeRange timeRange = CMTimeRangeFromTimeToTime(timeZero, asset.duration);
        [composition insertTimeRange:timeRange ofAsset:asset atTime:timeZero error:nil];
        
        DDLogVerbose(@"join added: %f %@", CMTimeGetSeconds(asset.duration), _tmpRecorderFile);
        
        AVAsset *secondAsset = [AVURLAsset URLAssetWithURL:_recordAudioUrl options:nil];
        CMTimeRange secondTimeRange = CMTimeRangeFromTimeToTime(timeZero, secondAsset.duration);
        [composition insertTimeRange:secondTimeRange ofAsset:secondAsset atTime:asset.duration error:nil];
        
        DDLogVerbose(@"join added 2: %f %@", CMTimeGetSeconds(secondAsset.duration), _recordAudioUrl);
        
        AVComposition *immutableSnapshotComposition = [composition copy];
        
        [[NSFileManager defaultManager] removeItemAtURL:_tmpRecorderFile error:nil];
        _tmpRecorderFile = [self tmpAudioUrlWithFileNamed:kRecordTmpFileName];
        
        [self saveAudioAsset:immutableSnapshotComposition toURL:_tmpRecorderFile];
    } else {
        _tmpRecorderFile = [self tmpAudioUrlWithFileNamed:kRecordTmpFileName];
        
        AVAsset *asset = [AVURLAsset URLAssetWithURL:_recordAudioUrl options:nil];
        [self saveAudioAsset:asset toURL:_tmpRecorderFile];
    }
}

- (void)saveAudioAsset:(AVAsset *)asset toURL:(NSURL *)url {
    NSError *error;
    if ([[NSFileManager defaultManager] removeItemAtURL:url error:&error] == NO) {
        DDLogError(@"audio export could not delete file: %@ error: %@", error, url);
    };
    
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetMediumQuality];
    exportSession.outputURL = url;
    exportSession.shouldOptimizeForNetworkUse = YES;
    exportSession.outputFileType = AVFileTypeMPEG4;
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        DDLogVerbose(@"audio export completed: %ld %@", (long)exportSession.status, url);
        if (exportSession.error) {
            DDLogError(@"audio export error: %@", exportSession.error);
        }
        dispatch_semaphore_signal(_sema);
    }];
    
    _sema = dispatch_semaphore_create(0);
    dispatch_semaphore_wait(_sema, dispatch_time(DISPATCH_TIME_NOW, kMaxSaveWaitTimeS * NSEC_PER_SEC));
}

- (void)joinWithTmpFile {
    if (_tmpRecorderFile && !_interruptedAndNotStarted) {
        AVMutableComposition *composition = [AVMutableComposition composition];
        
        AVAsset *asset = [AVURLAsset URLAssetWithURL:_tmpRecorderFile options:nil];
        CMTime timeZero = CMTimeMake(0, asset.duration.timescale);
        CMTimeRange timeRange = CMTimeRangeFromTimeToTime(timeZero, asset.duration);
        [composition insertTimeRange:timeRange ofAsset:asset atTime:timeZero error:nil];
        
        DDLogVerbose(@"join added: %f %@", CMTimeGetSeconds(asset.duration), _tmpRecorderFile);
        
        AVAsset *secondAsset = [AVURLAsset URLAssetWithURL:_recordAudioUrl options:nil];
        CMTimeRange secondTimeRange = CMTimeRangeFromTimeToTime(timeZero, secondAsset.duration);
        [composition insertTimeRange:secondTimeRange ofAsset:secondAsset atTime:asset.duration error:nil];
        
        DDLogVerbose(@"join added 2: %f %@", CMTimeGetSeconds(secondAsset.duration), _recordAudioUrl);
        
        AVComposition *immutableSnapshotComposition = [composition copy];
        
        [[NSFileManager defaultManager] removeItemAtURL:_tmpRecorderFile error:nil];
        _tmpRecorderFile = nil;
        _tmpFileDuration = 0;
        
        [self saveAudioAsset:immutableSnapshotComposition toURL:_recordAudioUrl];
    }
}

@end
