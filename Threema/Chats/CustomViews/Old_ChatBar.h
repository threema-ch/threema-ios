//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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
#import "CustomResponderTextView.h"
#import "HPGrowingTextView.h"
#import "QuoteView.h"

@class Old_ChatBar, Contact;

@protocol Old_ChatBarDelegate <NSObject>

- (void)old_chatBar:(Old_ChatBar*)chatBar didChangeHeight:(CGFloat)height;
- (void)old_chatBar:(Old_ChatBar*)chatBar didSendText:(NSString*)text;
- (void)old_chatBar:(Old_ChatBar*)chatBar didSendImageData:(NSData*)image;
- (void)old_chatBar:(Old_ChatBar *)chatBar didPasteImageData:(NSData *)image;
- (void)old_chatBar:(Old_ChatBar*)chatBar didPasteItems:(NSArray*)items;
- (void)old_chatBarWillStartTyping:(Old_ChatBar*)chatBar;
- (void)old_chatBarDidStopTyping:(Old_ChatBar*)chatBar;

- (void)old_chatBarDidPushAddButton:(Old_ChatBar*)chatBar;
- (void)old_chatBarDidAddQuote;

- (UIInterfaceOrientation)interfaceOrientationForChatBar:(Old_ChatBar*)chatBar;

- (BOOL)canBecomeFirstResponder;
- (void)old_chatBarTapped:(Old_ChatBar*)chatBar;

- (UIView *)chatContainterView;

@end

@interface Old_ChatBar : UIImageView <UITextViewDelegate, UIGestureRecognizerDelegate, PasteImageHandler, HPGrowingTextViewDelegate, QuoteViewDelegate>

@property (nonatomic, retain) HPGrowingTextView *chatInput;
@property (nonatomic, retain) UIButton *sendButton;
@property (nonatomic, retain) UIButton *addButton;

@property (readwrite) NSString* text;

@property (nonatomic, weak) id<Old_ChatBarDelegate> delegate;

@property (nonatomic) BOOL resettingKeyboard;

@property (nonatomic) BOOL canSendAudio;

- (id)initWithFrame:(CGRect)frame conversation:(Conversation * _Nonnull)conversation;

- (void)clearChatInput;
- (void)resizeChatInput;

- (void)checkEnableSendButton;

- (void)stopTyping;

- (void)refresh;

- (void)addQuotedText:(NSString*)quotedText quotedContact:(ContactEntity*)contact;
- (void)addQuotedMessage:(BaseMessage *)quotedMessage;

- (void)resetKeyboardType:(BOOL)resetType;
- (void)setupMentions:(NSArray *)OEMemberListOfGroup;
- (NSString *)formattedMentionText;
- (void)updateMentionsFromDraft:(NSString *)draft;

@end
