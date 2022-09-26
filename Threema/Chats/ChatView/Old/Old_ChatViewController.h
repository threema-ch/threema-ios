//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import <AudioToolbox/AudioToolbox.h>
#import <CoreData/CoreData.h>
#import "Old_ChatBar.h"
#import "PreviewImageViewController.h"
#import "ChatViewHeader.h"
#import "PlayRecordAudioViewController.h"
#import "Old_ThemedViewController.h"
#import "ChatViewControllerActionsProtocol.h"

@class Conversation;
@class BaseMessage;
@class ImageMessageEntity;
@class LocationMessage;
@class VideoMessageEntity;
@class AudioMessageEntity;
@class ChatMessageCell;
@class BallotMessage;
@class FileMessageEntity;

@class PPAssetsActionController;
@class ChatViewControllerAction;

typedef void (^Old_ChatViewControllerCompletionBlock)(Old_ChatViewController *chatViewController);

@protocol Old_ChatViewControllerDelegate <NSObject>

- (void)presentOld_ChatViewController:(Old_ChatViewController *) chatViewController onCompletion:(Old_ChatViewControllerCompletionBlock)onCompletion;
- (void)pushSettingChanged:(Conversation *)conversation;

@end

@interface Old_ChatViewController : Old_ThemedViewController <Old_ChatBarDelegate, PreviewImageViewControllerDelegate, ChatViewHeaderDelegate, UIScrollViewDelegate, PlayRecordAudioDelegate, ChatViewControllerActionsProtocol> {

}

@property (nonatomic, assign) SystemSoundID sentMessageSound;

@property (nonatomic, retain) UITableView *chatContent;

@property ChatViewHeader *headerView;

@property (weak, nonatomic) IBOutlet UIView *chatContentHeader;
@property (nonatomic, strong) Old_ChatBar *chatBar;
@property (weak, nonatomic) IBOutlet UIButton *loadEarlierMessages;

@property (nonatomic, strong) Conversation *conversation;

@property (nonatomic) BOOL composing;
@property (nonatomic) BOOL searching;
@property (nonatomic) NSString *searchPattern;

@property (nonatomic) BOOL isOpenWithForceTouch;

@property (readwrite) NSString *messageText;
@property (nonatomic, strong) NSData *imageDataToSend;

@property (nonatomic) int deleteMediaTotal;

@property (weak) id<Old_ChatViewControllerDelegate> delegate;

@property (nonatomic) BOOL showHeader;

- (void)setCurrentAction:(ChatViewControllerAction * _Nonnull)newAction;

- (BOOL)visible;

- (CGFloat)visibleChatHeight;

- (void)refresh;

- (IBAction)loadEarlierMessagesAction:(id)sender;

- (void)showContentAfterForceTouch;
- (void)startRecordingAudio;
- (void)createBallot;
- (void)sendFile;

- (void)imageMessageTapped:(ImageMessageEntity *)message;
- (void)fileImageMessageTapped:(FileMessageEntity *)message;
- (void)locationMessageTapped:(LocationMessage*)message;
- (void)fileVideoMessageTapped:(FileMessageEntity *)message;
- (void)videoMessageTapped:(VideoMessageEntity *)message;
- (void)audioMessageTapped:(AudioMessageEntity *)message;
- (void)fileAudioMessageTapped:(FileMessageEntity *)message;
- (void)showMessageDetails:(BaseMessage *)message;
- (void)messageBackgroundTapped:(BaseMessage*)message;
- (void)ballotMessageTapped:(BallotMessage*)message;
- (void)mentionTapped:(id)mentionObject;
- (void)showQuotedMessage:(BaseMessage *)message;
- (void)openPushSettings;

- (void)updateConversation;
- (void)updateConversationLastMessage;

- (void)presentActivityViewController:(UIActivityViewController *)viewControllerToPresent animated:(BOOL)flag fromView:(UIView *)view;

- (NSInteger)messageOffset;

- (NSIndexPath *)indexPathForMessage:(BaseMessage *)message;

- (id)objectAtIndexPath:(NSIndexPath *)indexPath;

- (void)observeUpdatesForMessage:(BaseMessage *)message;

- (void)startVoipCall:(BOOL)withVideo;

- (void)removeConversationObservers;

- (void)cleanCellHeightCache;

- (void)showHeaderWithDuration:(CGFloat)duration completion:(void (^ __nullable)(BOOL finished))completion;

- (void)showSingleDetails;
- (void)showGroupDetails;

@end
