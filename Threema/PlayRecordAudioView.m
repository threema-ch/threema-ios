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

#import "PlayRecordAudioView.h"
#import "UIImage+ColoredImage.h"
#import "Utils.h"
#import "BundleUtil.h"
#import "AudioRecorder.h"

#define AUDIO_PLAY_COLOR [UIColor blackColor]
#define AUDIO_RECORD_COLOR [UIColor redColor]

@interface PlayRecordAudioView () <RecordingMeterGraphProtocol>
@property AudioRecorder *recorder;
@property AVAudioPlayer *player;
@property NSTimer *updateTimer;

@property UIImage *playImage;
@property UIImage *stopImage;
@property UIImage *pauseImage;

@property BOOL quitNameSet;

@end

@implementation PlayRecordAudioView

- (void)setup {
    self.backgroundColor = [Colors backgroundDark];
    
    _playImage = [UIImage imageNamed:@"Play" inColor:[Colors fontNormal]];
    _playImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"play"];
    
    _stopImage = [UIImage imageNamed:@"Stop" inColor:[Colors fontNormal]];
    _stopImage.accessibilityLabel = @"stop";
    _stopImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"stop"];

    _pauseImage = [UIImage imageNamed:@"Pause" inColor:[Colors fontNormal]];
    _pauseImage.accessibilityLabel = [BundleUtil localizedStringForKey:@"pause"];

    [_playPauseStopButton setImage:_playImage forState:UIControlStateNormal];
    
    UIImage *tmpImage = [UIImage imageNamed:@"Record" inColor:AUDIO_RECORD_COLOR];
    UIImage *recordImage = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [_recordButton setImage:recordImage forState:UIControlStateNormal];
    _recordButton.tintColor = AUDIO_RECORD_COLOR;
    
    _recordButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"record"];
    
    self.layer.cornerRadius = 10.0;
    
    [_sendButton setTitle:NSLocalizedString(@"send", nil) forState:UIControlStateNormal];

    _timeCursorLabel.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    
    [self setupColors];
}

- (void)setupColors {
    [_sendButton setTitleColor:[Colors main] forState:UIControlStateNormal];
    
    _dataView.backgroundColor = [Colors background];
    _buttonView.backgroundColor = [Colors backgroundDark];
    
    _timeCursorLabel.textColor = [Colors fontNormal];
    _durationLabel.textColor = [Colors fontNormal];
    
    _horizontalDividerLine.backgroundColor = [Colors hairline];
    _verticalDividerLine.backgroundColor = [Colors hairline];
    
    _speedButton.backgroundColor = [Colors backgroundDark];
    _speedButton.clipsToBounds = YES;
    [_speedButton setTitleColor:[Colors fontNormal] forState:UIControlStateNormal];
    _speedButton.layer.cornerRadius = 15.0;
}

- (void)setupForPlaying:(AVAudioPlayer *)player {
    _player = player;
    _recorder = nil;
    
    _quitNameSet = NO;
    
    [_graphView drawAudioTrack: player];
    _graphView.delegate = self;

    [self setPlaying];
}

- (void)setPlaying {
    _recordButton.enabled = NO;
    _speedButton.hidden = false;
    [_playPauseStopButton setImage:_pauseImage forState:UIControlStateNormal];
    [self updateTimerFired];
    
    if (_player.playing) {
        [_graphView setPlaying:YES];
        [self startTimeUpdater];
    }
}

- (void)setupForRecording:(AudioRecorder *)recorder {
    _player = nil;
    _recorder = recorder;
    
    _quitNameSet = NO;
    
    [self setRecording];
    
    [_graphView reset];
    [_graphView drawLiveRecorder: recorder.recorder];
}

- (void)setRecording {
    _recordButton.enabled = NO;
    _speedButton.hidden = true;
    [_playPauseStopButton setImage:_stopImage forState:UIControlStateNormal];
    
    if (_recorder.recording) {
        [_graphView setRecording:YES];
        [self startTimeUpdater];
    } else {
        [_recorder setInterruptedAndNotStarted:true];
    }
}

- (void)setPaused {
    _recordButton.enabled = YES;
    _speedButton.hidden = false;
    [_playPauseStopButton setImage:_playImage forState:UIControlStateNormal];
    [self stopTimeUpdater];
}

- (void)setStopped {
    _recordButton.enabled = YES;
    _speedButton.hidden = false;
    [_playPauseStopButton setImage:_playImage forState:UIControlStateNormal];
    
    [_graphView setPlaying:NO];
    
    [self stopTimeUpdater];
    [self updateTimerFired];
}

- (void)startTimeUpdater {
    [_updateTimer invalidate];

    _updateTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(updateTimerFired) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_updateTimer forMode:NSDefaultRunLoopMode];

    [self updateTimerFired];
}

- (void)stopTimeUpdater {
    [_updateTimer invalidate];
    _updateTimer = nil;
}

- (void)setFinishedRecording {
    [_playPauseStopButton setImage:_playImage forState:UIControlStateNormal];
    _recordButton.enabled = YES;
}

-(void)toggleButtonsForRecording:(BOOL)hidden {
    if (_recordButton.hidden && hidden)
        _playPauseStopButton.frame = CGRectOffset(_playPauseStopButton.frame, -10, 0);
    else if (!_recordButton.hidden && !hidden)
        _playPauseStopButton.frame = CGRectOffset(_playPauseStopButton.frame, 10, 0);
    
    _recordButton.hidden = !hidden;

    _verticalDividerLine.hidden = !hidden;
    _sendButton.hidden = !hidden;
}

- (void)updateTimerFired {
    NSTimeInterval duration, position;
    
    if (_recorder) {
        duration = 0.0;
        position = _recorder.currentTime;        
    } else if (_player) {
        position = _player.currentTime;
        duration = _player.duration;
    } else {
        position = 0.0;
        duration = 0.0;
    }
    
    if (position > 2  && !_quitNameSet) {
        _quitNameSet = YES;
        [_delegate setAccessibilityLabelForQuit];
    }
    
    _durationLabel.text = [Utils timeStringForSeconds:duration];
    _timeCursorLabel.text = [Utils timeStringForSeconds:position];
    
    if (UIAccessibilityIsVoiceOverRunning()) {
        _durationLabel.accessibilityLabelBlock = ^NSString *() {
            return [Utils accessibilityStringAtTime:duration withPrefix:@"duration"];
        };

        _timeCursorLabel.accessibilityLabelBlock = ^NSString *() {
            return [Utils accessibilityStringAtTime:position withPrefix:@"current_position"];
        };
    }
}

#pragma mark - RecordingMeterGraphProtocol

- (void)didUpdatePlayerPosition {
    [self updateTimerFired];
}

@end
