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

#import <UIKit/UIKit.h>
#import "PlayRecordAudioView.h"
#import "Conversation.h"
#import "AppDelegate.h"

@protocol PlayRecordAudioDelegate
- (void)audioPlayerDidHide;
@end

@interface PlayRecordAudioViewController : UIViewController <MagicTapHandler>

+ (instancetype) playRecordAudioViewControllerIn:(UIViewController *)viewController;

+ (BOOL)canRecordAudio;
+ (void)activateProximityMonitoring;
+ (void)deactivateProximityMonitoring;

+ (void)requestMicrophoneAccessOnCompletion:(void(^)(void))onCompletion;

- (void)startRecordingForConversation:(Conversation *)conversation;
- (void)startPlaying:(NSURL *) audioFile;
- (void)cancel;

- (IBAction)playPauseStopButtonPressed:(id)sender;
- (IBAction)recordButtonPressed:(id)sender;
- (IBAction)sendButtonPressed:(id)sender;
- (IBAction)speedButtonPressed:(id)sender;

@property (strong, nonatomic) IBOutlet PlayRecordAudioView *audioView;
@property (weak, nonatomic) id<PlayRecordAudioDelegate> delegate;

@end
