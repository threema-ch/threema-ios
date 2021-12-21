//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "PlayRecordAudioViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioRecorder.h"
#import "BundleUtil.h"
#import "AppDelegate.h"
#import "UserSettings.h"
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface PlayRecordAudioViewController () <AVAudioPlayerDelegate, AudioRecorderDelegate, PlayRecordAudioViewDelegate>
@property AudioRecorder *recorder;
@property AVAudioPlayer *player;
@property UIView *coverView;
@property UIView *containerView;
@property NSString *prevAudioCategory;
@property Conversation *conversation;
@property UIViewController *parentController;

@property NSURL *audioFile;

@property BOOL cancelled;
@property BOOL hideOnFinishPlayback;

@property dispatch_semaphore_t sema;

@end

@implementation PlayRecordAudioViewController

+ (BOOL)canRecordAudio {
    return [AVAudioSession sharedInstance].inputAvailable;
}

+ (void)activateProximityMonitoring {
    if (![UserSettings sharedUserSettings].disableProximityMonitoring) {
        [[UIDevice currentDevice] setProximityMonitoringEnabled: YES];
    }
}

+ (void)deactivateProximityMonitoring {
    [[UIDevice currentDevice] setProximityMonitoringEnabled: NO];
}

+(instancetype)playRecordAudioViewControllerIn:(UIViewController *)viewController {
    PlayRecordAudioViewController *instance = [[PlayRecordAudioViewController alloc] init];
    instance.parentController = viewController;
    
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.cancelled = NO;
        self.hideOnFinishPlayback = NO;
        
        [[NSBundle mainBundle] loadNibNamed:@"PlayRecordAudioView" owner:self options:nil];
        
        [self storeCurrentAudioSession];
        
        [_audioView setup];
        _audioView.delegate = self;
        
        [_audioView setStopped];
        
        [self registerForNotifications];
        
        if (![UserSettings sharedUserSettings].disableProximityMonitoring) {
            [[UIDevice currentDevice] setProximityMonitoringEnabled: YES];
        }
    }
    
    return self;
}

- (void)dealloc {
    [self stopAll];
    [self unregisterFromNotifications];
    [[UIDevice currentDevice] setProximityMonitoringEnabled: NO];
    
    // make sure delegate methods are not called anymore
    _recorder.delegate = nil;
    _player.delegate = nil;
}

- (void)storeCurrentAudioSession {
    _prevAudioCategory = [AVAudioSession sharedInstance].category;
}

- (void)setupAudioSessionWithEarpiece:(BOOL)earpiece {
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (state == CallStateIdle) {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        if (![session setCategory:earpiece ? AVAudioSessionCategoryPlayAndRecord : AVAudioSessionCategoryPlayback mode:AVAudioSessionModeSpokenAudio options:earpiece ? AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP : 0 error:&error]) {
            DDLogError(@"Cannot set audio session category: %@", error);
            [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
            return;
        }

        if (earpiece && ![session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
            DDLogError(@"Cannot set audio session override outputaudio port: %@", error);
            [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
            return;
        }
        
        [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        
        [self printInAndOutputs];
    }
}

- (void)setupAudioSessionForRecordWithSpeaker {
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (state == CallStateIdle) {
        NSError *error = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        if (![session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeSpokenAudio options:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP error:&error]) {
            DDLogError(@"Cannot set audio session category: %@", error);
            [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
            return;
        }
        
        [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        
        [self printInAndOutputs];
    }
}

- (void)printInAndOutputs {
    AVAudioSessionRouteDescription *currentRoute = [AVAudioSession sharedInstance].currentRoute;
    NSArray *availableInputs = [AVAudioSession sharedInstance].availableInputs;
    for (AVAudioSessionPortDescription *input in availableInputs) {
        DDLogInfo(@"Play/Record audio: Available input port: %@", input.portType);
    }
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        DDLogInfo(@"Play/Record audio: Current output port: %@", output.portType);
    }
}

- (void)resetAudioSession {
    NSInteger state = [[VoIPCallStateManager shared] currentCallState];
    if (state == CallStateIdle) {
        [[AVAudioSession sharedInstance] setCategory:_prevAudioCategory error:nil];
        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        _recorder.delegate = nil;
        _player.delegate = nil;
    }
}

- (NSURL *)tmpAudioUrlWithFileNamed:(NSString *)filename {
    NSURL *tmpDirUrl = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *url = [[tmpDirUrl URLByAppendingPathComponent:filename] URLByAppendingPathExtension: MEDIA_EXTENSION_AUDIO];
    
    DDLogInfo(@"fileURL: %@", [url path]);
    
    return url;
}

+ (void)requestMicrophoneAccessOnCompletion:(void(^)(void))onCompletion {
    [self checkPermissionOnCompletion:^{
        if (onCompletion != nil) {
            onCompletion();
        }
    }];
}

- (void)blendInView {
    UIViewController *rootViewController = _parentController.view.window.rootViewController;
    CGRect parentRect = rootViewController.view.bounds;
    
    /* create container view that we can make modal for accessibility purposes */
    _containerView = [[UIView alloc] initWithFrame:parentRect];
    _containerView.accessibilityViewIsModal = YES;
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [rootViewController.view addSubview:_containerView];
    
    /* add view to cover view controller contents */
    _coverView = [[UIView alloc] initWithFrame:parentRect];
    _coverView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    _coverView.alpha = 0;
    _coverView.isAccessibilityElement = YES;
    
    _coverView.accessibilityLabel = @"";
    
    _coverView.accessibilityIdentifier = @"FinishAudio";
    _coverView.accessibilityActivationPoint = CGPointMake(0.0, 0.0);
    
    _coverView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [_containerView addSubview:_coverView];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapCover:)];
    [_coverView addGestureRecognizer: tapGesture];
    
    CGRect frame = _audioView.frame;
    
    frame.origin.x = (parentRect.size.width - frame.size.width) / 2;
    frame.origin.y = (parentRect.size.height - frame.size.height) / 2;
    
    _audioView.frame = frame;
    _audioView.alpha = 0;
    
    [_containerView addSubview:_audioView];
    
    /* fade in */
    [UIView animateWithDuration:0.3 animations:^{
        _audioView.alpha = 1.0;
        _coverView.alpha = 1.0;
    }];
    
    [AppDelegate sharedAppDelegate].magicTapHandler = self;
    
}

- (void)removeFromView {
    _coverView.userInteractionEnabled = NO;
    
    if ([AppDelegate sharedAppDelegate].magicTapHandler == (id)self)
        [AppDelegate sharedAppDelegate].magicTapHandler = nil;
    
    [self stopAll];
    [self resetAudioSession];

    [UIView animateWithDuration:0.3 animations:^{
        _coverView.alpha = 0;
        _audioView.alpha = 0;
    } completion:^(BOOL finished) {
        [_containerView removeFromSuperview];
        [self stopAll];
        [self unregisterFromNotifications];
        [[UIDevice currentDevice] setProximityMonitoringEnabled: NO];
         [_delegate audioPlayerDidHide];
        
        // make sure delegate methods are not called anymore
        _recorder.delegate = nil;
        _player.delegate = nil;
    }];
}

- (void)startRecordingForConversation:(Conversation *)conversation {
    [self blendInView];
    
    _conversation = conversation;
    _hideOnFinishPlayback = NO;
    
    _recorder = [[AudioRecorder alloc] init];
    _recorder.delegate = self;

    [self startRecording];
}

- (void)startRecording {
    [_audioView toggleButtonsForRecording: YES];

    [self setupAudioSessionForRecordWithSpeaker];
    [_recorder start];
    [_audioView setupForRecording:_recorder];
}

- (void)startPlaying:(NSURL *)audioFile {
    [_audioView toggleButtonsForRecording: NO];

    [self blendInView];

    [self setupAudioPlayer: audioFile];
    
    [self startPlaying];
}

- (void)setupAudioPlayer: (NSURL *)audioFile {
    _audioFile = audioFile;
    
    NSError *error;
    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:_audioFile error:&error];
    [_player prepareToPlay];
    if (_player == nil) {
        DDLogError(@"Cannot create audio player: %@", error);
        [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        return;
    }
    
    _player.numberOfLoops = 0;
    _player.delegate = self;
    _player.enableRate = true;
    _player.rate = [[UserSettings sharedUserSettings] threemaAudioMessagePlaySpeedCurrentValue];
    [self setSpeedTitle];
    
    [_audioView setupForPlaying: _player];
    
    _player.currentTime = 0;
    
}

- (void)startPlaying {
    [self adaptToProximityState];
    
    [_player play];
    [_audioView setPlaying];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)stopRecording {
    [_recorder stop];
    
    [self adaptToProximityState];
    
    [self stopRecordingUI];
}

- (void)stopRecordingUI {
    [_audioView setStopped];
    
    [self adaptToProximityState];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)stopAll {
    if (_player) {
        [_player stop];
    }
    
    if (_recorder) {
        [_recorder stop];
    }
}

- (void)pause {
    [_player pause];
    
    [_audioView setPaused];
    
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)cancel {
    if (_recorder != nil) {
        [UIAlertTemplate showDestructiveAlertWithOwner:self title:[BundleUtil localizedStringForKey:@"record_cancel_title"] message:[BundleUtil localizedStringForKey:@"record_cancel_message"] titleDestructive:[BundleUtil localizedStringForKey:@"record_cancel_button_discard"] actionDestructive:^(UIAlertAction * action) {
            _cancelled = YES;
            [self stopRecording];
            [self removeFromView];
        } titleCancel:[BundleUtil localizedStringForKey:@"cancel"] actionCancel:nil];
    } else {
        [self stopRecording];
        [self removeFromView];
    }
}

- (IBAction)playPauseStopButtonPressed:(id)sender {
    _hideOnFinishPlayback = NO;
    
    if (_player.playing) {
        [self pause];
    } else if (_recorder.recorder.recording) {
        [self stopRecording];
    } else {
        [self startPlaying];
    }
}

- (IBAction)recordButtonPressed:(id)sender {
    [self startRecording];
}

- (IBAction)sendButtonPressed:(id)sender {
    [self stopRecording];
    
    [self sendFile];

    [self removeFromView];
}

- (IBAction)speedButtonPressed:(id)sender {
    _player.rate = [[UserSettings sharedUserSettings] threemaAudioMessagePlaySpeedSwitchToNextValue];
    [self setSpeedTitle];
}

- (void)setSpeedTitle {
    NSString *speedText = [NSString stringWithFormat:@"%.1f×", _player.rate];
    [_audioView.speedButton setTitle:speedText forState:UIControlStateNormal];
    
    _audioView.speedButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"speed"];
    _audioView.speedButton.accessibilityValue = speedText;
}

+ (void)checkPermissionOnCompletion:(void(^)(void))onCompletion {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([session respondsToSelector:@selector(requestRecordPermission:)]) {
        [session performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) {
                    DDLogInfo(@"Microphone access granted.");
                    onCompletion();
                } else {
                    DDLogInfo(@"Microphone access not granted.");
                    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:NSLocalizedString(@"microphone_disabled_title", nil) message:NSLocalizedString(@"microphone_disabled_message", nil) actionOk:nil];
                }
            });
        }];
    } else {
        onCompletion();
    }
}

- (void)sendFile {
    DDLogVerbose(@"Sending file");    
    NSURL *url = [_recorder audioURL];
    URLSenderItem *item = [URLSenderItem itemWithUrl:url type:(NSString *)kUTTypeAudio renderType:@1 sendAsFile:true];
    FileMessageSender *sender = [[FileMessageSender alloc] init];
    [sender sendItem:item inConversation:_conversation requestId:nil];
}


#pragma mark - AudioRecorderDelegate

- (void)recorderDidFinish {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL *url = [_recorder audioURL];
        BOOL hasAudioFile = [[NSFileManager defaultManager] fileExistsAtPath:url.path];
        if (hasAudioFile && _cancelled == NO) {
            [self setupAudioPlayer: url];
            [_audioView setFinishedRecording];
        }
    });
}

- (void)setAccessibilityLabelForQuit {
    _coverView.accessibilityLabel = [BundleUtil localizedStringForKey:@"quit"];
}

- (void)recorderResumedAfterInterrupt {
    [_audioView setupForRecording:_recorder];  
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupAudioPlayer: _audioFile];
        [self pause];
        AVAudioSessionRouteDescription *currentRoute = [AVAudioSession sharedInstance].currentRoute;
        if (currentRoute.outputs.count > 0) {
            if ([currentRoute.outputs[0].portType isEqualToString:@"Speaker"]) {
                [self setupAudioSessionWithEarpiece:false];
            }
            else if ([currentRoute.outputs[0].portType isEqualToString:@"Receiver"]) {
                [self setupAudioSessionWithEarpiece:true];
            }
        }
        
        if (_hideOnFinishPlayback) {
            [self cancel];
        }
    });
}

#pragma mark - Gestures

- (void)tapCover:(UIGestureRecognizer*)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        /* guard against accidental cancellation */
        if (_recorder.recorder.recording && _recorder.recorder.currentTime > 2) {
            return;
        }
        
        [self stopAll];
        [self cancel];
    }
}

#pragma mark - Notifications

- (void)registerForNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(proximityStateChanged:) name:UIDeviceProximityStateDidChangeNotification object:nil];

}

- (void)unregisterFromNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
}

- (void)proximityStateChanged:(NSNotification *)notification {
    AVAudioSessionRouteDescription *currentRoute = [AVAudioSession sharedInstance].currentRoute;
    if (currentRoute.outputs.count > 0) {
        if (_player.isPlaying && ([currentRoute.outputs[0].portType isEqualToString:@"Speaker"] || [currentRoute.outputs[0].portType isEqualToString:@"Receiver"])) {
            [self adaptToProximityState];
        }
    }
}

- (void)adaptToProximityState {
    AVAudioSessionRouteDescription *currentRoute = [AVAudioSession sharedInstance].currentRoute;
    if (currentRoute.outputs.count > 0) {
        if ([currentRoute.outputs[0].portType isEqualToString:@"Speaker"] || [currentRoute.outputs[0].portType isEqualToString:@"Receiver"]) {
            if ([UIDevice currentDevice].proximityState) {
                // close to ear
                [self setupAudioSessionWithEarpiece:true];
            } else {
                // speaker
                [self setupAudioSessionWithEarpiece:false];
            }
        } else {
            [self setupAudioSessionWithEarpiece:false];
        }
    } else {
        [self setupAudioSessionWithEarpiece:false];
    }
}

#pragma mark - Accessibility

/* Note: this is intentionally not accessibilityPerformMagicTap, as it doesn't appear to get delivered reliably with our complicated
   view controller hierarchies. Instead, we catch it in the AppDelegate and dispatch it from there. */
- (BOOL)handleMagicTap {
    _hideOnFinishPlayback = NO;
    
    if (_player.playing) {
        [self pause];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, NSLocalizedString(@"pause", nil));
    } else if (_recorder.recorder.recording) {
        [self stopRecording];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, NSLocalizedString(@"stop", nil));
    } else {
        [self startPlaying];
    }
    
    return YES;
}

@end
