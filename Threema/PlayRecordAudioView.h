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

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "RecordingMeterGraph.h"
#import "LazyAccessibilityLabel.h"

@class AudioRecorder;

@protocol PlayRecordAudioViewDelegate <NSObject>

- (void)setAccessibilityLabelForQuit;

@end

@interface PlayRecordAudioView : UIView

@property id<PlayRecordAudioViewDelegate> delegate;

@property (weak, nonatomic) IBOutlet UIButton *playPauseStopButton;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@property (weak, nonatomic) IBOutlet LazyAccessibilityLabel *timeCursorLabel;
@property (weak, nonatomic) IBOutlet LazyAccessibilityLabel *durationLabel;

@property (weak, nonatomic) IBOutlet RecordingMeterGraph *graphView;
@property (weak, nonatomic) IBOutlet UIView *dataView;
@property (weak, nonatomic) IBOutlet UIView *buttonView;

@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@property (weak, nonatomic) IBOutlet UIView *horizontalDividerLine;
@property (weak, nonatomic) IBOutlet UIView *verticalDividerLine;

- (void)setup;
- (void)setupForPlaying:(AVAudioPlayer *)player;
- (void)setupForRecording:(AudioRecorder *)recorder;

- (void)setPlaying;
- (void)setRecording;
- (void)setPaused;
- (void)setStopped;
- (void)setFinishedRecording;

- (void)toggleButtonsForRecording:(BOOL)hidden;


@end
