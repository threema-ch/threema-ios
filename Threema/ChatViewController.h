//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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
#import "ChatBar.h"
#import "PreviewImageViewController.h"
#import "ChatViewHeader.h"
#import "PlayRecordAudioViewController.h"
#import "ThemedViewController.h"

@class Conversation;
@class BaseMessage;
@class ImageMessage;
@class LocationMessage;
@class VideoMessage;
@class AudioMessage;
@class ChatMessageCell;
@class BallotMessage;
@class FileMessage;

@class PPAssetsActionController;
@class ChatViewControllerAction;

typedef void (^ChatViewControllerCompletionBlock)(ChatViewController *chatViewController);

@protocol ChatViewControllerDelegate <NSObject>

- (void)presentChatViewController:(ChatViewController *)chatViewController onCompletion:(ChatViewControllerCompletionBlock)onCompletion;
- (void)cancelSwipeGestureFromConversations;
- (void)pushSettingChanged:(Conversation *)conversation;

@end

@interface ChatViewController : ThemedViewController <ChatBarDelegate, PreviewImageViewControllerDelegate, ChatViewHeaderDelegate, UIScrollViewDelegate, PlayRecordAudioDelegate> {

}

@property (nonatomic, assign) SystemSoundID sentMessageSound;

@property (nonatomic, retain) UITableView *chatContent;

@property ChatViewHeader *headerView;

@property (weak, nonatomic) IBOutlet UIView *chatContentHeader;
@property (nonatomic, strong) ChatBar *chatBar;
@property (weak, nonatomic) IBOutlet UIButton *loadEarlierMessages;

@property (nonatomic, strong) Conversation *conversation;

@property (nonatomic) BOOL composing;
@property (nonatomic) BOOL searching;
@property (nonatomic) NSString *searchPattern;

@property (nonatomic) BOOL isOpenWithForceTouch;

@property (readwrite) NSString *messageText;
@property (nonatomic, strong) NSData *imageDataToSend;

@property (nonatomic) int deleteMediaTotal;

@property (weak) id<ChatViewControllerDelegate> delegate;

@property (nonatomic) BOOL showHeader;

- (void)setCurrentAction:(ChatViewControllerAction *)newAction;

- (BOOL)visible;

- (CGFloat)visibleChatHeight;

- (void)refresh;

- (IBAction)loadEarlierMessagesAction:(id)sender;

- (void)showContentAfterForceTouch;
- (void)startRecordingAudio;
- (void)createBallot;
- (void)sendFile;

- (void)imageMessageTapped:(ImageMessage *)message;
- (void)fileImageMessageTapped:(FileMessage *)message;
- (void)locationMessageTapped:(LocationMessage*)message;
- (void)fileVideoMessageTapped:(FileMessage *)message;
- (void)videoMessageTapped:(VideoMessage *)message;
- (void)audioMessageTapped:(AudioMessage *)message;
- (void)fileAudioMessageTapped:(FileMessage *)message;
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

@end
