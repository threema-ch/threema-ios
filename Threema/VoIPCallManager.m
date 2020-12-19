//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2020 Threema GmbH
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

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>
#import <WebRTC/WebRTC.h>
#import <WebRTC/RTCIceServer.h>
#import "VoIPCallManager.h"
#import "VoIPSender.h"
#include <arpa/inet.h>
#import "VoIPCallIceCandidatesMessage.h"
#import "BundleUtil.h"
#import "CallViewController.h"
#import "CallManager.h"
#import "MainTabBarController.h"
#import "AppDelegate.h"
#import "UserSettings.h"
#import "EntityManager.h"
#import "DateFormatter.h"
#import "NSString+Hex.h"
#import "AppGroup.h"
#import "ServerConnector.h"
#import "DateFormatter.h"
#import "VoIPHelper.h"
#import "NotificationManager.h"
#import "PushSetting.h"
#import "ValidationLogger.h"
#import "Threema-Swift.h"

#define kIncomingCallTimeout 60.0
#define kLogStatsIntervalConnecting 2.0
#define kLogStatsIntervalConnected 30.0

@interface VoIPCallManager () <RTCPeerConnectionDelegate, AVAudioPlayerDelegate, RTCAudioSessionDelegate>

@property (nonatomic, strong) RTCPeerConnectionFactory *factory;
@property (nonatomic, strong) RTCPeerConnection *connection;

@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) EntityManager *entityManager;

@property (nonatomic, strong) NSMutableDictionary *bufferReceivedAddIceCandidates;
@property (nonatomic, strong) NSMutableDictionary *bufferReceivedRemoveIceCandidates;

@property (nonatomic, assign) BOOL isMuteEnabled;
@property (nonatomic, strong) RTCAudioTrack *defaultAudioTrack;
@property (nonatomic, strong) NSMutableArray *iceCandidates;
@property (nonatomic, strong) NSMutableArray *tmpIceCandidates;
@property (nonatomic) BOOL isCopyIceCandidates;
@property (nonatomic, strong) NSTimer *incomingCallTimer;
@property (nonatomic, strong) NSTimer *iceCandidatesTimer;

@property (strong, nonatomic) AVAudioPlayer *callPlayer;
@property (strong, nonatomic) AVAudioPlayer *hangupPlayer;
@property (strong, nonatomic) AVAudioPlayer *pickupPlayer;
@property (strong, nonatomic) AVAudioPlayer *ringTonePlayer;
@property (strong, nonatomic) AVAudioPlayer *problemPlayer;
@property (strong, nonatomic) AVAudioPlayer *rejectedPlayer;

@property (strong, nonatomic) NSTimer *durationTimer;
@property (strong, nonatomic) NSTimer *reconnectTimer;
@property (strong, nonatomic) NSTimer *statsTimer;

@property (nonatomic) BOOL isSpeakerActive;
@property (nonatomic) BOOL changedToWebRTCAudio;

@end

@implementation VoIPCallManager

+ (VoIPCallManager*)sharedVoIPCallManager {
    static VoIPCallManager *instance;
    
    @synchronized (self) {
        if (!instance)
            instance = [[VoIPCallManager alloc] init];
    }
    
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        _factory = [RTCPeerConnectionFactory new];
        _bufferReceivedAddIceCandidates = [NSMutableDictionary new];
        _bufferReceivedRemoveIceCandidates = [NSMutableDictionary new];
        _isMuteEnabled = NO;
        _state = VoIPCallManagerStateIdle;
        _iceCandidates = [NSMutableArray new];
        _tmpIceCandidates = [NSMutableArray new];
        _isCopyIceCandidates = NO;
        _entityManager = [[EntityManager alloc] init];
        _isSpeakerActive = NO;
        _changedToWebRTCAudio = NO;
        _callAlreadyEnded = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
        [[RTCAudioSession sharedInstance] addDelegate:self];
    }
    return self;
}

#pragma mark - private functions

- (RTCConfiguration *)defaultRTCConfiguration {
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    RTCIceServer *servers = [[RTCIceServer alloc] initWithURLStrings:@[@"turn:stun-voip.threema.ch:3478", @"turn:stun-voip.threema.ch:443", @"turn:stun-voip.threema.ch:53", @"turn:turn-voip.threema.ch:3478", @"turn:turn-voip.threema.ch:443", @"turn:turn-voip.threema.ch:53"] username:@"threema-voip-ios" credential:@"ZdDbP1PF1vpAnqWgHXNSag" tlsCertPolicy:RTCTlsCertPolicySecure];
    configuration.iceServers = @[servers];
    
    if (_contact.verificationLevel == kVerificationLevelUnverified || [UserSettings sharedUserSettings].alwaysRelayCalls) {
        configuration.iceTransportPolicy = RTCIceTransportPolicyRelay;
    }
    
    configuration.bundlePolicy = RTCBundlePolicyMaxBundle;
    configuration.rtcpMuxPolicy = RTCRtcpMuxPolicyRequire;
    configuration.tcpCandidatePolicy = RTCTcpCandidatePolicyDisabled;
    configuration.continualGatheringPolicy = RTCContinualGatheringPolicyGatherContinually;
    
    return configuration;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSDictionary *optionalConstraints = @{@"DtlsSrtpKeyAgreement": @"true"};
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true", @"OfferToReceiveVideo": @"false"};
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true", @"OfferToReceiveVideo": @"false"};
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAudioConstraints {
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
    return constraints;
}

- (RTCMediaStream *)createLocalMediaStreamWithFactory:(RTCPeerConnectionFactory *)factory {
    RTCAudioSource *source = [factory audioSourceWithConstraints:[self defaultAudioConstraints]];
    RTCMediaStream *localStream = [factory mediaStreamWithStreamId:@"AMACALL"];
    [localStream addAudioTrack:[factory audioTrackWithSource:source trackId:@"AMACALLa0"]];
    return localStream;
}

+ (BOOL)isIPv6Address:(NSString *)ip {
    const char *utf8 = [ip UTF8String];
    
    // Check valid IPv4.
    struct in_addr dst;
    int success = inet_pton(AF_INET, utf8, &(dst.s_addr));
    if (success != 1) {
        // Check valid IPv6.
        struct in6_addr dst6;
        return inet_pton(AF_INET6, utf8, &dst6);
    }
    return NO;
}

- (BOOL)shouldAddCandidate:(RTCIceCandidate *)candidate {
    BOOL addCandidate = NO;
    if (![UserSettings sharedUserSettings].enableIPv6) {
        NSArray *sdpSplit = [candidate.sdp componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
        
        if (sdpSplit.count >= 5) {
            if ([sdpSplit[4] rangeOfString:@"."].location == NSNotFound && [sdpSplit[4] rangeOfString:@":"].location == NSNotFound) {
                addCandidate = YES;
            } else {
                if (![VoIPCallManager isIPv6Address:sdpSplit[4]]) {
                    addCandidate = YES;
                }
            }
        } else {
            addCandidate = YES;
        }
    } else {
        addCandidate = YES;
    }
     
    return addCandidate;
}

- (void)updateCallDurationTime {
    _callDurationTime = _callDurationTime + 1;
    if (_state != VoIPCallManagerStateReconnecting) {
        _callTimeString = [DateFormatter timeFormatted:_callDurationTime];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCallInBackgroundTimeChanged object:[NSNumber numberWithInt:_callDurationTime]];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCallInBackgroundTimeChanged object:nil];
    }
}

- (void)setupCallTone {
    NSString *soundFilePath = [BundleUtil pathForResource:@"ringing-tone-ch-fade" ofType:@"mp3"];
    NSURL *filePath = [NSURL fileURLWithPath:soundFilePath];
    _callPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:nil];
    _callPlayer.numberOfLoops = -1;
    [_callPlayer prepareToPlay];
}

- (void)setupHangupTone {
    NSString *soundFilePath = [BundleUtil pathForResource:@"threema_hangup" ofType:@"mp3"];
    NSURL *filePath = [NSURL fileURLWithPath:soundFilePath];
    _hangupPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:nil];
    _hangupPlayer.numberOfLoops = 1;
    _hangupPlayer.delegate = self;
    [_hangupPlayer prepareToPlay];
}

- (void)setupPickupTone {
    NSString *soundFilePath = [BundleUtil pathForResource:@"threema_pickup" ofType:@"mp3"];
    NSURL *filePath = [NSURL fileURLWithPath:soundFilePath];
    _pickupPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:nil];
    _pickupPlayer.numberOfLoops = 1;
    [_pickupPlayer prepareToPlay];
}

- (void)setupRingTone {
    NSString *voIPSound = [UserSettings sharedUserSettings].voIPSound;
    NSString *soundFilePath;
    if (![voIPSound isEqualToString:@"default"]) {
        soundFilePath = [BundleUtil pathForResource:[UserSettings sharedUserSettings].voIPSound ofType:@"mp3"];
    } else {
        soundFilePath = [BundleUtil pathForResource:@"threema_best" ofType:@"mp3"];
    }
    NSURL *filePath = [NSURL fileURLWithPath:soundFilePath];
    _ringTonePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:nil];
    _ringTonePlayer.numberOfLoops = -1;
    [_ringTonePlayer prepareToPlay];
}

- (void)setupProblemTone {
    NSString *soundFilePath = [BundleUtil pathForResource:@"threema_problem" ofType:@"mp3"];
    NSURL *filePath = [NSURL fileURLWithPath:soundFilePath];
    _problemPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:nil];
    _problemPlayer.numberOfLoops = -1;
    [_problemPlayer prepareToPlay];
}

- (void)setupRejectedTone {
    NSString *soundFilePath = [BundleUtil pathForResource:@"busy-4x" ofType:@"mp3"];
    NSURL *filePath = [NSURL fileURLWithPath:soundFilePath];
    _rejectedPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:filePath error:nil];
    _rejectedPlayer.numberOfLoops = -1;
    [_rejectedPlayer prepareToPlay];
}

- (void)playReconnecting:(NSTimer *)timer {
    if (_state == VoIPCallManagerStateReconnecting) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:_state]];
        [self playTone:VoIPCallManagerToneProblem];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSArray *outputs = [[session currentRoute] outputs];
        BOOL isSpeaker = NO;
        for (AVAudioSessionPortDescription *desc in outputs) {
            if ([desc.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
                isSpeaker = YES;
            }
        }
        [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP error:nil];
        isSpeaker ? [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil] : [session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    }
}

- (void)schedulePeriodStatsWithOptions:(VoIPStatsOptions *)options period:(NSTimeInterval)period {
    // Reset timer
    if (self.statsTimer && [self.statsTimer isValid]) {
        [self.statsTimer invalidate];
        self.statsTimer = nil;
    }
    
    // Create new timer with <period> (but immediately log once)
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    [dict setObject:self.connection forKey:@"connection"];
    [dict setObject:options forKey:@"options"];
    self.statsTimer = [NSTimer scheduledTimerWithTimeInterval:period target:self selector:@selector(logDebugStatsFromTimer:) userInfo:dict repeats:YES];
    [self logDebugStats:dict];
    [[NSRunLoop mainRunLoop] addTimer:self.statsTimer forMode:NSRunLoopCommonModes];
}

- (void)logDebugStatsFromTimer:(NSTimer *)timer {
    NSDictionary *dict = [timer userInfo];
    [self logDebugStats:dict];
}

- (void)logDebugStats:(NSDictionary *)dict {
    RTCPeerConnection *connection = [dict objectForKey:@"connection"];
    VoIPStatsOptions *options = [dict objectForKey:@"options"];
    [connection statsForTrack:nil statsOutputLevel:RTCStatsOutputLevelDebug completionHandler:^(NSArray<RTCLegacyStatsReport *> * _Nonnull report) {
        VoIPStats *stats = [[VoIPStats alloc] initWithReport:report options:options];
        NSString *statsStr = [stats getRepresentation];
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Call: Stats\n%@", statsStr]];
        
        // Execute callback (if any)
        void(^callback)(void) = [dict objectForKey:@"callback"];
        if (callback) {
            callback();
        }
    }];
}

- (NSString *)stringForIceConnectionState:(RTCIceConnectionState)state {
    switch (state) {
        case RTCIceConnectionStateNew:
            return @"new";
        case RTCIceConnectionStateChecking:
            return @"checking";
        case RTCIceConnectionStateConnected:
            return @"connected";
        case RTCIceConnectionStateCompleted:
            return @"completed";
        case RTCIceConnectionStateFailed:
            return @"failed";
        case RTCIceConnectionStateDisconnected:
            return @"disconnected";
        case RTCIceConnectionStateClosed:
            return @"closed";
        case RTCIceConnectionStateCount:
            return @"count";
    }
}

#pragma mark - public functions

- (Contact *)getCallContact {
    return _contact;
}

- (void)startVoIPCallWithContact:(Contact *)contact {
    _state = VoIPCallManagerStateWaitForRinging;
    _changedToWebRTCAudio = NO;
    [self setupTones];
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:_state]];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP error:nil];
        [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    });
    
    _contact = contact;
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *configuration = [self defaultRTCConfiguration];
    _connection = [_factory peerConnectionWithConfiguration:configuration constraints:constraints delegate:self];
    RTCMediaStream *localStream = [self createLocalMediaStreamWithFactory:_factory];
    [_connection addStream:localStream];
    [_connection offerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        [_connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
            if (!error) {
                _isCallInitiator = YES;
                [VoIPSender startVoIPCallWithContact:contact sessionDescription:sdp];
            }
        }];
    }];
}

- (void)startRinging {
    _state = VoIPCallManagerStateRinging;
    [[VoIPCallManager sharedVoIPCallManager] playTone:VoIPCallManagerToneCall];
    [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:_state]];
}

- (void)startVoIPCallAnswerWithContact:(Contact *)contact {
    _state = VoIPCallManagerStateInitializing;
    _changedToWebRTCAudio = NO;
    [self setupTones];
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:_state]];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP error:nil];
        [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    });
    
    __weak VoIPCallManager *weakSelf = self;
    
    [[CallManager sharedInstance] callPickedUpFromReceiver];
    
    if (!contact) {
        contact = _contact;
    }
    
    RTCMediaConstraints *answerConstraints = [self defaultAnswerConstraints];
    [_connection answerForConstraints:answerConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (!error) {
            [_connection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                if (!error) {
                    _isCallInitiator = NO;
                    VoIPCallAnswerMessage *message = [VoIPCallAnswerMessage new];
                    message.answer = sdp;
                    message.action = VoIPCallAnswerMessageActionCall;
                    message.rejectReason = VoIPCallAnswerMessageRejectReasonUnknown;
                    
                    [VoIPSender startVoIPCallAnswerWithContact:contact message:message];
                    
                    if (weakSelf.incomingCallTimer && [weakSelf.incomingCallTimer isValid]){
                        [weakSelf.incomingCallTimer invalidate];
                        weakSelf.incomingCallTimer = nil;
                    }
                }
            }];
        }
    }];
}

- (void)setOffer:(RTCSessionDescription *)sdp fromContact:(Contact *)contact {
    __weak VoIPCallManager *weakSelf = self;
    _state = VoIPCallManagerStateWaitForRinging;
    dispatch_async(dispatch_get_main_queue(),^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:_state]];
    });
    _contact = contact;
    RTCMediaConstraints *offerConstraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *configuration = [self defaultRTCConfiguration];
    _connection = [_factory peerConnectionWithConfiguration:configuration constraints:offerConstraints delegate:self];
    RTCMediaStream *localStream = [self createLocalMediaStreamWithFactory:_factory];
    [_connection addStream:localStream];
    
    @synchronized (_bufferReceivedAddIceCandidates) {
        [_bufferReceivedAddIceCandidates removeAllObjects];
    }
    @synchronized (_bufferReceivedRemoveIceCandidates) {
        [_bufferReceivedRemoveIceCandidates removeAllObjects];
    }
    
    [_connection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
        if (!error) {
            NSUUID *uuid = [NSUUID new];
            _state = VoIPCallManagerStateRinging;
            
            // add already received candidates
            @synchronized (weakSelf.bufferReceivedAddIceCandidates) {
                NSMutableArray *addCandidates = [weakSelf.bufferReceivedAddIceCandidates valueForKey:contact.identity];
                [addCandidates enumerateObjectsUsingBlock:^(RTCIceCandidate *candidate, NSUInteger idx, BOOL * _Nonnull stop) {
                    [weakSelf.connection addIceCandidate:candidate];
                }];
                [weakSelf.bufferReceivedAddIceCandidates removeAllObjects];
            }
            
            @synchronized (weakSelf.bufferReceivedRemoveIceCandidates) {
                NSMutableArray *removeCandidates = [weakSelf.bufferReceivedRemoveIceCandidates valueForKey:contact.identity];
                if (removeCandidates) {
                    [weakSelf.connection removeIceCandidates:removeCandidates];
                }
                [weakSelf.bufferReceivedRemoveIceCandidates removeAllObjects];
            }
            
            dispatch_async(dispatch_get_main_queue(),^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:weakSelf.state]];
                
                _incomingCallTimer = [NSTimer scheduledTimerWithTimeInterval:kIncomingCallTimeout target:self selector:@selector(timeoutCall) userInfo:nil repeats:NO];
            });
           _isCallInitiator = NO;
            if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0") && [UserSettings sharedUserSettings].enableCallKit && ![[[NSLocale currentLocale] objectForKey: NSLocaleCountryCode] isEqualToString:@"CN"]) {
                [[CallManager sharedInstance] reportIncomingCallForUUID:uuid contact:contact];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
                    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"CallStoryboard" bundle:nil];
                    CallViewController *callViewController = (CallViewController *)[storyboard instantiateInitialViewController];
                    callViewController.contact = [weakSelf contact];
                    callViewController.alreadyAccepted = NO;
                    callViewController.isCallInitiator = NO;
                    callViewController.modalPresentationStyle = UIModalPresentationOverFullScreen;
                    [vc presentViewController:callViewController animated:NO completion:nil];
                });
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
                        /* We're in the background and have received a message. There will be no push, so we need to generate a local notification */
                        NSString *cmd;
                        UNMutableNotificationContent *notification = [[UNMutableNotificationContent alloc] init];
                        notification.categoryIdentifier = @"INCOMCALL";
                        cmd = @"newcall";
                        
                        NSString *voIPSound = [UserSettings sharedUserSettings].voIPSound;
                        if (![voIPSound isEqualToString:@"default"]) {
                            notification.sound = [UNNotificationSound soundNamed:[NSString stringWithFormat:@"%@.mp3", [UserSettings sharedUserSettings].voIPSound]];
                        } else {
                            notification.sound = [UNNotificationSound soundNamed:[NSString stringWithFormat:@"threema_best.mp3"]];
                        }
                        
                        notification.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys: cmd, @"cmd", contact.displayName, @"from", nil], @"threema", nil];
                        notification.title = contact.displayName;
                        notification.body = NSLocalizedString(@"call_incoming_ended", @"");
                        
                        NSString *notificationIdentifier = contact.identity;
                        UNNotificationRequest *notificationRequest = [UNNotificationRequest requestWithIdentifier:notificationIdentifier content:notification trigger:nil];
                        
                        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                        [center addNotificationRequest:notificationRequest withCompletionHandler:^(NSError * _Nullable error) {
                        }];
                    }
                });
            }
            
            [VoIPSender sendVoIPCallRingingMessageToContact:weakSelf.contact];
        }
    }];
}

- (void)setAnswer:(RTCSessionDescription *)sdp {
    __weak VoIPCallManager *weakSelf = self;
    [_connection setRemoteDescription:sdp completionHandler:^(NSError * _Nullable error) {
        if (error) {
            [weakSelf callRejected];
        }
    }];
}

- (void)removeIceCandidates:(NSArray *)candidates fromIdentity:(NSString *)identity {
    if (_connection) {
        if ([_contact.identity isEqualToString:identity]) {
            [_connection removeIceCandidates:candidates];
        }
    } else {
        @synchronized (_bufferReceivedRemoveIceCandidates) {
            NSMutableArray *candidatesArray = [_bufferReceivedRemoveIceCandidates valueForKey:identity];
            if (!candidatesArray) {
                candidatesArray = [NSMutableArray new];
            }
            [candidates enumerateObjectsUsingBlock:^(RTCIceCandidate *candidate, NSUInteger idx, BOOL * _Nonnull stop) {
                [candidatesArray addObject:candidate];
            }];
            [_bufferReceivedRemoveIceCandidates setObject:candidatesArray forKey:identity];
        }
    }
}

- (void)addIceCandidates:(NSArray *)candidates fromIdentity:(NSString *)identity{
    if (_connection) {
        if ([_contact.identity isEqualToString:identity]) {
            [candidates enumerateObjectsUsingBlock:^(RTCIceCandidate *candidate, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([self shouldAddCandidate:candidate]) {
                    [_connection addIceCandidate:candidate];
                }
            }];
        }
    } else {
        @synchronized (_bufferReceivedAddIceCandidates) {
            NSMutableArray *candidatesArray = [_bufferReceivedAddIceCandidates valueForKey:identity];
            
            if (!candidatesArray) {
                candidatesArray = [NSMutableArray new];
            }
            [candidates enumerateObjectsUsingBlock:^(RTCIceCandidate *candidate, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([self shouldAddCandidate:candidate]) {
                    [candidatesArray addObject:candidate];
                }
            }];
            
            [_bufferReceivedAddIceCandidates setObject:candidatesArray forKey:identity];
        }
    }
}

- (void)hangup {
    if (!_callAlreadyEnded) {
        _callAlreadyEnded = YES;
        [VoIPSender sendVoIPCallHangupToContact:_contact];
        if (_state == VoIPCallManagerStateWaitForRinging || _state == VoIPCallManagerStateRinging || _state == VoIPCallManagerStateInitializing || _state == VoIPCallManagerStateCalling || _state == VoIPCallManagerStateReconnecting || _state == VoIPCallManagerStateSystemRejected) {
            Conversation *conversation = [_entityManager conversationForContact:_contact createIfNotExisting:YES];
            [_entityManager performSyncBlockAndSafe:^{
                SystemMessage *systemMessage = [_entityManager.entityCreator systemMessageForConversation:conversation];
                systemMessage.type = [NSNumber numberWithInteger:kSystemMessageCallEnded];
                if (!_callTimeString)
                    _callTimeString = @"";
                NSDictionary *argDict = @{@"DateString": [DateFormatter shortStyleTimeNoDate:[NSDate date]], @"CallTime": _callTimeString, @"CallInitiator": [NSNumber numberWithBool:_isCallInitiator]};
                NSError *error;
                NSData *data = [NSJSONSerialization dataWithJSONObject:argDict options:NSJSONWritingPrettyPrinted error:&error];
                systemMessage.arg = data;
                systemMessage.isOwn = [NSNumber numberWithBool:_isCallInitiator];
                systemMessage.conversation = conversation;
                conversation.lastMessage = systemMessage;
                _callTimeString = @"";
            }];
        }
        if (_incomingCallTimer && [_incomingCallTimer isValid]){
            [_incomingCallTimer invalidate];
            _incomingCallTimer = nil;
        }
        [self disconnect: true];
        [[CallManager sharedInstance] endCall];
    }
}

- (void)hangupOnCompletion:(void(^)(void))onCompletion {
    [VoIPSender sendVoIPCallHangupAndWaitToContact:_contact];
    if (_state == VoIPCallManagerStateWaitForRinging || _state == VoIPCallManagerStateRinging || _state == VoIPCallManagerStateInitializing || _state == VoIPCallManagerStateCalling || _state == VoIPCallManagerStateReconnecting || _state == VoIPCallManagerStateSystemRejected) {
        if (![[VoIPCallManager sharedVoIPCallManager] callAlreadyEnded]) {
            [[VoIPCallManager sharedVoIPCallManager] setCallAlreadyEnded:YES];
            Conversation *conversation = [_entityManager conversationForContact:_contact createIfNotExisting:YES];
            [_entityManager performSyncBlockAndSafe:^{
                SystemMessage *systemMessage = [_entityManager.entityCreator systemMessageForConversation:conversation];
                systemMessage.type = [NSNumber numberWithInteger:kSystemMessageCallEnded];
                if (!_callTimeString)
                    _callTimeString = @"";
                NSDictionary *argDict = @{@"DateString": [DateFormatter shortStyleTimeNoDate:[NSDate date]], @"CallTime": _callTimeString, @"CallInitiator": [NSNumber numberWithBool:_isCallInitiator]};
                NSError *error;
                NSData *data = [NSJSONSerialization dataWithJSONObject:argDict options:NSJSONWritingPrettyPrinted error:&error];
                systemMessage.arg = data;
                systemMessage.isOwn = [NSNumber numberWithBool:_isCallInitiator];
                systemMessage.conversation = conversation;
                conversation.lastMessage = systemMessage;
                _callTimeString = @"";
            }];
        }
    }
    if (_incomingCallTimer && [_incomingCallTimer isValid]){
        [_incomingCallTimer invalidate];
        _incomingCallTimer = nil;
    }
    [self disconnect: true];
    [[CallManager sharedInstance] endCall];
    onCompletion();
}

- (void)callHangedup {
    [self disconnect: true];
    [[CallManager sharedInstance] endCall];
}

- (void)callRejected {
    [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:VoIPCallManagerStateSystemRejected]];
    [_reconnectTimer invalidate];
    [self setCallTimeString:@""];
    
    [self disconnect: false];
    [[CallManager sharedInstance] endCall];
}

- (void)timeoutCall {
    __weak VoIPCallManager *weakSelf = self;
    RTCMediaConstraints *answerConstraints = [self defaultAnswerConstraints];
    [_connection answerForConstraints:answerConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (!error) {
            VoIPCallAnswerMessage *message = [VoIPCallAnswerMessage new];
            message.answer = sdp;
            message.action = VoIPCallAnswerMessageActionReject;
            message.rejectReason = VoIPCallAnswerMessageRejectReasonTimeout;
            [VoIPSender startVoIPCallAnswerRejectWithContact:_contact message:message];
        }
        __block NSString *messageId;
        Conversation *conversation = [_entityManager.entityFetcher conversationForIdentity:_contact.identity];
        [_entityManager performSyncBlockAndSafe:^{
            /* Insert system message to document the missed call */
            NSDictionary *argDict;
            SystemMessage *systemMessage = [_entityManager.entityCreator systemMessageForConversation:conversation];
            systemMessage.type = [NSNumber numberWithInteger:kSystemMessageCallMissed];
            systemMessage.isOwn = [NSNumber numberWithBool:NO];
            conversation.unreadMessageCount = [NSNumber numberWithInt:[[conversation unreadMessageCount] intValue] + 1];
            argDict = @{@"DateString": [DateFormatter shortStyleTimeNoDate:[NSDate date]], @"CallInitiator": [NSNumber numberWithBool:[[VoIPCallManager sharedVoIPCallManager] isCallInitiator]]};
            NSError *error;
            NSData *data = [NSJSONSerialization dataWithJSONObject:argDict options:NSJSONWritingPrettyPrinted error:&error];
            systemMessage.arg = data;
            systemMessage.isOwn = [NSNumber numberWithBool:[[VoIPCallManager sharedVoIPCallManager] isCallInitiator]];
            systemMessage.conversation = conversation;
            conversation.lastMessage = systemMessage;
            messageId = [NSString stringWithHexData:systemMessage.id];
        }];
        dispatch_async(dispatch_get_main_queue(),^{
            [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
        });
        
        __block UIApplicationState state;
        dispatch_async(dispatch_get_main_queue(),^{
            state = [UIApplication sharedApplication].applicationState;
        });
        PushSetting *pushSetting = [PushSetting findPushSettingForConversation:conversation];
        BOOL canSendPush = YES;
        if (pushSetting != nil) {
            canSendPush = [pushSetting canSendPush];
        }
        if (state == UIApplicationStateBackground && canSendPush) {
            UNMutableNotificationContent *notification = [[UNMutableNotificationContent alloc] init];
            
            NSString *cmd;
            if ([UserSettings sharedUserSettings].pushDecrypt) {
                notification.title = _contact.displayName;
                notification.body = NSLocalizedString(@"call_missed", nil);
                notification.categoryIdentifier = @"CALL";
            } else {
                notification.body = [NSString stringWithFormat:NSLocalizedString(@"new_message_from_x", nil), _contact.displayName];
                notification.categoryIdentifier = @"";
            }
            
            cmd = @"newmsg";
            
            if (![[UserSettings sharedUserSettings].pushSound isEqualToString:@"none"]) {
                if (pushSetting != nil) {
                    if (!pushSetting.silent) {
                        notification.sound = [UNNotificationSound soundNamed:[NSString stringWithFormat:@"%@.caf", [UserSettings sharedUserSettings].pushSound]];
                    }
                } else {
                    notification.sound = [UNNotificationSound soundNamed:[NSString stringWithFormat:@"%@.caf", [UserSettings sharedUserSettings].pushSound]];
                }
            }
            
            notification.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys: cmd, @"cmd", _contact.displayName, @"from", messageId, @"messageId", nil], @"threema", nil];
            NSString *notificationIdentifier = _contact.identity;
            UNNotificationRequest *notificationRequest = [UNNotificationRequest requestWithIdentifier:notificationIdentifier content:notification trigger:nil];
            
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center addNotificationRequest:notificationRequest withCompletionHandler:^(NSError * _Nullable error) {
            }];
        }
        
        if (weakSelf.incomingCallTimer && [weakSelf.incomingCallTimer isValid]){
            [weakSelf.incomingCallTimer invalidate];
            weakSelf.incomingCallTimer = nil;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:VoIPCallManagerStateIdle]];
        
        [_reconnectTimer invalidate];
        [self setCallTimeString:@""];
        
        [[RTCAudioSession sharedInstance] lockForConfiguration];
        NSError *rtcError = nil;
        if (![[RTCAudioSession sharedInstance] setActive:NO error:&rtcError]) {
            NSLog(@"resume music player failed, error=%@", rtcError);
        }
        [[RTCAudioSession sharedInstance] unlockForConfiguration];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if (![audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&rtcError]) {
            NSLog(@"resume music player failed, error=%@", rtcError);
        }
        
        [self disconnect: true];
        [[CallManager sharedInstance] endCall];        
    }];
}

- (void)rejectCallOnCompletion:(void(^)(void))onCompletion {
    __weak VoIPCallManager *weakSelf = self;
    RTCMediaConstraints *answerConstraints = [self defaultAnswerConstraints];
    [_connection answerForConstraints:answerConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (!error) {
            _isCallInitiator = NO;
            VoIPCallAnswerMessage *message = [VoIPCallAnswerMessage new];
            message.answer = sdp;
            message.action = VoIPCallAnswerMessageActionReject;
            message.rejectReason = VoIPCallAnswerMessageRejectReasonReject;
            [VoIPSender startVoIPCallAnswerRejectWithContact:_contact message:message];
            if (![[VoIPCallManager sharedVoIPCallManager] callAlreadyEnded]) {
                [[VoIPCallManager sharedVoIPCallManager] setCallAlreadyEnded:YES];
                Conversation *conversation = [_entityManager conversationForContact:_contact createIfNotExisting:YES];
                [_entityManager performSyncBlockAndSafe:^{
                    SystemMessage *systemMessage = [_entityManager.entityCreator systemMessageForConversation:conversation];
                    systemMessage.type = [NSNumber numberWithInteger:kSystemMessageCallRejected];
                    NSDictionary *argDict = @{@"DateString": [DateFormatter shortStyleTimeNoDate:[NSDate date]], @"CallInitiator": [NSNumber numberWithBool:_isCallInitiator]};
                    NSError *error;
                    NSData *data = [NSJSONSerialization dataWithJSONObject:argDict options:NSJSONWritingPrettyPrinted error:&error];
                    systemMessage.arg = data;
                    systemMessage.isOwn = [NSNumber numberWithBool:_isCallInitiator];
                    systemMessage.read = [NSNumber numberWithBool:YES];
                    systemMessage.conversation = conversation;
                    conversation.lastMessage = systemMessage;
                }];
            }
        }
        if (weakSelf.incomingCallTimer && [weakSelf.incomingCallTimer isValid]){
            [weakSelf.incomingCallTimer invalidate];
            weakSelf.incomingCallTimer = nil;
        }
        [self disconnect: false];
        [[CallManager sharedInstance] endCall];
        onCompletion();
    }];
}

- (void)rejectCallWithBusy:(Contact *)contact onCompletion:(void(^)(void))onCompletion {
    VoIPCallAnswerMessage *message = [VoIPCallAnswerMessage new];
    message.answer = nil;
    message.action = VoIPCallAnswerMessageActionReject;
    message.rejectReason = VoIPCallAnswerMessageRejectReasonBusy;
    [VoIPSender startVoIPCallAnswerRejectWithContact:contact message:message];
    Conversation *conversation = [_entityManager conversationForContact:_contact createIfNotExisting:YES];
    [_entityManager performSyncBlockAndSafe:^{
        SystemMessage *systemMessage = [_entityManager.entityCreator systemMessageForConversation:conversation];
        systemMessage.type = [NSNumber numberWithInteger:kSystemMessageCallMissed];
        NSDictionary *argDict = @{@"DateString": [DateFormatter shortStyleTimeNoDate:[NSDate date]], @"CallInitiator": [NSNumber numberWithBool:NO]};
        NSError *error;
        NSData *data = [NSJSONSerialization dataWithJSONObject:argDict options:NSJSONWritingPrettyPrinted error:&error];
        systemMessage.arg = data;
        systemMessage.isOwn = [NSNumber numberWithBool:NO];
        systemMessage.conversation = conversation;
        conversation.lastMessage = systemMessage;
        conversation.unreadMessageCount = [NSNumber numberWithInt:[[conversation unreadMessageCount] intValue] + 1];
    }];
    dispatch_async(dispatch_get_main_queue(),^{
        [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
    });
    onCompletion();
}

- (void)rejectCallWithDisabled:(Contact *)contact onCompletion:(void(^)(void))onCompletion {
    _state = VoIPCallManagerStateSystemRejected;
    VoIPCallAnswerMessage *message = [VoIPCallAnswerMessage new];
    message.answer = nil;
    message.action = VoIPCallAnswerMessageActionReject;
    message.rejectReason = VoIPCallAnswerMessageRejectReasonDisabled;
    [VoIPSender startVoIPCallAnswerRejectWithContact:contact message:message];
    dispatch_async(dispatch_get_main_queue(),^{
        [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
    });
    [[CallManager sharedInstance] endCall];
    [self disconnect: false];
    if (onCompletion != nil) {
        onCompletion();
    }
}

- (void)disconnect:(BOOL)playSound {
    void(^disconnectCallback)(void) = ^{
        [_connection close];
        _connection = nil;
    };
    
    if (playSound) {
        [self playTone:VoIPCallManagerToneHangup];
    }
    [[VoIPHelper shared] setIsCallActiveInBackground:NO];
    [[VoIPHelper shared] setContactName:nil];
    [[VoIPHelper shared] setLastUpdatedCallDuration:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCallInBackground object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationCallInBackgroundTimeChanged object:nil];
    
    if (_connection) {
        dispatch_async(dispatch_get_main_queue(),^{
            if (_statsTimer && [_statsTimer isValid]) {
                // Invalidate timer
                [_statsTimer invalidate];
                _statsTimer = nil;
                
                // Hijack the existing dict, override options and set callback
                VoIPStatsOptions *options = [[VoIPStatsOptions alloc] init];
                options.transport = true;
                options.inboundRtp = true;
                options.codecs = true;
                options.candidatePairsFlag = CandidatePairVariantOVERVIEW_AND_DETAILED;
                NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                      self.connection, @"connection",
                                      options, @"options",
                                      disconnectCallback, @"callback",
                                      nil];
                
                // One-shot stats fetch before disconnect
                [self logDebugStats:dict];
            } else {
                disconnectCallback();
            }
            [_incomingCallTimer invalidate];
            _incomingCallTimer = nil;
            _contact = nil;
            _callAlreadyEnded = NO;
            _isMuteEnabled = NO;
            [_iceCandidatesTimer invalidate];
            _iceCandidatesTimer = nil;
            [_callDurationTimer invalidate];
            _callDurationTimer = nil;
            _callDurationTime = 0;
            _callTimeString = @"";
            [_iceCandidates removeAllObjects];
            _state = VoIPCallManagerStateIdle;
        });
    }
}

- (void)muteAudioIn {
    RTCMediaStream *localStream = _connection.localStreams[0];
    self.defaultAudioTrack = localStream.audioTracks[0];
    [localStream removeAudioTrack:localStream.audioTracks[0]];
    [_connection removeStream:localStream];
    [_connection addStream:localStream];
    _isMuteEnabled = YES;
}
- (void)unmuteAudioIn {
    RTCMediaStream* localStream = _connection.localStreams[0];
    [localStream addAudioTrack:self.defaultAudioTrack];
    [_connection removeStream:localStream];
    [_connection addStream:localStream];
    _isMuteEnabled = NO;
}

- (BOOL)isMuteEnabled {
    return _isMuteEnabled;
}

- (void)invalidateDurationTimer {
    [_durationTimer invalidate];
    _durationTimer = nil;
}

- (void)setupTones {
    [self setupCallTone];
    [self setupHangupTone];
    [self setupPickupTone];
    [self setupRingTone];
    [self setupProblemTone];
    [self setupRejectedTone];
}

- (void)playTone:(VoIPCallManagerTone)tone {
    switch (tone) {
        case VoIPCallManagerToneCall:
            [_hangupPlayer stop];
            [_pickupPlayer stop];
            [_ringTonePlayer stop];
            [_problemPlayer stop];
            [_rejectedPlayer stop];
            
            [_callPlayer setCurrentTime:0];
            [_callPlayer play];
            break;
        case VoIPCallManagerToneHangup:
            [_callPlayer stop];
            [_pickupPlayer stop];
            [_ringTonePlayer stop];
            [_problemPlayer stop];
            [_rejectedPlayer stop];
            
            [_hangupPlayer play];
            break;
        case VoIPCallManagerTonePickup:
            [_callPlayer stop];
            [_hangupPlayer stop];
            [_ringTonePlayer stop];
            [_problemPlayer stop];
            [_rejectedPlayer stop];
            
            [_pickupPlayer play];
            break;
        case VoIPCallManagerToneRing:
            [_callPlayer stop];
            [_hangupPlayer stop];
            [_pickupPlayer stop];
            [_problemPlayer stop];
            [_rejectedPlayer stop];
            
            [_ringTonePlayer setCurrentTime:0];
            [_ringTonePlayer play];
            break;
        case VoIPCallManagerToneProblem:
            [_callPlayer stop];
            [_hangupPlayer stop];
            [_pickupPlayer stop];
            [_ringTonePlayer stop];
            [_rejectedPlayer stop];
            
            [_problemPlayer setCurrentTime:0];
            [_problemPlayer play];
            break;
        case VoIPCallManagerToneRejected:
            [_callPlayer stop];
            [_hangupPlayer stop];
            [_pickupPlayer stop];
            [_ringTonePlayer stop];
            [_problemPlayer stop];
            
            [_rejectedPlayer setCurrentTime:0];
            [_rejectedPlayer play];
        default:
            break;
    }
}

- (void)stopAllTones {
    [_callPlayer stop];
    [_hangupPlayer stop];
    [_pickupPlayer stop];
    [_ringTonePlayer stop];
    [_problemPlayer stop];
    [_rejectedPlayer stop];

    [[RTCAudioSession sharedInstance] lockForConfiguration];
    NSError *error = nil;
    if (![[RTCAudioSession sharedInstance] setActive:NO error:&error]) {
        NSLog(@"resume music player failed, error=%@", error);
    }
    [[RTCAudioSession sharedInstance] unlockForConfiguration];
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (![audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error]) {
        NSLog(@"resume music player failed, error=%@", error);
    }
}

- (void)activateRTCAudio {
    AVAudioSessionRouteDescription *currentRoute = [[RTCAudioSession sharedInstance] currentRoute];
    AVAudioSessionPortDescription *portDesc = [[currentRoute outputs] firstObject];
    if ([portDesc.portType isEqualToString:@"Speaker"]) {
        NSError *error;
        [[RTCAudioSession sharedInstance] lockForConfiguration];
        [[RTCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth error:nil];
        [[RTCAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
        [[RTCAudioSession sharedInstance] setActive:YES error:&error];
        [[RTCAudioSession sharedInstance] unlockForConfiguration];
        
        [[RTCAudioSession sharedInstance] lockForConfiguration];
        [[RTCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth error:nil];
        [[RTCAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        [[RTCAudioSession sharedInstance] setActive:YES error:&error];
        [[RTCAudioSession sharedInstance] unlockForConfiguration];
    } else {
        NSError *error;
        [[RTCAudioSession sharedInstance] lockForConfiguration];
        [[RTCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth error:nil];
        [[RTCAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        [[RTCAudioSession sharedInstance] setActive:YES error:&error];
        [[RTCAudioSession sharedInstance] unlockForConfiguration];
        
        [[RTCAudioSession sharedInstance] lockForConfiguration];
        [[RTCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth error:nil];
        [[RTCAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
        [[RTCAudioSession sharedInstance] setActive:YES error:&error];
        [[RTCAudioSession sharedInstance] unlockForConfiguration];
    }
}


#pragma mark - RTCPeerConnectionDelegate

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    
}

/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    // ignore
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    // ignore
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    // ignore
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    BOOL wasInitializing = _state == VoIPCallManagerStateInitializing;
    NSString *strState = [self stringForIceConnectionState:newState];
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat: @"Call: ICE connection state -> %@", strState]];
    if (newState == RTCIceConnectionStateChecking) {
        _state = VoIPCallManagerStateInitializing;
        
        [self playTone:VoIPCallManagerTonePickup];
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeVoiceChat options:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP error:nil];
        [session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        
        dispatch_async(dispatch_get_main_queue(),^{
            // Schedule 'connecting' stats timer
            VoIPStatsOptions *options = [[VoIPStatsOptions alloc] init];
            options.transport = true;
            options.inboundRtp = true;
            options.codecs = true;
            options.candidatePairsFlag = CandidatePairVariantOVERVIEW_AND_DETAILED;
            [self schedulePeriodStatsWithOptions:options period:kLogStatsIntervalConnecting];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStartDebugMode object:_connection];
        });
    } else if (newState == RTCIceConnectionStateConnected) {
        if (_state !=  VoIPCallManagerStateReconnecting) {
            [_callDurationTimer invalidate];
            _callDurationTimer = nil;
            _callDurationTime = 0;
            
            dispatch_async(dispatch_get_main_queue(),^{
                self.callDurationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateCallDurationTime) userInfo:nil repeats:YES];
                [[NSRunLoop mainRunLoop] addTimer:self.callDurationTimer forMode:NSRunLoopCommonModes];
                [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStartDebugMode object:_connection];
            });
        }
        _state = VoIPCallManagerStateCalling;
        [_callPlayer stop];
        [_hangupPlayer stop];
        [_ringTonePlayer stop];
        [_problemPlayer stop];
        _changedToWebRTCAudio = NO;
    } else if (newState == RTCIceConnectionStateCompleted) {
        _state = VoIPCallManagerStateCalling;
        [_callPlayer stop];
        [_hangupPlayer stop];
        [_ringTonePlayer stop];
        [_problemPlayer stop];
        
        if (_iceCandidatesTimer && [_iceCandidatesTimer isValid]){
            [_iceCandidatesTimer invalidate];
            _iceCandidatesTimer = nil;
        }
    } else if (newState == RTCIceConnectionStateFailed) {
        [self hangup];
    } else if (newState == RTCIceConnectionStateDisconnected) {
        _state = VoIPCallManagerStateReconnecting;
        dispatch_async(dispatch_get_main_queue(),^{
            // wait 2 seconds and play sound if its still on status reconnecting
            _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(playReconnecting:) userInfo:nil repeats:NO];
        });
    } else if (newState == RTCIceConnectionStateClosed) {
    }
    
    if (newState != RTCIceConnectionStateDisconnected) {
        dispatch_async(dispatch_get_main_queue(),^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kVoIPCallStatusChanged object:[NSNumber numberWithInt:_state]];
        });
    }
    
    if (wasInitializing && (newState == RTCIceConnectionStateConnected || newState == RTCIceConnectionStateCompleted)) {
        dispatch_async(dispatch_get_main_queue(),^{
            // Schedule 'connected' stats timer
            VoIPStatsOptions *options = [[VoIPStatsOptions alloc] init];
            options.transport = true;
            options.selectedCandidatePair = true;
            options.inboundRtp = true;
            options.codecs = true;
            options.candidatePairsFlag = CandidatePairVariantOVERVIEW;
            [self schedulePeriodStatsWithOptions:options period:kLogStatsIntervalConnected];
        });
    }
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    // ignore
}

/** New ice candidate has been found. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    if ([self shouldAddCandidate:candidate]) {
        if (_isCopyIceCandidates) {
            [_tmpIceCandidates addObject:candidate];
        } else {
            if (_tmpIceCandidates.count > 0) {
                [_iceCandidates addObjectsFromArray:_tmpIceCandidates];
                [_tmpIceCandidates removeAllObjects];
            }
            [_iceCandidates addObject:candidate];
        }
        
        dispatch_async(dispatch_get_main_queue(),^{
            if (!_iceCandidatesTimer) {
                _iceCandidatesTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(sendCandidates:) userInfo:nil repeats:YES];
            }
        });
    }
}

- (void)sendCandidates:(NSTimer *)timer {
    if (_iceCandidates.count) {
        _isCopyIceCandidates = YES;
        NSMutableArray *candidates = _iceCandidates.copy;
        [_iceCandidates removeAllObjects];
        _isCopyIceCandidates = NO;
        
        NSMutableArray *sendCandidates = [NSMutableArray new];
        int candidatesCount = 0;
        for (int i = 0; i < candidates.count; i++) {
            candidatesCount++;
            [sendCandidates addObject:candidates[i]];
            
            if (candidates.count > 0 && (candidatesCount == 5 || i == candidates.count - 1)) {
                VoIPCallIceCandidatesMessage *message = [VoIPCallIceCandidatesMessage new];
                message.removed = NO;
                message.candidates = sendCandidates.copy;
                [VoIPSender sendVoIPCallIceCandidatesMessage:message toContact:_contact];
                [sendCandidates removeAllObjects];
                candidatesCount = 0;
            }
        }
    }
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    // send it only all 50 milli seconds
    VoIPCallIceCandidatesMessage *message = [VoIPCallIceCandidatesMessage new];
    message.removed = YES;
    message.candidates = candidates;
    [VoIPSender sendVoIPCallIceCandidatesMessage:message toContact:_contact];
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {
    // ignore
}


#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [[RTCAudioSession sharedInstance] lockForConfiguration];
    NSError *error = nil;
    if (![[RTCAudioSession sharedInstance] setActive:NO error:&error]) {
        NSLog(@"resume music player failed, error=%@", error);
    }
    [[RTCAudioSession sharedInstance] unlockForConfiguration];
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (![audioSession setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error]) {
        NSLog(@"resume music player failed, error=%@", error);
    }
}


#pragma mark - RTCAudioSessionDelegate

- (void)audioSessionDidStartPlayOrRecord:(RTCAudioSession *)session {
    if ([session.currentRoute.outputs[0].portType isEqualToString:@"Speaker"]) {
        _isSpeakerActive = YES;
    } else {
        _isSpeakerActive = NO;
    }
    _changedToWebRTCAudio = YES;
}

- (void)audioSessionDidStopPlayOrRecord:(RTCAudioSession *)session {
    _changedToWebRTCAudio = NO;
}


#pragma mark - Notifications

- (void)handleRouteChange:(NSNotification *)notification {
    if (_changedToWebRTCAudio && _isSpeakerActive) {
        NSError *error;
        [[RTCAudioSession sharedInstance] lockForConfiguration];
        [[RTCAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionAllowBluetooth error:nil];
        [[RTCAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        [[RTCAudioSession sharedInstance] setActive:YES error:&error];
        [[RTCAudioSession sharedInstance] unlockForConfiguration];
    }
}

@end
