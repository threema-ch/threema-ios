//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "ChatBar.h"
#import "ChatDefines.h"
#import "UserSettings.h"
#import "ServerConnector.h"
#import "BundleUtil.h"
#import "UIImage+ColoredImage.h"
#import "RectUtil.h"
#import "Contact.h"
#import "QuoteView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "AppDelegate.h"
#import "Threema-Swift.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface ChatBar () <OEMentionsHelperDelegate, HPGrowingTextViewDelegate>

@end

@implementation ChatBar {
    BOOL typing;
    dispatch_source_t typing_timer;
    UITapGestureRecognizer *chatBarTapRecognizer;
    UIPanGestureRecognizer *chatBarPanRecognizer;
    
    NSInteger takePhotoIndex;
    NSInteger chooseExistingIndex;
    
    CGFloat minChatBarHeight;
    float fontSize;
    NSString *sendButtonText;
    BOOL microphoneShowing;
    
    CGSize sendButtonTextSize;
    CGFloat additionalWidth;
    
    UIView *hairlineView;
    
    UIImage *microphoneImage;
    UIView *chatInputBackgroundView;
    QuoteView *quoteView;
    
    CGFloat chatBarHeight;
    
    OEMentionsHelper *oementionsHelper;
    UIView *addMentionView;
    
    dispatch_queue_t typingQueue;
    
    BOOL updateTextColorForEmptyString;
}

#define kChatInputPadding 6.0
#define kTypingTimeout 10
#define kQuoteViewSpacing 6.0

@synthesize chatInput;
@synthesize sendButton;
@synthesize addButton;

@synthesize delegate;
@synthesize canSendAudio;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        fontSize = [UserSettings sharedUserSettings].chatFontSize;
        
        minChatBarHeight = frame.size.height;
        chatBarHeight = minChatBarHeight;
        
        self.userInteractionEnabled = YES;
        self.clearsContextBeforeDrawing = NO;
        self.clipsToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;

        chatBarTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(chatBarTapped)];
        chatBarTapRecognizer.delegate = self;
        [self addGestureRecognizer:chatBarTapRecognizer];
        chatBarPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(chatBarPanned:)];
        chatBarPanRecognizer.delegate = self;
        [self addGestureRecognizer:chatBarPanRecognizer];
        
        sendButtonText = NSLocalizedString(@"send", nil);
        UIFont *sendButtonFont = [UIFont boldSystemFontOfSize:16.0f];
        sendButtonTextSize = [sendButtonText sizeWithAttributes:@{NSFontAttributeName : sendButtonFont}];
        
        additionalWidth = 18.0f;

        CGRect chatInputBackgroundRect = CGRectMake(42, kChatInputPadding, 244 - sendButtonTextSize.width + additionalWidth, self.frame.size.height - (2*kChatInputPadding));
        chatInputBackgroundView = [[UIView alloc] initWithFrame:chatInputBackgroundRect];
        chatInputBackgroundView.clipsToBounds = YES;
        [self addSubview:chatInputBackgroundView];

        // Create chatInput.
        CGRect chatInputRect = CGRectMake(0.0, 0.0, chatInputBackgroundRect.size.width, 40.0);
        chatInput = [[HPGrowingTextView alloc] initWithFrame:chatInputRect];
        chatInput.isScrollable = NO;
        chatInput.contentInset = UIEdgeInsetsMake(0, 3, 0, 3);
        chatInput.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(5, 0, 5, 0);
        chatInput.delegate = self;
        chatInput.minNumberOfLines = 1;
        chatInput.maxNumberOfLines = 6;
        chatInput.font = [UIFont systemFontOfSize:fontSize];
        chatInput.dataDetectorTypes = UIDataDetectorTypeAll;
        chatInput.internalTextView.scrollsToTop = NO;
        ((CustomResponderTextView*)chatInput.internalTextView).pasteImageHandler = self;
        [self updateMaxNumberOfLines];
        [chatInputBackgroundView addSubview:chatInput];
        
        // center chatInput again since it might have adapted its height after initialising
        chatInput.frame = [RectUtil rect:chatInput.frame centerIn:chatInputBackgroundView.bounds round:YES];

        // Create addButton.
        CGFloat addButtonYOffset = 1;
        addButton = [UIButton buttonWithType:UIButtonTypeCustom];
        addButton.clearsContextBeforeDrawing = NO;
        addButton.frame = CGRectMake(0, 0, 40, 40);
        addButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        addButton.imageEdgeInsets = UIEdgeInsetsMake(addButtonYOffset, 2, 0, 0);
        addButton.accessibilityLabel = NSLocalizedString(@"send_media_or_location", nil);
        addButton.accessibilityIdentifier = @"PlusButton";
        [addButton addTarget:self action:@selector(addAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:addButton];
        
        // Create sendButton.
        CGFloat sendButtonOffset = 8.0f;
        sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
        sendButton.clearsContextBeforeDrawing = NO;
        sendButton.frame = CGRectMake(self.frame.size.width - 24.0f - sendButtonTextSize.width + sendButtonOffset, 7.0f, sendButtonTextSize.width + 16.0f, 27.0f);
        sendButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
        sendButton.titleLabel.font = sendButtonFont;
        [sendButton setTitle:sendButtonText forState:UIControlStateNormal];
        
        [sendButton addTarget:self action:@selector(sendItemAction:) forControlEvents:UIControlEventTouchUpInside];
        [self checkEnableSendButton]; // disable initially
        [self addSubview:sendButton];
        
        // Set typing timer
        typingQueue = dispatch_queue_create("ch.threema.typingQueue", 0);

        typing_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, typingQueue);
        dispatch_source_set_event_handler(typing_timer, ^{
            [self stopTyping];
        });
        
        CGRect hairlineRect = CGRectMake(0.0, 0.0, CGRectGetWidth(self.bounds), 0.5);
        hairlineView = [[UIView alloc] initWithFrame:hairlineRect];
        hairlineView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:hairlineView];
        
        quoteView = [[QuoteView alloc] init];
        quoteView.hidden = YES;
        quoteView.delegate = self;
        quoteView.buttonWidthHint = sendButtonTextSize.width + additionalWidth;
        [self addSubview:quoteView];
        
        addMentionView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, frame.size.width, self.frame.size.height)];
        addMentionView.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.7];
        addMentionView.hidden = true;
        [self addSubview:addMentionView];
        
        [self setupColors];
        
        // Listen for connection status changes so we can enable/disable the send button
        [[ServerConnector sharedServerConnector] addObserver:self forKeyPath:@"connectionState" options:0 context:nil];
        
        updateTextColorForEmptyString = false;
        [self updateHeight];
    }
    return self;
}

- (void)setupColors {
    [Colors updateKeyboardAppearanceFor:(id<UITextInputTraits>)chatInput];
    
    self.backgroundColor = [Colors chatBarBackground];
    chatInput.backgroundColor = [UIColor clearColor];

    chatInputBackgroundView.backgroundColor = [Colors chatBarInput];
    chatInputBackgroundView.layer.borderWidth = 0.5;
    chatInputBackgroundView.layer.cornerRadius = 4.0;
    chatInputBackgroundView.layer.borderColor = [Colors chatBarBorder].CGColor;
    

    hairlineView.backgroundColor = [Colors chatBarBorder];
    
    [addButton setImage:[UIImage imageNamed:@"Plus"inColor:[Colors main]] forState:UIControlStateNormal];
    [addButton setImage:[UIImage imageNamed:@"Plus"inColor:[Colors fontNormal]] forState:UIControlStateHighlighted];

    [sendButton setTitleColor:[Colors main] forState:UIControlStateNormal];
    [sendButton setTitleColor:[Colors fontLight] forState:UIControlStateDisabled];
    [sendButton setTitleColor:[Colors fontNormal] forState:UIControlStateHighlighted];
    
    microphoneImage = [UIImage imageNamed:@"Microphone" inColor:[Colors main]];
    if (microphoneShowing) {
        [self.sendButton setImage:microphoneImage forState:UIControlStateNormal];
    }
    
    [quoteView setupColors];
    [oementionsHelper setupColors];
}

- (void)setupMentions:(NSArray *)sortedMembers {
    if (oementionsHelper != nil) {
        [oementionsHelper updateOeObjectsWithSortedContacts:sortedMembers];
    } else {
        if (sortedMembers.count > 0) {
            UIView *mainView = [delegate chatContainterView];
            oementionsHelper = [[OEMentionsHelper alloc] initWithContainerView:self chatInputView:chatInput mainView:mainView sortedContacts:sortedMembers];
            
            addMentionView.frame = CGRectMake(0.0, mainView.frame.origin.y, mainView.frame.size.width, mainView.frame.size.height - self.frame.origin.y);
            oementionsHelper.delegate = self;
        }
    }
}

- (void)updateMentionsFromDraft:(NSString *)draft {
    if (oementionsHelper != nil) {
        [oementionsHelper addMentionsWithDraft:draft];
    } else {
        chatInput.text = draft;
    }
}

- (NSString *)formattedMentionText {
    if (oementionsHelper != nil) {
        return [oementionsHelper formattedMentionText];
    }
    
    return chatInput.text;
}

- (void)refresh {
    [self setupColors];
}

- (void)dealloc {
    if (typing_timer != nil) {
        dispatch_source_cancel(typing_timer);
        typing_timer = nil;
    }
    
    [[ServerConnector sharedServerConnector] removeObserver:self forKeyPath:@"connectionState"];
}

- (void)layoutSubviews {   
    [super layoutSubviews];
    
    CGFloat chatInputLeftPadding = 42.0f;
    CGFloat leftPadding = 0.0f;
    CGFloat rightPadding = 0.0f;
    if ([AppDelegate hasBottomSafeAreaInsets]) {
        UIInterfaceOrientation orientation = [self.delegate interfaceOrientationForChatBar:self];
        if (orientation == UIInterfaceOrientationLandscapeRight) {
            leftPadding += kIphoneXChatBarLandscapePadding;
        } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
            rightPadding += kIphoneXChatBarLandscapePadding;
        }
        
        addButton.frame = CGRectMake(leftPadding, addButton.frame.origin.y, addButton.frame.size.width, addButton.frame.size.height);
        sendButton.frame = CGRectMake(self.frame.size.width - sendButton.frame.size.width - rightPadding, sendButton.frame.origin.y, sendButton.frame.size.width, sendButton.frame.size.height);
    }
    
    CGFloat chatInputXOffset = chatInputLeftPadding + leftPadding;
    CGFloat chatInputYOffset = 0.0f;
    
    if (quoteView.hidden == NO) {
        // Reposition quote view
        CGSize quoteViewAvailableSize = CGSizeMake(self.frame.size.width - chatInputLeftPadding - rightPadding, CGFLOAT_MAX);
        CGSize quoteViewPreferredSize = [quoteView sizeThatFits:quoteViewAvailableSize];
        quoteView.frame = CGRectMake(chatInputLeftPadding, kQuoteViewSpacing, quoteViewAvailableSize.width, quoteViewPreferredSize.height);
        
        chatInputYOffset = quoteView.frame.size.height + kQuoteViewSpacing;
    }
    
    chatInputBackgroundView.frame = CGRectMake(chatInputLeftPadding + leftPadding, kChatInputPadding + chatInputYOffset, self.frame.size.width - chatInputXOffset - sendButtonTextSize.width - additionalWidth - rightPadding, self.frame.size.height - 2*kChatInputPadding - chatInputYOffset);
    chatInput.frame = CGRectMake(0, (chatInputBackgroundView.frame.size.height - chatInput.frame.size.height)/2, chatInputBackgroundView.frame.size.width, chatInput.frame.size.height);
    
    [oementionsHelper updateTextColor];
}

- (void)resizeChatInput {
    [self updateMaxNumberOfLines];

    [chatInput refreshHeightForce:YES];
}

- (void)updateMaxNumberOfLines {
    if (UIInterfaceOrientationIsLandscape([self.delegate interfaceOrientationForChatBar:self])) {
        if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) >= 667) {
            /* iPhone 6 (Plus) */
            if (fontSize >= 28.0)
                chatInput.maxNumberOfLines = 3;
            else
                chatInput.maxNumberOfLines = 4;
        } else {
            if (fontSize >= 28.0)
                chatInput.maxNumberOfLines = 2;
            else
                chatInput.maxNumberOfLines = 3;
        }
    } else {
        if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) >= 667) {
            /* iPhone 6 (Plus) */
            if (fontSize >= 30.0)
                chatInput.maxNumberOfLines = 7;
            else
                chatInput.maxNumberOfLines = 8;
        }
        else if (MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) <= 480) {
            /* iPhone 4s */
            if (fontSize >= 30.0)
                chatInput.maxNumberOfLines = 3;
            else
                chatInput.maxNumberOfLines = 4;
        }
        else {
            if (fontSize >= 30.0)
                chatInput.maxNumberOfLines = 5;
            else
                chatInput.maxNumberOfLines = 6;
        }
    }
}

- (void)updateHeight {
    CGFloat height = chatBarHeight;
    if (quoteView.hidden == NO) {
        height += quoteView.frame.size.height + kQuoteViewSpacing;
    }
    
    if ([self.delegate respondsToSelector:@selector(chatBar:didChangeHeight:)]) {
        [self.delegate chatBar:self didChangeHeight:height];
    }
}

- (void)resetKeyboardType:(BOOL)resetType {
    if (resetType)
        chatInput.internalTextView.keyboardType = UIKeyboardTypeDefault;

    if (chatInput.isFirstResponder) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resettingKeyboard = YES;
            if ([self.delegate respondsToSelector:@selector(canBecomeFirstResponder)]) {
                if (delegate.canBecomeFirstResponder) {
                    [UIView performWithoutAnimation: ^{
                        [chatInput resignFirstResponder];
                        [chatInput becomeFirstResponder];
                    }];
                }
            } else {
                [UIView performWithoutAnimation: ^{
                    [chatInput resignFirstResponder];
                    [chatInput becomeFirstResponder];
                }];
            }
            self.resettingKeyboard = NO;
        });
    }
}

- (void)sendItemAction: (id) sender {
    // Ensure last auto correction is applied
    [chatInput.internalTextView.inputDelegate selectionWillChange:chatInput.internalTextView];
    [chatInput.internalTextView.inputDelegate selectionDidChange:chatInput.internalTextView];
    
    // switch back to default keyboard (in case we're currently using the numeric or emoji keypad)
    [self resetKeyboardType:YES];
    
    [self sendText];
}

- (void)sendText {
    if (oementionsHelper != nil) {
        NSString *formattedMentionText = [oementionsHelper formattedMentionText];
        [oementionsHelper resetMentionsIndexes];
        chatInput.text = formattedMentionText;
    }
    
    if ([self.delegate respondsToSelector:@selector(chatBar:didSendText:)]) {
        NSString *textToSend = chatInput.text;
        if (textToSend.length > 0 && quoteView.hidden == NO) {
            textToSend = [quoteView makeQuoteWithReply:textToSend];
        }
        
        [self.delegate chatBar: self didSendText: textToSend];
    }
}

- (void)addAction:(id)sender {
    [self.delegate chatBarDidPushAddButton:self];
}

- (NSString*)text {
    return chatInput.text;
}

- (void)setText:(NSString *)text {
    chatInput.text = text;
    
    [self resizeChatInput];
}

- (void)setCanSendAudio:(BOOL)newCanSendAudio {
    canSendAudio = newCanSendAudio;
    [self checkEnableSendButton];
}

- (void)clearChatInput {
    @try {
        chatInput.text = @"";
    }
    @catch (NSException *exception) {
        /* Setting the text may trigger an exception ("Range or index out of bounds") if
           dictation is currently in process and the spinner is showing. It seems to be
           an Apple bug, so we simply catch it to avoid crashing */
        DDLogWarn(@"Exception: %@", exception);
    }
    
    // iOS 10 workaround: set font again to fix wonky text field after entering certain emojis
    // (e.g. policewoman, soccer ball and many more), which would cause incorrect height
    // calculations and excessive word spacing.
    chatInput.font = [UIFont systemFontOfSize:fontSize];
    
    [self quoteCancelled];

    [self resizeChatInput];
    if ([UserSettings sharedUserSettings].sendTypingIndicator == true) {
        [self stopTyping];
    }
}

- (void)disableSendButton {
    if (!sendButton.enabled)
        return;
    
    sendButton.enabled = NO;
}

- (void)enableSendButton {
    if (sendButton.enabled)
        return;
    
    sendButton.enabled = YES;
}

- (void)chatBarTapped {
    if ([self.delegate respondsToSelector:@selector(canBecomeFirstResponder)]) {
        if (delegate.canBecomeFirstResponder) {
            [chatInput becomeFirstResponder];
        }
    } else {
        [chatInput becomeFirstResponder];
    }
    
    if ([self.delegate respondsToSelector:@selector(chatBarTapped:)]) {
        [delegate chatBarTapped:self];
    }
}

- (void)chatBarPanned:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    if (translation.y <= -10) {
        if ([self.delegate respondsToSelector:@selector(canBecomeFirstResponder)]) {
            if (delegate.canBecomeFirstResponder) {
                [chatInput becomeFirstResponder];
            }
        } else {
            [chatInput becomeFirstResponder];
        }
    }
}

- (BOOL)becomeFirstResponder {
    if ([self.delegate respondsToSelector:@selector(canBecomeFirstResponder)]) {
        if (delegate.canBecomeFirstResponder) {
            return [chatInput becomeFirstResponder];
        } else {
            return NO;
        }
    } else {
        return [chatInput becomeFirstResponder];
    }
}

- (BOOL)resignFirstResponder {
    DDLogVerbose(@"ChatBar resignFirstResponder");
    BOOL res = [chatInput resignFirstResponder];
    if ([UserSettings sharedUserSettings].sendTypingIndicator == true) {
        [self stopTyping];
    }
    return res;
}

- (BOOL)isFirstResponder {
    return [chatInput isFirstResponder];
}

- (void)checkEnableSendButton {
    /* replace send button with microphone if there is no text */
    if (chatInput.text.length > 0) {
        if (microphoneShowing) {
            [self.sendButton setTitle:sendButtonText forState:UIControlStateNormal];
            [self.sendButton setImage:nil forState:UIControlStateNormal];
            self.sendButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"send"];
            microphoneShowing = NO;
        }
    } else {
        if (self.canSendAudio) {
            if (!microphoneShowing) {
                [self.sendButton setTitle:nil forState:UIControlStateNormal];
                [self.sendButton setImage:microphoneImage forState:UIControlStateNormal];
                self.sendButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"voice message"];
                microphoneShowing = YES;
            }
        }
    }
    
    /* only enable send button if there is some text and we're currently connected */
    NSString *trimmedText = [chatInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedText.length > 0) {
        if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
            [self enableSendButton];
        } else {
            [self disableSendButton];
        }
    } else {
        if (self.canSendAudio) {
            [self enableSendButton];
        } else {
            [self disableSendButton];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [ServerConnector sharedServerConnector] && [keyPath isEqualToString:@"connectionState"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self checkEnableSendButton];
        });
    }
}
    
#pragma mark OEMentionsHelperDelegate

- (void)textView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height {
    [self growingTextView:growingTextView willChangeHeight:height];
}

- (BOOL)textView:(HPGrowingTextView *)growingTextView shouldChangeTextIn:(NSRange)range replacementText:(NSString *)text {
    return [self growingTextView:growingTextView shouldChangeTextInRange:range replacementText:text];
}

- (void)textViewDidChange:(HPGrowingTextView *)growingTextView {
    [self growingTextViewDidChange:growingTextView];
    if (growingTextView.text.length == 0 && updateTextColorForEmptyString == false) {
        updateTextColorForEmptyString = true;
        growingTextView.text = @" ";
        [oementionsHelper updateTextColor];
        growingTextView.text = @"";
        updateTextColorForEmptyString = false;
    }
}

- (void)mentionSelectedWithId:(NSInteger)id name:(NSString *)name {
}

#pragma mark HPGrowingTextViewDelegate

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height {
    chatBarHeight = height + 5.0f;
    if (chatBarHeight < minChatBarHeight) {
        chatBarHeight = minChatBarHeight;
    }
    
    if (height < growingTextView.frame.size.height) {
        // workaround for the weird HPGrowingTextView on iOS8
        // force height update after resize animation to prevent contentOffset issue
        // when more than maxLines were entered and input field is shrinked again
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            [chatInput setNeedsLayout];
            [chatInput refreshHeight];
        });
    }
    
    [self updateHeight];
}

- (BOOL)growingTextView:(HPGrowingTextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text hasPrefix:@"tel:"]) {
        NSString *newText = [text stringByRemovingPercentEncoding];
        newText = [newText substringFromIndex:4];
        self.text = [self.text stringByReplacingCharactersInRange:range withString:newText];
        return NO;
    }
    
    if ([UserSettings sharedUserSettings].sendTypingIndicator == true) {
        dispatch_source_set_timer(typing_timer, dispatch_time(DISPATCH_TIME_NOW, kTypingTimeout * NSEC_PER_SEC),
                                  kTypingTimeout * NSEC_PER_SEC, NSEC_PER_SEC);
        
        if (!typing) {
            typing = YES;
            [delegate chatBarWillStartTyping:self];
            dispatch_resume(typing_timer);
        }
    }
    
    if ([text isEqualToString:@"\n"] && [UserSettings sharedUserSettings].returnToSend) {
        if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendText];
            });
        }
        return NO;
    }
    return YES;
}

- (void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView {
    [self checkEnableSendButton];
}

- (void)stopTyping {
    if ([UserSettings sharedUserSettings].sendTypingIndicator == true) {
        DDLogVerbose(@"stopTyping");
        if (typing) {
            typing = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate chatBarDidStopTyping:self];
            });
            dispatch_suspend(typing_timer);
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == chatBarTapRecognizer && [touch.view isKindOfClass:[UIControl class]]) {
        // we touched a button, slider, or other UIControl
        return NO; // ignore the touch
    }
    return YES; // handle the touch
}

#pragma mark - Paste image handler

- (void)handlePasteItem {
    // Allow pasting all items in iOS 11 or newer because we can reuse the item handling from the share extension
    if (@available(iOS 11.0, *)) {
        // Handle memoji separately and send them immediately
        NSString *memojiMimeType = @"com.apple.png-sticker";
        bool memoji = [[UIPasteboard generalPasteboard] containsPasteboardTypes:@[memojiMimeType]] && [UIPasteboard generalPasteboard].numberOfItems == 1;
        if (!memoji) {
            if ([UIPasteboard generalPasteboard].itemProviders != nil) {
                [delegate chatBar:self didPasteItems:[UIPasteboard generalPasteboard].itemProviders];
                return;
            }
        } else {
            NSData *imageData = [[UIPasteboard generalPasteboard] dataForPasteboardType:(__bridge NSString *)kUTTypeImage];
            [delegate chatBar:self didSendImageData:imageData];
            return;
        }
    }
    // Handle pasted images on older versions or if no itemProvider was available
    [self handlePastedImage];
}

- (void)handlePastedImage {
    NSData *imageData = [[UIPasteboard generalPasteboard] dataForPasteboardType:(__bridge NSString *)kUTTypeImage];
    if (imageData != nil) {
        [delegate chatBar:self didPasteImageData:imageData];
    } else {
        [delegate chatBar:self didPasteImageData:UIImageJPEGRepresentation([UIPasteboard generalPasteboard].image, 1.0)];
    }
}

#pragma mark - Quoting

- (void)addQuotedMessage:(BaseMessage *)message {
    [quoteView setQuotedMessage:message];
    
    [self showQuotedMessage];
}

- (void)addQuotedText:(NSString*)quotedText quotedContact:(Contact*)contact {
    [quoteView setQuotedText:quotedText quotedContact:contact];
    
    [self showQuotedMessage];
}

- (void)showQuotedMessage {
    CGSize quoteViewAvailableSize = CGSizeMake(self.frame.size.width - 42, CGFLOAT_MAX);
    CGSize quoteViewPreferredSize = [quoteView sizeThatFits:quoteViewAvailableSize];
    quoteView.frame = CGRectMake(42, kQuoteViewSpacing, quoteViewAvailableSize.width, quoteViewPreferredSize.height);
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.5];
    quoteView.hidden = NO;
    [self updateHeight];
    [UIView commitAnimations];
    
    if ([self.delegate respondsToSelector:@selector(chatBarDidAddQuote)]) {
        [self.delegate chatBarDidAddQuote];
    }
    
    if ([self.delegate respondsToSelector:@selector(canBecomeFirstResponder)]) {
        if (delegate.canBecomeFirstResponder) {
            [chatInput becomeFirstResponder];
        }
    } else {
        [chatInput becomeFirstResponder];
    }
}

- (void)quoteCancelled {
    if (quoteView.hidden)
        return;
    
    quoteView.hidden = YES;
    [self updateHeight];
}

@end
