//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import "RecordingMeterGraph.h"
#import "RectUtil.h"
#import "AudioTrackAnalyzer.h"
#import "ThreemaUtilityObjC.h"
#import "BundleUtil.h"

//    0db max output
// -160db min output
//  -50db noise level
#define DECIBEL_RANGE 50.0f
#define NOISE_OFFSET -50.0f

#define GRAPH_LINE_MIN_HEIGHT 2.0f
#define GRAPH_LINE_WIDTH 1.5f
#define TIMER_INTERVAL_RECORDER 0.5f
#define Y_OFFSET

#define COLOR_RECORDING [UIColor redColor]
#define COLOR_PLAY_FUTURE Colors.textLight
#define COLOR_PLAY_PAST Colors.primary
#define COLOR_PLAY_CURRENT COLOR_PLAY_PAST

@interface RecordingMeterGraph () <AudioTrackAnalyzerDelegate>

@property AVAudioRecorder *recorder;
@property AVAudioPlayer *player;
@property NSTimer *recordTimer;
@property NSTimer *playTimer;
@property NSInteger numberOfChanels;

@property float scale;
@property CGFloat numberOfSamples;
@property CGFloat runningXOffset;
@property CGFloat noiseOffset;

@property CGFloat widthPerSample;
@property UIColor *graphColor;

@property UIView *slider;

@end

@implementation RecordingMeterGraph

- (void)reset {
    [self setup];
}

- (void)setup {
    _widthPerSample = GRAPH_LINE_WIDTH * 2.0;
    _runningXOffset = 0.0;
    _noiseOffset = NOISE_OFFSET;
    _scale = self.frame.size.height/(DECIBEL_RANGE);
    
    [_playTimer invalidate];
    [_recordTimer invalidate];
    
    for (UIView *view in [self subviews]) {
        [view removeFromSuperview];
    }
    
    self.accessibilityTraits |= UIAccessibilityTraitAdjustable;
    self.accessibilityLabel = [BundleUtil localizedStringForKey:@"voice message"];

    self.backgroundColor = Colors.backgroundAudioPlayer;
}

- (void)drawLiveRecorder:(AVAudioRecorder *)recorder {
    [self setup];
    
    _graphColor = COLOR_RECORDING;
    _recorder = recorder;
    _recorder.meteringEnabled = YES;
    
    NSDictionary *settings = [_recorder settings];
    NSNumber *number = [settings objectForKey: @"AVNumberOfChannelsKey"];
    _numberOfChanels = [number integerValue];
    
    [self setRecording:YES];
}

- (void)drawAudioTrack:(AVAudioPlayer *)player {
    [self setup];
    
    _player = player;
    _graphColor = COLOR_PLAY_FUTURE;
    
    _numberOfSamples = self.frame.size.width / _widthPerSample;
    
    AudioTrackAnalyzer *analyzer = [AudioTrackAnalyzer audioTrackAnalyzerFor:player.url];
    analyzer.delegate = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [analyzer reduceAudioToDecibelLevels: _numberOfSamples];
    });
}

- (void)setPlaying:(BOOL)playing {
    if (playing && _player && _playTimer.valid == NO) {
        NSTimeInterval interval = _player.duration / (4.0 * _numberOfSamples);
        _playTimer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(timerFiredPlayer) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_playTimer forMode:NSDefaultRunLoopMode];
    } else {
        [_playTimer invalidate];
    }
}

- (void)setRecording:(BOOL)recording {
    if (recording && _recordTimer.valid == NO) {
        _recordTimer = [NSTimer timerWithTimeInterval:TIMER_INTERVAL_RECORDER target:self selector:@selector(timerFiredRecorder) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_recordTimer forMode:NSDefaultRunLoopMode];
    } else {
        [_recordTimer invalidate];
    }
}

#pragma mark - AudioTrackAnalyzerDelegate

- (void)trackAnalyzerNextValue:(Float32)value {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self drawNextSample: value];
    });
}

-(void)trackAnalyzerFinished {
    ;//nop
}

- (void)drawNextSample:(CGFloat)value {
    CGRect rect = [self rectForValue:value];
    
    UIView *view = [[UIView alloc] initWithFrame: rect];
    view.backgroundColor = _graphColor;
    [self addSubview: view];
}

- (void)timerFiredRecorder {
    if (_recorder.isRecording == NO) {
        [_recordTimer invalidate];
        return;
    }
    
    CGFloat decibel = [self avgForAllChanels];
    
    CGRect rect = [self rectForValue:decibel];
    
    UIView *view = [[UIView alloc] initWithFrame: rect];
    view.backgroundColor = _graphColor;
    [self addSubview: view];
}

- (void)timerFiredPlayer {
    if (_player.playing == NO) {
        [_playTimer invalidate];
        return;
    }
    
    [self updateGraph];
}

- (void)updateGraph {
    CGFloat currentPos = [self xAtCurrentPlayerTime];
    for (UIView *view in [self subviews]) {
        if (view == _slider) {
            continue;
        }
        
        if (CGRectGetMaxX(view.frame) < currentPos) {
            view.backgroundColor = COLOR_PLAY_PAST;
        } else if (CGRectGetMinX(view.frame) < currentPos) {
            view.backgroundColor = COLOR_PLAY_CURRENT;
        } else {
            view.backgroundColor = COLOR_PLAY_FUTURE;
        }
    }
    
    if (_delegate) {
        [_delegate didUpdatePlayerPosition];
    }
}

- (CGFloat)xAtCurrentPlayerTime {
    return _player.currentTime/_player.duration * self.frame.size.width;
}

- (CGFloat)currentPlayerTimeForX:(CGFloat)x {
    return x/self.frame.size.width * _player.duration;
}

- (CGRect)rectForValue:(CGFloat)value {
    CGFloat avgOffset = value - _noiseOffset;
    
    CGFloat scaledAvg = avgOffset * _scale;
    scaledAvg = fmaxf(GRAPH_LINE_MIN_HEIGHT, scaledAvg); // draw at least 1px
    scaledAvg = fminf(self.frame.size.height, scaledAvg); // clip on top edge
    
    CGFloat y = self.frame.size.height - scaledAvg;
    
    CGRect rect = CGRectMake(_runningXOffset, y, GRAPH_LINE_WIDTH, scaledAvg);
    
    if (_runningXOffset >= self.frame.size.width - GRAPH_LINE_WIDTH) {
        [self shiftGraphBy: _widthPerSample];
    } else {
        _runningXOffset += _widthPerSample;
    }
    
    return rect;
}

- (void)shiftGraphBy:(CGFloat)offset {
    for (UIView *view in [self subviews]) {
        view.frame = [RectUtil offsetRect:view.frame byX: -offset byY:0.0];
        
        if (view.frame.origin.x < 0.0) {
            [view removeFromSuperview];
        }
    }
}

- (CGFloat)avgForAllChanels {
    [_recorder updateMeters];
    
    CGFloat avgSum = 0.0;
    for (int i=0; i<_numberOfChanels; i++) {
        avgSum += [_recorder averagePowerForChannel: i];
    }
    
    return avgSum / (CGFloat) _numberOfChanels;
}

#pragma mark - Slider

- (void)addSliderView:(CGPoint) point {
    CGRect rect = [self sliderRect:point];
    _slider = [[UIView alloc] initWithFrame: rect];
    _slider.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.3];
    [self addSubview: _slider];
}

- (CGRect)sliderRect:(CGPoint) point {
    CGFloat x = point.x;
    
    x = fmin(self.frame.size.width, x);
    x = fmax(1.0, x);
    
    CGFloat y = 0.0;
    CGRect rect = CGRectMake(0.0, y, x, self.frame.size.height);
    
    return rect;
}

- (void)updateSliderTo:(CGPoint)point {
    _player.currentTime = [self currentPlayerTimeForX: point.x];
    _slider.frame = [self sliderRect: point];
}

#pragma mark - touch handling for slider

- (void)clearSlider {
    [_slider removeFromSuperview];
    _slider = nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (_recorder.isRecording) {
        return;
    }
    
    if ([touches count] == 1 && _slider == nil) {
        UITouch *touch = [touches anyObject];
        CGPoint position = [touch locationInView: self];
        [self addSliderView: position];
        [self updateSliderTo:position];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_recorder.isRecording) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint position = [touch locationInView: self];

    if (UIAccessibilityIsVoiceOverRunning() == NO) {
        // for some reason this is extremly slow when accessability is enabled
        [self updateSliderTo:position];
        [self updateGraph];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (UIAccessibilityIsVoiceOverRunning()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *timeString = [ThreemaUtilityObjC accessibilityStringAtTime:_player.currentTime withPrefix:@"go_to_position"];
            
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, timeString);
        });
    }

    [self clearSlider];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self clearSlider];
}

#pragma mark - Accessability

- (BOOL)isAccessibilityElement {
    return YES;
}

- (void)accessibilityIncrement {
    NSTimeInterval time =  _player.currentTime;
    _player.currentTime = time + ((_player.duration/100)*10);
    [self updateGraph];
    NSString *timeString = [ThreemaUtilityObjC accessibilityStringAtTime:_player.currentTime withPrefix:@"go_to_position"];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, timeString);
}

- (void)accessibilityDecrement {
    NSTimeInterval time =  _player.currentTime;
    _player.currentTime = time - ((_player.duration/100)*10);
    [self updateGraph];
    NSString *timeString = [ThreemaUtilityObjC accessibilityStringAtTime:_player.currentTime withPrefix:@"go_to_position"];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, timeString);
}

@end
