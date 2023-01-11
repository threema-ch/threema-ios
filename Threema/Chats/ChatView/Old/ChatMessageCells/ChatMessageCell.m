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

#import "ChatMessageCell.h"
#import "ChatDefines.h"
#import "TextMessage.h"
#import "Conversation.h"
#import "Contact.h"
#import "MessageSender.h"
#import "Old_ChatViewController.h"
#import "CustomResponderTextView.h"
#import "ThreemaUtilityObjC.h"
#import "UserSettings.h"
#import "AvatarMaker.h"
#import "ActivityUtil.h"
#import "UIImage+ColoredImage.h"
#import "QBPopupMenu.h"
#import "RectUtil.h"
#import "BaseMessage+OLD_Accessibility.h"
#import "BundleUtil.h"
#import "Threema-Swift.h"
#import "ContactGroupPickerViewController.h"
#import "ChatTextMessageCell.h"
#import "Old_FileMessageSender.h"

#define DATE_LABEL_BG_COLOR [Colors.backgroundView colorWithAlphaComponent:0.8]
#define REQUIRED_MENU_HEIGHT 50.0
#define EMOJI_FONT_SIZE_FACTOR 3
#define EMOJI_MAX_FONT_SIZE 50
#define QUOTE_FONT_SIZE_FACTOR 0.8
#define METADATA_STACK_SPACE 3.0

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface ChatMessageCell () <QBPopupMenuDelegate, ModalNavigationControllerDelegate, ContactGroupPickerDelegate, MGSwipeTableCellDelegate>

@property QBPopupMenu *popupMenu;

@end

@implementation ChatMessageCell {
    UIImageView *msgBackground;
    UIStackView *metaDataStackView;
    UIView *metaDataStackViewBackgroundView;
    UIStackView *ackStackView;
    UIStackView *declineStackView;
    UIImageView *statusImage;
    UIImageView *groupAckImage;
    UILabel *groupAckCountLabel;
    UIImageView *groupDeclineImage;
    UILabel *groupDeclineCountLabel;
    
    UILabel *dateLabel;
    UIImageView *typingIndicator;
    UIButton *groupSenderImageButton;
    UIImageView *quoteSlideIconImage;
    BOOL transparent;
    CGSize bubbleSize;
    UITapGestureRecognizer *dtgr;
    UIPanGestureRecognizer *pan;
    UIImpactFeedbackGenerator *gen;
    BaseMessage *_messageToQuote;
}

@synthesize message;
@synthesize typing;
@synthesize chatVc;
@synthesize statusImage;
@synthesize msgBackground;
@synthesize dtgr;

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {
    return 0;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)_transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {        
        transparent = _transparent;
        
        self.backgroundColor = transparent ? [UIColor clearColor] : Colors.backgroundGroupedViewController; // clearColor slows performance
        
        // Create message background image view
        msgBackground = [[UIImageView alloc] init];
        msgBackground.clearsContextBeforeDrawing = NO;
        msgBackground.backgroundColor = transparent ? [UIColor clearColor] : Colors.backgroundGroupedViewController; // clearColor slows performance
        [self.contentView addSubview:msgBackground];
        
        // Status image
        statusImage = [[UIImageView alloc] init];
        statusImage.contentMode = UIViewContentModeScaleAspectFit;
        
        // Group ack images image
        groupAckImage = [[UIImageView alloc] init];
        groupAckImage.contentMode = UIViewContentModeScaleAspectFit;
        groupAckImage.image = [[UIImage systemImageNamed:@"hand.thumbsup"] imageWithTintColor:Colors.thumbUp renderingMode:UIImageRenderingModeAlwaysOriginal];
        groupDeclineImage = [[UIImageView alloc] init];
        groupDeclineImage.contentMode = UIViewContentModeScaleAspectFit;
        groupDeclineImage.image = [[UIImage systemImageNamed:@"hand.thumbsdown"] imageWithTintColor:Colors.thumbDown renderingMode:UIImageRenderingModeAlwaysOriginal];
        
        groupAckCountLabel = [[UILabel alloc] init];
        groupAckCountLabel.backgroundColor = [UIColor clearColor];
        groupAckCountLabel.font = [UIFont systemFontOfSize:MAX(11.0f, MIN(14.0, roundf([UserSettings sharedUserSettings].chatFontSize * 11.0 / 16.0)))];
        groupAckCountLabel.numberOfLines = 1;
        
        groupDeclineCountLabel = [[UILabel alloc] init];
        groupDeclineCountLabel.backgroundColor = [UIColor clearColor];
        groupDeclineCountLabel.font = [UIFont systemFontOfSize:MAX(11.0f, MIN(14.0, roundf([UserSettings sharedUserSettings].chatFontSize * 11.0 / 16.0)))];
        groupDeclineCountLabel.numberOfLines = 1;
        
        ackStackView = [[UIStackView alloc] initWithArrangedSubviews:@[groupAckImage, groupAckCountLabel]];
        ackStackView.axis = UILayoutConstraintAxisHorizontal;
        ackStackView.distribution = UIStackViewDistributionEqualSpacing;
        ackStackView.alignment = UIStackViewAlignmentCenter;
        ackStackView.spacing = 1.0;
        
        declineStackView = [[UIStackView alloc] initWithArrangedSubviews:@[groupDeclineImage, groupDeclineCountLabel]];
        declineStackView.axis = UILayoutConstraintAxisHorizontal;
        declineStackView.distribution = UIStackViewDistributionEqualSpacing;
        declineStackView.alignment = UIStackViewAlignmentCenter;
        declineStackView.spacing = 1.0;
        
        // Date label
        dateLabel = [[UILabel alloc] init];
        dateLabel.backgroundColor = [UIColor clearColor];
        dateLabel.font = [UIFont systemFontOfSize:MAX(11.0f, MIN(14.0, roundf([UserSettings sharedUserSettings].chatFontSize * 11.0 / 16.0)))];
        dateLabel.numberOfLines = 2;
        
        UIImage *quoteImage = [[BundleUtil imageNamed:@"Quote"] imageWithTint:Colors.text];
        quoteSlideIconImage = [[UIImageView alloc] initWithImage:quoteImage];
        quoteSlideIconImage.alpha = 0.0;
        [self.contentView addSubview:quoteSlideIconImage];
        
        gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        
        // Typing indicator
        typingIndicator = [[UIImageView alloc] init];
        typingIndicator.contentMode = UIViewContentModeScaleAspectFit;
        
        metaDataStackView = [[UIStackView alloc] init];
        metaDataStackView.axis = UILayoutConstraintAxisHorizontal;
        metaDataStackView.distribution = UIStackViewDistributionEqualSpacing;
        metaDataStackView.alignment = UIStackViewAlignmentCenter;
        metaDataStackView.spacing = METADATA_STACK_SPACE;
        [self.contentView addSubview:metaDataStackView];
        
        metaDataStackViewBackgroundView = [UIView new];
        metaDataStackViewBackgroundView.backgroundColor = [UIColor clearColor];
        metaDataStackViewBackgroundView.layer.cornerRadius = 5;
        metaDataStackViewBackgroundView.layer.masksToBounds = true;
        [self.contentView insertSubview:metaDataStackViewBackgroundView belowSubview:metaDataStackView];
        
        pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGestureCellAction:)];
        pan.delegate = self;
        [self.contentView addGestureRecognizer:pan];
        
        [self setupResendButton];

        [self updateColors];
    }
    
    return self;
}

- (void)updateColors {
    groupAckCountLabel.textColor = Colors.thumbUp;
    groupDeclineCountLabel.textColor = Colors.thumbDown;
    
    typingIndicator.image = [self getStatusImageNamed:@"Typing" withCustomColor:nil];
    
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = [Colors.primary colorWithAlphaComponent:0.1];
    self.selectedBackgroundView = v;
    
    quoteSlideIconImage.image = [[BundleUtil imageNamed:@"Quote"] imageWithTint:Colors.text];
    
    if ([UserSettings sharedUserSettings].wallpaper) {
        metaDataStackViewBackgroundView.backgroundColor = DATE_LABEL_BG_COLOR;
        dateLabel.textColor = Colors.textChatDateCustomImage;
    } else {
        metaDataStackViewBackgroundView.backgroundColor = [UIColor clearColor];
        dateLabel.textColor = Colors.textLight;
    }
    
    [self setNeedsLayout];
}

- (void)dealloc {
    @try {
        [message removeObserver:self forKeyPath:@"read"];
        [message removeObserver:self forKeyPath:@"delivered"];
        [message removeObserver:self forKeyPath:@"sent"];
        [message removeObserver:self forKeyPath:@"userack"];
        [message removeObserver:self forKeyPath:@"userackDate"];
        [message removeObserver:self forKeyPath:@"groupDeliveryReceipts"];
    }
    @catch(NSException *e) {}
}

- (void)setMessage:(BaseMessage *)newMessage {
    @try {
        [message removeObserver:self forKeyPath:@"read"];
        [message removeObserver:self forKeyPath:@"delivered"];
        [message removeObserver:self forKeyPath:@"sent"];
        [message removeObserver:self forKeyPath:@"userack"];
        [message removeObserver:self forKeyPath:@"userackDate"];
        [message removeObserver:self forKeyPath:@"groupDeliveryReceipts"];
    }
    @catch(NSException *e) {}
    
    message = newMessage;
    
    [self updateColors];

    [self setBubbleHighlighted:NO];
    
    if (message.isOwn.boolValue) { // right bubble
        msgBackground.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else { // left bubble
        msgBackground.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    [self configureMetaStackView];
    
    [self updateStatusImage];
    [self updateDateLabel];
    [self updateTypingIndicator];
    [self updateGroupSenderImage];
    [self updateResendButton];
    
    [self setNeedsLayout];
    
    if (!self.chatVc.isOpenWithForceTouch) {
        [message addObserver:self forKeyPath:@"read" options:0 context:nil];
        [message addObserver:self forKeyPath:@"delivered" options:0 context:nil];
        [message addObserver:self forKeyPath:@"sent" options:0 context:nil];
        [message addObserver:self forKeyPath:@"userack" options:0 context:nil];
        [message addObserver:self forKeyPath:@"userackDate" options:0 context:nil];
        [message addObserver:self forKeyPath:@"groupDeliveryReceipts" options:0 context:nil];
    }
}

- (void)setBubbleContentSize:(CGSize)size {
    CGFloat bgWidthMargin = 30.0f;
    CGFloat bgHeightMargin = 16.0f;
    
    bubbleSize = CGSizeMake(size.width+bgWidthMargin, size.height+bgHeightMargin);
}

- (void)setBubbleSize:(CGSize)size {
    bubbleSize = size;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (_popupMenu.isVisible) {
        [_popupMenu dismissAnimated:YES];
    }
    
    CGFloat bgTopOffset = 1.0f;
    CGFloat bgSideMargin = 6.0f;
    
    CGSize dateLabelSize = [dateLabel sizeThatFits:CGSizeMake(120, 28)];
    CGFloat dateLabelWidth = ceilf(dateLabelSize.width);
    
    
    CGFloat metaDataStackViewWidth = 0.0;
    
    if (self.message.conversation.isGroup) {
        if ([self.message old_groupReactionsCountOf:DeliveryReceiptTypeAcknowledged] > 0) {
            ackStackView.hidden = NO;
            metaDataStackViewWidth += 25.0;
            metaDataStackViewWidth += groupAckCountLabel.frame.size.width + 2.0;
        } else {
            ackStackView.hidden = YES;
        }
        
        if ([self.message old_groupReactionsCountOf:DeliveryReceiptTypeDeclined] > 0) {
            if (metaDataStackViewWidth > 0.0) {
                metaDataStackViewWidth += METADATA_STACK_SPACE;
            }
            declineStackView.hidden = NO;
            metaDataStackViewWidth += 25.0;
            metaDataStackViewWidth += groupDeclineCountLabel.frame.size.width + 2.0;
        } else {
            declineStackView.hidden = YES;
        }
        if (!dateLabel.hidden) {
            if (metaDataStackViewWidth > 0.0) {
                metaDataStackViewWidth += METADATA_STACK_SPACE;
            }
            metaDataStackViewWidth += dateLabelWidth;
        }
    } else {
        if (!statusImage.hidden) {
            metaDataStackViewWidth += 25.0;
        }
        if (!dateLabel.hidden) {
            if (metaDataStackViewWidth > 0.0) {
                metaDataStackViewWidth += METADATA_STACK_SPACE;
            }
            metaDataStackViewWidth += dateLabelWidth;
        }
        if (!typingIndicator.hidden) {
            if (metaDataStackViewWidth > 0.0) {
                metaDataStackViewWidth += METADATA_STACK_SPACE;
            }
            metaDataStackViewWidth += 25.0;
        }
    }
        
    if (message.isOwn.boolValue) { // right bubble
        msgBackground.frame = CGRectMake(self.contentView.frame.size.width-bubbleSize.width-bgSideMargin,
                                         bgTopOffset, bubbleSize.width, bubbleSize.height);
    
        CGFloat bubbleMaxY = CGRectGetMaxY(msgBackground.frame);

        metaDataStackView.frame = CGRectMake(msgBackground.frame.origin.x - metaDataStackViewWidth - 4, bubbleMaxY - 27, metaDataStackViewWidth, 18);
        metaDataStackViewBackgroundView.frame = CGRectMake(metaDataStackView.frame.origin.x - 2.0, metaDataStackView.frame.origin.y, metaDataStackView.frame.size.width + 4.0, metaDataStackView.frame.size.height);
        
        // Add Retry Button for all Cells
        if (![self isKindOfClass: [ChatBlobMessageCell class]]) {
            [metaDataStackView setHidden:false];
            
            CGFloat minX = metaDataStackView.frame.origin.x;
            CGFloat maxX = metaDataStackView.frame.origin.x + metaDataStackView.frame.size.width;
            
            CGFloat minY = metaDataStackView.frame.origin.y;
            CGFloat maxY = metaDataStackView.frame.origin.y + metaDataStackView.frame.size.height;
            
            CGFloat midY = bgTopOffset + (bubbleSize.height / 2);
            
            [_resendButton sizeToFit];
            
            CGFloat width = _resendButton.frame.size.width;
            CGFloat height = _resendButton.frame.size.height;
            
            CGFloat padding = 5;
            
            CGFloat originX = minX - width - padding;
            
            if (!_resendButton.hidden) {
                // If we go over the left edge, reset x coordinate of the origin and add some padding
                if (minX - width - padding < 0) {
                    originX = padding;
                }
                
                // If we go over the message bubble on the right side, we allow us to take up two lines
                // and update our width and height to the new value
                if (originX + width > CGRectGetMinX(msgBackground.frame)) {
                    [_resendButton.titleLabel setNumberOfLines:2];
                    
                    [_resendButton sizeToFit];
                    
                    width = _resendButton.frame.size.width;
                    height = _resendButton.frame.size.height;
                }
                
                // If we still go over the message bubble on the right side, artificially restrict our width
                // forcing us to cut text if necessary
                if (originX + width > CGRectGetMinX(msgBackground.frame)) {
                    width = CGRectGetMinX(self.msgBackground.frame) - (2 * padding);
                }
                
                // If go over the metaDataStackView we just hide it as all info will still be available in the message details.
                if (originX + width > CGRectGetMinX(metaDataStackView.frame) && (metaDataStackView.frame.origin.y < (midY) && (metaDataStackView.frame.origin.y + metaDataStackView.frame.size.height > (midY)))) {
                    [metaDataStackView setHidden:true];
                }
            }
             
            CGRect newFrame = CGRectMake(originX, midY - (height / 2), width, maxY - minY);
            _resendButton.frame = newFrame;
        }
        
    } else { // left bubble
        msgBackground.frame = CGRectMake(bgSideMargin + self.contentLeftOffset, bgTopOffset, bubbleSize.width, bubbleSize.height);

        CGFloat bubbleMaxY = CGRectGetMaxY(msgBackground.frame);

        groupSenderImageButton.frame = CGRectMake(8, bubbleMaxY - 31, 27, 27);
        
        CGFloat xOffset = msgBackground.frame.origin.x + msgBackground.frame.size.width + 4;
        metaDataStackView.frame = CGRectMake(xOffset, bubbleMaxY - 27, metaDataStackViewWidth, 18);
        metaDataStackViewBackgroundView.frame = CGRectMake(metaDataStackView.frame.origin.x - 2.0, metaDataStackView.frame.origin.y, metaDataStackView.frame.size.width + 4.0, metaDataStackView.frame.size.height);
    }
}

- (void)setupResendButton {
    _resendButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _resendButton.clearsContextBeforeDrawing = NO;
    [_resendButton setTitle:[BundleUtil localizedStringForKey:@"try_again"] forState:UIControlStateNormal];

    _resendButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    _resendButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_resendButton addTarget:self action:@selector(resendButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    _resendButton.hidden = YES;
    
    [self.contentView addSubview:_resendButton];
}

- (void)updateResendButton {
    if (self.message.isOwn.boolValue && (self.message.sendFailed.boolValue)) {
        _resendButton.hidden = NO;
    } else {
        _resendButton.hidden = YES;
        [metaDataStackView setHidden:NO];
    }
    
    [self layoutSubviews];
}

- (void)resendButtonTapped:(id)sender {
    [self resendMessage:nil];
}

- (void)updateDateLabel {
    NSDate *date = [message displayDate];

    if (date != nil) {
        if (![ThreemaUtilityObjC isSameDayWithDate1:date date2:message.date]) {
            dateLabel.text = [DateFormatter shortStyleDateTime:date];
        } else {
            dateLabel.text = [DateFormatter shortStyleTimeNoDate:date];
        }
    } else {
        dateLabel.text = [DateFormatter shortStyleTimeNoDate:date];
    }
        
    dateLabel.hidden = NO;
    
    /* received message - show timestamp only if setting is enabled */
    if (!message.isOwn.boolValue) {
        dateLabel.hidden = ([UserSettings sharedUserSettings].showReceivedTimestamps == NO) && ([UserSettings sharedUserSettings].newChatViewActive == NO);
    }
    
    // Reset metaDataStackView hiding
    [metaDataStackView setHidden:NO];
}

- (void)updateTypingIndicator {    
    if (typing) {
        typingIndicator.hidden = NO;
        [self setNeedsLayout];
    } else {
        typingIndicator.hidden = YES;
        [self setNeedsLayout];
    }
}

- (void)updateGroupDeliveryReceipts {
    NSInteger ackCount = [message old_groupReactionsCountOf:DeliveryReceiptTypeAcknowledged];
    NSInteger declineCount = [message old_groupReactionsCountOf:DeliveryReceiptTypeDeclined];
    
    groupAckCountLabel.text = [NSString stringWithFormat:@"%li", ackCount];
    groupDeclineCountLabel.text = [NSString stringWithFormat:@"%li", declineCount];
    groupAckImage.image = [[UIImage systemImageNamed:@"hand.thumbsup"] imageWithTintColor:Colors.thumbUp renderingMode:UIImageRenderingModeAlwaysOriginal];
    groupDeclineImage.image = [[UIImage systemImageNamed:@"hand.thumbsdown"] imageWithTintColor:Colors.thumbDown renderingMode:UIImageRenderingModeAlwaysOriginal];
    
    GroupDeliveryReceipt *myReaction = [message old_reactionForMyIdentity];
    if (myReaction != nil) {
        if (myReaction.deliveryReceiptType == DeliveryReceiptTypeAcknowledged) {
            groupAckImage.image = [[UIImage systemImageNamed:@"hand.thumbsup.fill"] imageWithTintColor:Colors.thumbUp renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        else {
            groupDeclineImage.image = [[UIImage systemImageNamed:@"hand.thumbsdown.fill"] imageWithTintColor:Colors.thumbDown renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    }
}

- (UIImage*)bubbleImageWithHighlight:(BOOL)bubbleHighlight {
    if (self.shouldHideBubbleBackground) {
        return nil;
    }
    
    if (message.isOwn.boolValue) {
        NSString *name = @"ChatBubbleSentMask";
        if (bubbleHighlight) {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleSentSelected] stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        } else {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleSent] stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        }
    } else {
        NSString *name = @"ChatBubbleReceivedMask";
        if (bubbleHighlight) {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleReceivedSelected] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        } else {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleReceived] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        }
    }
}

- (void)configureMetaStackView {
    for (UIView *view in metaDataStackView.subviews) {
        [view removeFromSuperview];
    }
    
    if (message.conversation.isGroup) {
        if (message.isOwn.boolValue) { // right bubble
            [metaDataStackView addArrangedSubview:dateLabel];
            [metaDataStackView addArrangedSubview:ackStackView];
            [metaDataStackView addArrangedSubview:declineStackView];
        } else { // left bubble
            [metaDataStackView addArrangedSubview:ackStackView];
            [metaDataStackView addArrangedSubview:declineStackView];
            [metaDataStackView addArrangedSubview:dateLabel];
        }
    }
    else {
        if (message.isOwn.boolValue) { // right bubble
            [metaDataStackView addArrangedSubview:typingIndicator];
            [metaDataStackView addArrangedSubview:dateLabel];
            [metaDataStackView addArrangedSubview:statusImage];
        } else { // left bubble
            [metaDataStackView addArrangedSubview:statusImage];
            [metaDataStackView addArrangedSubview:dateLabel];
            [metaDataStackView addArrangedSubview:typingIndicator];
        }
    }
}

- (void)updateStatusImage {
    NSString *iconName;
    UIColor *color = nil;
    
    if (message.conversation.groupId != nil || message.conversation.contact.isGatewayId) {
        /* group messages & gateway IDs don't have delivered/read status */
        if (message.isOwn.boolValue && message.sent.boolValue == NO) {
            iconName = @"MessageStatus_sending";
        }
    } else {
        if (message.isOwn.boolValue) {
            if (message.read.boolValue) {
                iconName = @"MessageStatus_read";
            } else if (message.delivered.boolValue) {
                iconName = @"MessageStatus_delivered";
            } else if (message.sendFailed.boolValue) {
                iconName = @"MessageStatus_sendfailed";
            } else if (message.sent.boolValue) {
                iconName = @"MessageStatus_sent";
            } else {
                iconName = @"MessageStatus_sending";
            }
        }
    }
    
    CGFloat alpha = 0.8;
    
    if (message.conversation.groupId != nil) {
        [self updateGroupDeliveryReceipts];
    }
    else {
        ackStackView.hidden = YES;
        declineStackView.hidden = YES;
        if (message.userackDate != nil) {
            if (message.userack.boolValue) {
                iconName = @"hand.thumbsup.fill";
                color = Colors.thumbUp;
            } else if (message.userack.boolValue == NO) {
                iconName = @"hand.thumbsdown.fill";
                color = Colors.thumbDown;
            }
            alpha = 1.0;
        }
    }
    
    
    if (iconName) {
        if ([iconName isEqualToString:@"hand.thumbsup.fill"] || [iconName isEqualToString:@"hand.thumbsdown.fill"]) {
            statusImage.image = [[UIImage systemImageNamed:iconName] imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        else if ([iconName isEqualToString:@"MessageStatus_sendfailed"]) {
            statusImage.image = [UIImage imageNamed:@"MessageStatus_sendfailed"];
        }
        else {
            statusImage.image = [self getStatusImageNamed:iconName withCustomColor:color];
        }
        
        statusImage.alpha = alpha;
        statusImage.hidden = NO;
    } else {
        statusImage.hidden = YES;
    }
}

- (UIImage *)getStatusImageNamed:(NSString *)imageName withCustomColor:(UIColor *)color {
    if (color == nil && [UserSettings sharedUserSettings].wallpaper == nil) {
        color = Colors.textLight;
    }
    
    if (color) {
        return [[UIImage imageNamed:imageName inColor:color] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    } else {
        NSString *glowImageName = [NSString stringWithFormat:@"%@_glow", imageName];
        return [UIImage imageNamed:glowImageName];
    }
}

- (void)updateGroupSenderImage {
    if (message.sender == nil || message.isOwn.boolValue) {
        /* not an outgoing group message */
        groupSenderImageButton.hidden = YES;
        [groupSenderImageButton setImage:nil forState:UIControlStateNormal];
        return;
    }
    
    if (groupSenderImageButton == nil) {
        groupSenderImageButton = [[UIButton alloc] init];
        [groupSenderImageButton addTarget:self action:@selector(handleTappedAvatar) forControlEvents:UIControlEventTouchUpInside];
        
        [self.contentView addSubview:groupSenderImageButton];
    }
    
    [groupSenderImageButton setImage:[BundleUtil imageNamed:@"Unknown"] forState:UIControlStateNormal];
    [[AvatarMaker sharedAvatarMaker] avatarForContact:message.sender size:27.0f masked:YES onCompletion:^(UIImage *avatarImage, NSString *identity) {
        if ([message.sender.identity isEqualToString:identity]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [groupSenderImageButton setImage:avatarImage forState:UIControlStateNormal];
            });
        }
    }];
    
    groupSenderImageButton.hidden = NO;
}

- (void)handleTappedAvatar {
    [NSNotificationCenter.defaultCenter postNotificationName:kNotificationShowConversation object:nil userInfo: @{kKeyContact: message.sender}];
}

- (void)handleDoubleTap:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && self.chatVc.chatContent.editing == NO) {
        [self showMenu];
    }
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan && self.chatVc.chatContent.editing == NO) {
        [self showMenu];
    }
}

- (void)showMenu {
    
    NSMutableArray *menuItems = [NSMutableArray array];
    
    if ([self canPerformAction:@selector(userackMessage:) withSender:nil]) {
        NSString *iconName = @"hand.thumbsup";
        GroupDeliveryReceipt *dr = [message old_reactionForMyIdentity];
        if (dr != nil) {
            if (dr.deliveryReceiptType == DeliveryReceiptTypeAcknowledged) {
                iconName = @"hand.thumbsup.fill";
            }
        }
        UIImage *ackImage = [[UIImage systemImageNamed:iconName] imageWithTintColor:Colors.thumbUp renderingMode:UIImageRenderingModeAlwaysOriginal];
        
        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:ackImage target:self action:@selector(userackMessage:)];
        item.accessibilityLabel = [BundleUtil localizedStringForKey:@"acknowledge"];
        [menuItems addObject:item];
    }
    
    if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
        NSString *iconName = @"hand.thumbsdown";
        GroupDeliveryReceipt *dr = [message old_reactionForMyIdentity];
        if (dr != nil) {
            if (dr.deliveryReceiptType == DeliveryReceiptTypeDeclined) {
                iconName = @"hand.thumbsdown.fill";
            }
        }
        UIImage *declineImage = [[UIImage systemImageNamed:iconName] imageWithTintColor:Colors.thumbDown renderingMode:UIImageRenderingModeAlwaysOriginal];

        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:declineImage target:self action:@selector(userdeclineMessage:)];
        item.accessibilityLabel = [BundleUtil localizedStringForKey:@"decline"];
        [menuItems addObject:item];
    }
    
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIImage *quoteImage = [UIImage imageNamed:@"Quote" inColor:[UIColor whiteColor]];
        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:quoteImage target:self action:@selector(quoteMessage:)];
        item.accessibilityLabel = [BundleUtil localizedStringForKey:@"quote"];
        [menuItems addObject:item];
    }
    
    if (UIAccessibilityIsSpeakSelectionEnabled()) {
        if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
            [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"speak"] target:self action:@selector(speakMessage:)]];
        }
    }
    
    if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"copy"] target:self action:@selector(copyMessage:)]];
    }
    
    if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"share"] target:self action:@selector(shareMessage:)]];
    }
    
    if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"try_again"] target:self action:@selector(resendMessage:)]];
    }
    
    if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"details"] target:self action:@selector(detailsMessage:)]];
    }
    
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"delete"] target:self action:@selector(deleteMessage:)]];
    }
    
    _popupMenu = [[QBPopupMenu alloc] initWithItems:menuItems];
    _popupMenu.delegate = self;
    _popupMenu.color = Colors.backgroundPopupMenu;
    _popupMenu.highlightedColor = Colors.popupMenuHighlight;
    _popupMenu.nextPageAccessibilityLabel = [BundleUtil localizedStringForKey:@"showNext"];
    _popupMenu.previousPageAccessibilityLabel = [BundleUtil localizedStringForKey:@"showPrevious"];

    CGRect targetRect = [self targetRectForMenuPopup];
    [_popupMenu showInView:chatVc.view targetRect:targetRect animated:YES];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _popupMenu);
    
    /* add view to add a quit for voice over */
    UIView *quitView = [[UIView alloc] initWithFrame:chatVc.view.subviews.lastObject.frame];
    quitView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    quitView.alpha = 1;
    quitView.isAccessibilityElement = YES;
    quitView.accessibilityLabel = [BundleUtil localizedStringForKey:@"quit"];
    quitView.accessibilityActivationPoint = CGPointMake(0.0, 0.0);
    quitView.backgroundColor = [UIColor clearColor];
    quitView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    quitView.userInteractionEnabled = NO;
    [chatVc.view.subviews.lastObject insertSubview:quitView belowSubview:_popupMenu];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapQuitPopoverMenu:)];
    [quitView addGestureRecognizer: tapGesture];
}

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
     if (self.editing) {
         return nil;
     }
    UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
        return nil;
    } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        NSMutableArray *menuItems = [NSMutableArray array];
        NSMutableArray *deleteItems = [NSMutableArray array];
        if ([self canPerformAction:@selector(userackMessage:) withSender:nil]) {
            NSString *iconName = @"hand.thumbsup";
            GroupDeliveryReceipt *dr = [message old_reactionForMyIdentity];
            if (dr != nil) {
                if (dr.deliveryReceiptType == DeliveryReceiptTypeAcknowledged) {
                    iconName = @"hand.thumbsup.fill";
                }
            }
            UIImage *ackImage = [[UIImage systemImageNamed:iconName] imageWithTintColor:Colors.thumbUp renderingMode:UIImageRenderingModeAlwaysOriginal];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"acknowledge"] image:ackImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self userackMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
            NSString *iconName = @"hand.thumbsdown";
            GroupDeliveryReceipt *dr = [message old_reactionForMyIdentity];
            if (dr != nil) {
                if (dr.deliveryReceiptType == DeliveryReceiptTypeDeclined) {
                    iconName = @"hand.thumbsdown.fill";
                }
            }
            UIImage *declineImage = [[UIImage systemImageNamed:iconName] imageWithTintColor:Colors.thumbDown renderingMode:UIImageRenderingModeAlwaysOriginal];
            
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"decline"] image:declineImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self userdeclineMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
            UIImage *quoteImage = [UIImage systemImageNamed:@"quote.bubble.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"quote"] image:quoteImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self quoteMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if (UIAccessibilityIsSpeakSelectionEnabled()) {
            if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
                UIImage *speakImage = [UIImage systemImageNamed:@"text.bubble.fill" compatibleWithTraitCollection:self.traitCollection];
                UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"speak"] image:speakImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                    [self speakMessage:nil];
                }];
                [menuItems addObject:action];
            }
        }
        if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
            UIImage *copyImage = [UIImage systemImageNamed:@"doc.on.doc.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"copy"] image:copyImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self copyMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(forwardMessage:) withSender:nil]) {
            UIImage *forwardImage = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"forward"] image:forwardImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self forwardMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
            UIImage *shareImage = [UIImage systemImageNamed:@"square.and.arrow.up.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"share"] image:shareImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self shareMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
            UIImage *resendImage = [UIImage systemImageNamed:@"paperplane.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"try_again"] image:resendImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self resendMessage:nil];
            }];
            [menuItems addObject:action];
        }
        
        if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
            UIImage *detailsImage = [UIImage systemImageNamed:@"info.circle.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"details"] image:detailsImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self detailsMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
            UIImage *deleteImage = [UIImage systemImageNamed:@"trash.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"delete"] image:deleteImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self deleteMessage:nil];
            }];
            action.attributes = UIMenuElementAttributesDestructive;
            [deleteItems addObject:action];
        }
        UIMenu *actionsMenu = [UIMenu menuWithTitle:@"" image:nil identifier:UIMenuApplication options:UIMenuOptionsDisplayInline children:menuItems];
        UIMenu *deleteMenu = [UIMenu menuWithTitle:@"" image:nil identifier:UIMenuApplication options:UIMenuOptionsDisplayInline children:deleteItems];
        return [UIMenu menuWithTitle:@"" children:@[actionsMenu, deleteMenu]];
    }];
    return conf;
}

- (NSArray *)contextMenuItems API_AVAILABLE(ios(13.0)) {
    if (self.editing) {
        return nil;
    }
    
    NSMutableArray *menuItems = [NSMutableArray array];
    NSMutableArray *deleteItems = [NSMutableArray array];
    if ([self canPerformAction:@selector(userackMessage:) withSender:nil]) {
        NSString *iconName = @"hand.thumbsup";
        GroupDeliveryReceipt *dr = [message old_reactionForMyIdentity];
        if (dr != nil) {
            if (dr.deliveryReceiptType == DeliveryReceiptTypeAcknowledged) {
                iconName = @"hand.thumbsup.fill";
            }
        }
        UIImage *ackImage = [[UIImage systemImageNamed:iconName] imageWithTintColor:Colors.thumbUp renderingMode:UIImageRenderingModeAlwaysOriginal];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"acknowledge"] image:ackImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self userackMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
        NSString *iconName = @"hand.thumbsdown";
        GroupDeliveryReceipt *dr = [message old_reactionForMyIdentity];
        if (dr != nil) {
            if (dr.deliveryReceiptType == DeliveryReceiptTypeDeclined) {
                iconName = @"hand.thumbsdown.fill";
            }
        }
        UIImage *declineImage = [[UIImage systemImageNamed:iconName] imageWithTintColor:Colors.thumbDown renderingMode:UIImageRenderingModeAlwaysOriginal];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"decline"] image:declineImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self userdeclineMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIImage *quoteImage = [UIImage imageNamed:@"Quote" inColor:Colors.text];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"quote"] image:quoteImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self quoteMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if (UIAccessibilityIsSpeakSelectionEnabled()) {
        if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
            UIImage *speakImage = [UIImage systemImageNamed:@"text.bubble.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"speak"] image:speakImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
                [self speakMessage:nil];
            }];
            [menuItems addObject:action];
        }
    }
    if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
        UIImage *copyImage = [UIImage systemImageNamed:@"doc.on.doc.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"copy"] image:copyImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self copyMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(forwardMessage:) withSender:nil]) {
        UIImage *forwardImage = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"forward"] image:forwardImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self forwardMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
        UIImage *shareImage = [UIImage systemImageNamed:@"square.and.arrow.up.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"share"] image:shareImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self shareMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
        UIImage *resendImage = [UIImage systemImageNamed:@"paperplane.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"try_again"] image:resendImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self resendMessage:nil];
        }];
        [menuItems addObject:action];
    }
    
    if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
        UIImage *detailsImage = [UIImage systemImageNamed:@"info.circle.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"details"] image:detailsImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self detailsMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        UIImage *deleteImage = [UIImage systemImageNamed:@"trash.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"delete"] image:deleteImage identifier:nil handler:^(__unused __kindof UIAction * _Nonnull action) {
            [self deleteMessage:nil];
        }];
        action.attributes = UIMenuElementAttributesDestructive;
        [deleteItems addObject:action];
    }
    
    UIMenu *actionsMenu = [UIMenu menuWithTitle:@"" image:nil identifier:UIMenuApplication options:UIMenuOptionsDisplayInline children:menuItems];
    UIMenu *deleteMenu = [UIMenu menuWithTitle:@"" image:nil identifier:UIMenuApplication options:UIMenuOptionsDisplayInline children:deleteItems];
    return @[actionsMenu, deleteMenu];
}

- (void)showCallMenu {
    
    NSMutableArray *menuItems = [NSMutableArray array];
    
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIImage *quoteImage = [UIImage imageNamed:@"Quote" inColor:[UIColor whiteColor]];
        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:quoteImage target:self action:@selector(quoteMessage:)];
        item.accessibilityLabel = [BundleUtil localizedStringForKey:@"quote"];
        [menuItems addObject:item];
    }
    
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:[BundleUtil localizedStringForKey:@"delete"] target:self action:@selector(deleteMessage:)]];
    }
    
    _popupMenu = [[QBPopupMenu alloc] initWithItems:menuItems];
    _popupMenu.delegate = self;
    _popupMenu.color = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    _popupMenu.highlightedColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.95];
    _popupMenu.nextPageAccessibilityLabel = [BundleUtil localizedStringForKey:@"showNext"];
    _popupMenu.previousPageAccessibilityLabel = [BundleUtil localizedStringForKey:@"showPrevious"];
    
    CGRect targetRect = [self targetRectForMenuPopup];
    [_popupMenu showInView:chatVc.view targetRect:targetRect animated:YES];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _popupMenu);
    
    /* add view to add a quit for voice over */
    UIView *quitView = [[UIView alloc] initWithFrame:chatVc.view.subviews.lastObject.frame];
    quitView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
    quitView.alpha = 1;
    quitView.isAccessibilityElement = YES;
    quitView.accessibilityLabel = [BundleUtil localizedStringForKey:@"quit"];
    quitView.accessibilityActivationPoint = CGPointMake(0.0, 0.0);
    quitView.backgroundColor = [UIColor clearColor];
    quitView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    quitView.userInteractionEnabled = NO;
    [chatVc.view.subviews.lastObject insertSubview:quitView belowSubview:_popupMenu];
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapQuitPopoverMenu:)];
    [quitView addGestureRecognizer: tapGesture];
}

- (CGRect)targetRectForMenuPopup {
    CGRect cellRect = [chatVc.view convertRect:msgBackground.frame fromView:self];

    CGRect containingRect = chatVc.view.frame;
    CGFloat minY = chatVc.view.safeAreaInsets.top;
    CGFloat maxY = chatVc.visibleChatHeight;
    
    // cell overlapping top
    if (CGRectGetMinY(cellRect) - REQUIRED_MENU_HEIGHT < minY) {
        if (CGRectGetMaxY(cellRect) + REQUIRED_MENU_HEIGHT - minY > maxY) {
            // cell overlapping also bottom of containing view -> show in middle of cell
            cellRect = [RectUtil setHeightOf:cellRect height:REQUIRED_MENU_HEIGHT];
            return [RectUtil rect:cellRect centerVerticalIn:containingRect];
        } else {
            // force to show on bottom by extending top cell border
            return [RectUtil offsetAndResizeRect:cellRect byX:0.0 byY:-100.0];
        }
    }
    
    return cellRect;
}

- (void)tapQuitPopoverMenu:(id)sender {
    [_popupMenu dismissAnimated:YES];
}

- (void)resendMessage:(UIMenuController*)menuController {
}

- (void)copyMessage:(UIMenuController *)menuController {
}

- (void)speakMessage:(UIMenuController *)menuController {
}

- (void)shareMessage:(UIMenuController *)menuController {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
    if ([mdmSetup disableShareMedia] == true) {
        ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
        ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
        picker.enableMultiSelection = true;
        picker.enableTextInput = true;
        picker.submitOnSelect = false;
        
        if ([self.message isKindOfClass: [FileMessageEntity class]]) {
            picker.renderType = ((FileMessageEntity *) self.message).type;
        }
        
        [[AppDelegate sharedAppDelegate].window.rootViewController presentViewController:navigationController animated:YES completion:nil];
    } else {
        UIActivityViewController *activityViewController =  activityViewController = [ActivityUtil activityViewControllerForMessage:self.message withView:self.chatVc.view andRect:CGRectMake(0, 0, 0, 0)];
        [self.chatVc presentActivityViewController:activityViewController animated:YES fromView:self];
    }
}

- (void)forwardMessage:(UIMenuController *)menuController {
    ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
    ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
    picker.enableMultiSelection = true;
    picker.enableTextInput = true;
    picker.submitOnSelect = false;
    
    if ([self.message isKindOfClass: [FileMessageEntity class]]) {
        picker.renderType = ((FileMessageEntity *) self.message).type;
    }
    
    [[AppDelegate sharedAppDelegate].window.rootViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)setBubbleHighlighted:(BOOL)bubbleHighlighted {
    msgBackground.image = [self bubbleImageWithHighlight:bubbleHighlighted];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    
    if (dtgr != nil) {
        dtgr.enabled = !editing;
    }
    if (editing) {
        self.msgBackground.userInteractionEnabled = NO;
        self.alpha = 0.8;
    } else {
        self.msgBackground.userInteractionEnabled = YES;
        self.alpha = 1.0;
    }
}

- (void)userackMessage:(UIMenuController *)menuController {
    [self sendUserAck:YES];
}

- (void)userdeclineMessage:(UIMenuController *)menuController {
    [self sendUserAck:NO];
}

- (void)sendUserAck:(BOOL)doAcknowledge {

    if (!message.conversation.isGroup && message.userackDate != nil && message.userack.boolValue == doAcknowledge) {
        return;
    }
    if (message.conversation.isGroup && message.groupDeliveryReceipts != nil) {
        if (message.groupDeliveryReceipts.count > 0) {
            GroupDeliveryReceipt *gdr = [message old_reactionForMyIdentity];
            DeliveryReceiptType type = doAcknowledge ? DeliveryReceiptTypeAcknowledged : DeliveryReceiptTypeDeclined;
            if (gdr != nil &&
                [gdr deliveryReceiptType] == type) {
                return;
            }
        }
    }
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
    Group *group = [groupManager getGroupWithConversation:message.conversation];
    [entityManager performSyncBlockAndSafe:^{
        if (doAcknowledge) {
            [MessageSender sendUserAckForMessages:@[message] toIdentity:message.conversation.contact.identity group:group onCompletion:^{}];
            if (group == nil) {
                message.userack = @YES;
                message.userackDate = [NSDate date];
                [self updateStatusImage];
                [self setNeedsLayout];
            } else {
                GroupDeliveryReceipt *groupDeliveryReceipt = [[GroupDeliveryReceipt alloc] initWithIdentity:[MyIdentityStore sharedMyIdentityStore].identity deliveryReceiptType:DeliveryReceiptTypeAcknowledged date:[NSDate date]];
                [message addWithGroupDeliveryReceipt:groupDeliveryReceipt];
            }
        } else {
            [MessageSender sendUserDeclineForMessages:@[message] toIdentity:message.conversation.contact.identity group:group onCompletion:^{}];
            if (group == nil) {
                message.userack = @NO;
                message.userackDate = [NSDate date];
                [self updateStatusImage];
                [self setNeedsLayout];
            } else {
                GroupDeliveryReceipt *groupDeliveryReceipt = [[GroupDeliveryReceipt alloc] initWithIdentity:[MyIdentityStore sharedMyIdentityStore].identity deliveryReceiptType:DeliveryReceiptTypeDeclined date:[NSDate date]];
                [message addWithGroupDeliveryReceipt:groupDeliveryReceipt];
            }
        }
    }];
}

- (void)deleteMessage:(UIMenuController*)menuController {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIAlertTemplate showDestructiveAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:nil message:[BundleUtil localizedStringForKey:@"messages_delete_selected_confirm"] titleDestructive:[BundleUtil localizedStringForKey:@"delete"] actionDestructive:^(UIAlertAction *destructiveAction) {
            [chatVc cleanCellHeightCache];
            EntityManager *entityManager = [[EntityManager alloc] init];
            [entityManager performSyncBlockAndSafe:^{
                [[entityManager entityDestroyer] deleteObjectWithObject:message];
                [chatVc updateConversationLastMessage];
            }];
            [chatVc updateConversation];
        } titleCancel:[BundleUtil localizedStringForKey:@"cancel"] actionCancel:^(UIAlertAction *cancelAction) {
        }];
    });
}

- (void)detailsMessage:(UIMenuController*)menuController {
    [chatVc showMessageDetails:message];
}

- (void)quoteMessage:(UIMenuController*)menuController {
    if (_messageToQuote == nil || _messageToQuote == self.message) {
        _messageToQuote = nil;
        
        [self.chatVc.chatBar addQuotedMessage:self.message];
    }
}

- (NSString*)textForQuote {
    return nil;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copyMessage:)) {
        return YES;
    }
    else if (action == @selector(shareMessage:)) {
        MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
        if ([mdmSetup disableShareMedia] == true) {
            return NO;
        }
        return YES;
    } else if (action == @selector(userackMessage:) && ((!message.isOwn.boolValue && !message.conversation.isGroup) || message.conversation.isGroup)) {
        return YES;
    } else if (action == @selector(userdeclineMessage:) && ((!message.isOwn.boolValue && !message.conversation.isGroup) || message.conversation.isGroup)) {
        return YES;
    } else if (action == @selector(deleteMessage:)) {
        return YES;
    } else if (action == @selector(detailsMessage:)) {
        return YES;
    } else if (action == @selector(quoteMessage:)) {
        return YES;
    } else if (action == @selector(forwardMessage:)) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass:[BaseMessage class]]) {
        @try {
            BaseMessage *messageObject = (BaseMessage *)object;
            
            if (messageObject.objectID == self.message.objectID) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.message.wasDeleted == NO) {
                        [UIView animateWithDuration:0.5 animations:^{
                            [self updateDateLabel];
                            [self updateStatusImage];
                            [self updateTypingIndicator];
                            [self updateResendButton];
                            [self setNeedsLayout];
                        }];
                    }
                });
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into message");
        }
    }
}

- (void)setTyping:(BOOL)newTyping {
    typing = newTyping;
    [self updateTypingIndicator];
}

- (CGFloat)contentLeftOffset {
    if (message.sender == nil || message.isOwn.boolValue)
        return 0.0f;
    else
        return 30.0f;
}

+ (CGFloat)maxContentWidthForTableWidth:(CGFloat)tableWidth isGroup:(BOOL)isGroup {
    CGFloat additionalInset = 0;
    if (isGroup) {
        return tableWidth - kMessageScreenMarginGroup;
    }
    else {
        return tableWidth - kMessageScreenMargin;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (touches.count == 1) {
        if (UIAccessibilityIsVoiceOverRunning()) {
            /* when VoiceOver is on, double-taps on message cells will result in a touch located
               in the center of the cell. Since this may not be within the bubble, it will not
               trigger playing/showing media. Therefore, we hand this event to the cell */
            if ([self performPlayActionForAccessibility])
                return;
        }
        
        UITouch *touch = [touches anyObject];
        CGPoint point = [touch locationInView:self.contentView];
        if (!CGRectContainsPoint(self.msgBackground.frame, point))
            [self.chatVc messageBackgroundTapped:self.message];
    }
    
    [super touchesEnded:touches withEvent:event];
}

- (NSString *)accessibilityLabel {
    NSMutableString *text = [NSMutableString new];
    
    NSString *senderText = [message accessibilityMessageSender];
    if (senderText.length > 0) {
        [text appendFormat:@"%@. ", senderText];
    }
    
    [text appendFormat:@"%@\n", self.accessibilityLabelForContent];

    NSString *statusText = [message accessibilityMessageStatus];
    if (statusText.length > 0) {
        [text appendFormat:@"%@", statusText];
    }

    NSString *dateText = [DateFormatter accessibilityRelativeDayTime:message.displayDate];
    if (dateText.length > 0) {
        [text appendFormat:@". %@", dateText];
    }

    return text;
}

- (NSString *)accessibilityLabelForContent {
    return @"";
}

- (BOOL)performPlayActionForAccessibility {
    return NO;
}

- (BOOL)shouldHideBubbleBackground {
    return NO;
}

+ (UIFont *)textFont {
    return [UIFont systemFontOfSize: [ChatMessageCell textFontSize]];
}

+ (CGFloat)textFontSize {
    return [UserSettings sharedUserSettings].chatFontSize;
}

+ (UIFont *)quoteFont {
    return [UIFont systemFontOfSize: [ChatMessageCell quoteFontSize]];
}

+ (CGFloat)quoteFontSize {
    return [UserSettings sharedUserSettings].chatFontSize * QUOTE_FONT_SIZE_FACTOR;
}

+ (UIFont *)quoteIdentityFont {
    return [UIFont boldSystemFontOfSize: [ChatMessageCell quoteIdentityFontSize]];
}

+ (CGFloat)quoteIdentityFontSize {
    return [UserSettings sharedUserSettings].chatFontSize * QUOTE_FONT_SIZE_FACTOR;
}

+ (UIFont *)emojiFont {
    return [UIFont systemFontOfSize: [ChatMessageCell emojiFontSize]];
}

+ (CGFloat)emojiFontSize {
    return MIN(EMOJI_MAX_FONT_SIZE, [UserSettings sharedUserSettings].chatFontSize * EMOJI_FONT_SIZE_FACTOR);
}

- (BOOL)highlightOccurencesOf:(NSString *)pattern {
    // default implementation does nothing
    return NO;
}

+ (NSAttributedString *)highlightedOccurencesOf:(NSString *)pattern inString:(NSString *)text {
    BOOL hasMatches = NO;
    
    NSRange searchRange = NSMakeRange(0, text.length);
    
    UIFont *font = [ChatMessageCell textFont];
    
    NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:text];
    [attributedText addAttribute:NSFontAttributeName value:font range:searchRange];
    [attributedText addAttribute:NSForegroundColorAttributeName value:Colors.text range:searchRange];
    
    // fixes line height issues when text contains emojis (https://github.com/TTTAttributedLabel/TTTAttributedLabel/issues/405)
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.lineHeightMultiple = 1.0;
    paragraphStyle.minimumLineHeight = font.lineHeight;
    paragraphStyle.maximumLineHeight = font.lineHeight;
    [attributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:searchRange];

    if (pattern == nil) {
        return nil;
    }
    
    // options should match EntityFetcher options for fulltext search: [cd]
    NSStringCompareOptions options = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    
    UIColor *highlightColor = [UIColor redColor];
    while (true) {
        NSRange range = [text rangeOfString:pattern options:options range:searchRange];
        if (range.location == NSNotFound) {
            break;
        }
        
        hasMatches = YES;
        
        [attributedText addAttribute:NSForegroundColorAttributeName value:highlightColor range:range];
        
        NSInteger location = range.location + range.length;
        searchRange = NSMakeRange(location, text.length - location);
    }
    
    return attributedText;
}

- (UIViewController *)previewViewController {
    // default has no preview
    return nil;
}

- (UIViewController *)previewViewControllerFor:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    // default has no preview
    return nil;
}

- (void)willDisplay {
    //default implementation does nothing;
    [self updateColors];
}

- (void)didEndDisplaying {
    self.editing = false;
    //default implementation does nothing;
}

#pragma mark - QBPopupMenuDelegate

- (void)popupMenuWillAppear:(QBPopupMenu *)popupMenu {
    [self setBubbleHighlighted:YES];
}

- (void)popupMenuWillDisappear:(QBPopupMenu *)popupMenu {
    [self setBubbleHighlighted:NO];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self);
}


#pragma mark - Accessibility

- (NSArray *)accessibilityCustomActions {
    NSMutableArray *actions = [NSMutableArray new];
    
    if ([self canPerformAction:@selector(userackMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"acknowledge"] target:self selector:@selector(userackMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"decline"] target:self selector:@selector(userdeclineMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"quote"] target:self selector:@selector(quoteMessage:)];
        [actions addObject:action];
    }
    
    if (UIAccessibilityIsSpeakSelectionEnabled()) {
        if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
            UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"speak"] target:self selector:@selector(speakMessage:)];
            [actions addObject:action];
        }
    }
    
    if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"copy"] target:self selector:@selector(copyMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"share"] target:self selector:@selector(shareMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"try_again"] target:self selector:@selector(resendMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"details"] target:self selector:@selector(detailsMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"delete"] target:self selector:@selector(deleteMessage:)];
        [actions addObject:action];
    }
  
    return actions;
}


#pragma mark - Contact picker delegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    
    if ([self.message isKindOfClass: [TextMessage class]]) {
        TextMessage *textMessage = (TextMessage *)message;
        for (Conversation *conversation in conversations) {
            [MessageSender sendMessage:textMessage.text inConversation:conversation quickReply:NO requestId:nil onCompletion:^(BaseMessage *message) {
                ;//nop
            }];
            if (contactPicker.additionalTextToSend) {
                [MessageSender sendMessage:contactPicker.additionalTextToSend inConversation:conversation quickReply:NO requestId:nil onCompletion:^(BaseMessage *message) {
                    ;//nop
                }];
            }
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    }
    else if ([self.message isKindOfClass: [LocationMessage class]]) {
        LocationMessage *locationMessage = (LocationMessage *)message;
        
        CLLocationCoordinate2D coordinates = CLLocationCoordinate2DMake(locationMessage.latitude.doubleValue, locationMessage.longitude.doubleValue);
        double accurracy = locationMessage.accuracy.doubleValue;
        for (Conversation *conversation in conversations) {
            [MessageSender sendLocation:coordinates accuracy:accurracy poiName:locationMessage.poiName poiAddress:locationMessage.poiAddress inConversation:conversation onCompletion:^(NSData *messageId) {
                ;//nop
            }];
            if (contactPicker.additionalTextToSend) {
                [MessageSender sendMessage:contactPicker.additionalTextToSend inConversation:conversation quickReply:NO requestId:nil onCompletion:^(BaseMessage *message) {
                    ;//nop
                }];
            }
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else if ([self.message isKindOfClass: [FileMessageEntity class]] || sendAsFile == true) {
        [self handleFileMessagefromContactPicker:contactPicker didPickConversations:conversations];
 
    } else if ([self.message isKindOfClass: [AudioMessageEntity class]]) {
        AudioMessageEntity *audioMessageEntity = (AudioMessageEntity *)message;
        
        NSData *data = [audioMessageEntity.audio.data copy];
        for (Conversation *conversation in conversations) {
            URLSenderItem *item = [URLSenderItem itemWithData:data fileName:@"audio.m4a" type:UTTYPE_AUDIO renderType:@1 sendAsFile:true];
            Old_FileMessageSender *sender = [[Old_FileMessageSender alloc] init];
            [sender sendItem:item inConversation:conversation requestId:nil];
            
            if (contactPicker.additionalTextToSend) {
                item.caption = contactPicker.additionalTextToSend;
            }
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else if ([self.message isKindOfClass: [ImageMessageEntity class]]) {
        ImageMessageEntity *imageMessageEntity = (ImageMessageEntity *)message;
        NSString *caption = contactPicker.additionalTextToSend;
        // A ImageMessage can never be sent as file, thus the image data will always be converted
        [self forwardImageMessage:imageMessageEntity toConversations:conversations additionalTextToSend:caption];
        
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else if ([self.message isKindOfClass: [VideoMessageEntity class]]) {
        VideoMessageEntity *videoMessageEntity = (VideoMessageEntity *)message;
        
        NSURL *videoURL = [VideoURLSenderItemCreator writeToTemporaryDirectoryWithData:videoMessageEntity.video.data];
        
        if (videoURL == nil) {
            DDLogError(@"VideoURL was nil.");
            return;
        }
        
        VideoURLSenderItemCreator *senderCreator = [[VideoURLSenderItemCreator alloc] init];
        URLSenderItem *senderItem = [senderCreator senderItemFrom:videoURL];
        for (Conversation *conversation in conversations) {
            if (contactPicker.additionalTextToSend) {
                senderItem.caption = contactPicker.additionalTextToSend;
            }
            
            Old_FileMessageSender *sender = [[Old_FileMessageSender alloc] init];
            [sender sendItem:senderItem inConversation:conversation requestId:nil];
        }
        [contactPicker dismissViewControllerAnimated:YES completion:^(){
            (void)[VideoURLSenderItemCreator cleanTemporaryDirectory];
        }];
    }
}

- (void) handleFileMessagefromContactPicker:(ContactGroupPickerViewController *)contactPicker didPickConversations:(NSSet *)conversations {
    URLSenderItem *item;
    
    if ([self.message isKindOfClass: [FileMessageEntity class]]) {
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)message;
        NSNumber *type = fileMessageEntity.type;
        item = [URLSenderItem itemWithData:fileMessageEntity.data.data fileName:fileMessageEntity.fileName type:fileMessageEntity.blobGetUTI renderType:type sendAsFile:true];
    }
    else if ([self.message isKindOfClass: [AudioMessageEntity class]]) {
        AudioMessageEntity *audioMessageEntity = (AudioMessageEntity *)message;
        item = [URLSenderItem itemWithData:audioMessageEntity.audio.data fileName:audioMessageEntity.audio.getFilename type:audioMessageEntity.blobGetUTI renderType:@1 sendAsFile:true];
    }
    else if ([self.message isKindOfClass: [ImageMessageEntity class]]) {
        ImageMessageEntity *imageMessageEntity = (ImageMessageEntity *)message;
        item = [URLSenderItem itemWithData:imageMessageEntity.image.data fileName:imageMessageEntity.image.getFilename type:imageMessageEntity.blobGetUTI renderType:@0 sendAsFile:true];
    }
    else if ([self.message isKindOfClass: [VideoMessageEntity class]]) {
        VideoMessageEntity *videoMessageEntity = (VideoMessageEntity *)message;
        item = [URLSenderItem itemWithData:videoMessageEntity.video.data fileName:videoMessageEntity.video.getFilename type:videoMessageEntity.blobGetUTI renderType:@0 sendAsFile:true];
    }
    if (contactPicker.additionalTextToSend) {
        item.caption = contactPicker.additionalTextToSend;
    }
    for (Conversation *conversation in conversations) {
        Old_FileMessageSender *urlSender = [[Old_FileMessageSender alloc] init];
        [urlSender sendItem:item inConversation:conversation];
    }
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}

- (void)forwardImageMessage:(ImageMessageEntity *)imageMessage toConversations:(NSSet *)conversations additionalTextToSend:(NSString *)additionalText {
    // Images in ImageMessage are always jpg
    NSString* uti = UTTypeJPEG.identifier;

    for (Conversation *conversation in conversations) {
        ImageURLSenderItemCreator *imageSender = [[ImageURLSenderItemCreator alloc] init];
        URLSenderItem *item = [imageSender senderItemFrom:imageMessage.image.data uti:uti];
        
        if (additionalText) {
            item.caption = additionalText;
        }
        
        Old_FileMessageSender *sender = [[Old_FileMessageSender alloc] init];
        [sender sendItem:item inConversation:conversation];
    }
}

- (void)contactPickerDidCancel:(ContactGroupPickerViewController*)contactPicker {
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - ModalNavigationControllerDelegate

- (void)willDismissModalNavigationController {
    
}


#pragma mark Gesture Recognizer

- (IBAction)panGestureCellAction:(UIPanGestureRecognizer *)recognizer {
    if (UIAccessibilityIsVoiceOverRunning() || ![self canPerformAction:@selector(quoteMessage:) withSender:nil] || self.chatVc.chatContent.editing == true) {
        quoteSlideIconImage.alpha = 0.0;
        [recognizer.view setFrame: CGRectMake(recognizer.view.frame.origin.x, recognizer.view.frame.origin.y, recognizer.view.frame.size.width, recognizer.view.frame.size.height)];
        return;
    }
    CGPoint translation = [recognizer translationInView:self.chatVc.view];
    if (recognizer.view.frame.origin.x < 0) {
        quoteSlideIconImage.alpha = 0.0;
        [recognizer.view setFrame: CGRectMake(0, recognizer.view.frame.origin.y, recognizer.view.frame.size.width, recognizer.view.frame.size.height)];
        return;
    }
    
    _messageToQuote = self.message;
    
    recognizer.view.center = CGPointMake(recognizer.view.center.x+ translation.x,
                                         recognizer.view.center.y );
    [recognizer setTranslation:CGPointMake(0, 0) inView:self.chatVc.view];
    if(recognizer.view.frame.origin.x > [UIScreen mainScreen].bounds.size.width * 0.9)
    {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            quoteSlideIconImage.alpha = 0.0;
            [recognizer.view setFrame: CGRectMake(0, recognizer.view.frame.origin.y, recognizer.view.frame.size.width, recognizer.view.frame.size.height)];
        } completion:nil];
    }
    
    CGFloat minX = self.msgBackground.frame.size.width/2 < 75.0 && message.isOwn.boolValue ? self.msgBackground.frame.size.width / 2 : 75.0;
    CGFloat newAlpha = recognizer.view.frame.origin.x / minX;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (quoteSlideIconImage.alpha < 0.8 && newAlpha >= 0.8) {
            [gen prepare];
        }
        if (quoteSlideIconImage.alpha < 1.0 && newAlpha >= 1.0) {
            [gen impactOccurred];
        }
    });
    
    if (message.isOwn.boolValue) {
        quoteSlideIconImage.frame = CGRectMake(dateLabel.frame.origin.x - 30.0, recognizer.view.frame.origin.y + (recognizer.view.frame.size.height / 2) - 10.0, 20.0, 20.0);
    } else {
        if (message.conversation.isGroup == true) {
            quoteSlideIconImage.frame = CGRectMake(groupSenderImageButton.frame.origin.x - 30.0, recognizer.view.frame.origin.y + (recognizer.view.frame.size.height / 2) - 10.0, 20.0, 20.0);
        } else {
            quoteSlideIconImage.frame = CGRectMake(self.msgBackground.frame.origin.x - 30.0, recognizer.view.frame.origin.y + (recognizer.view.frame.size.height / 2) - 10.0, 20.0, 20.0);
        }
    }
    quoteSlideIconImage.alpha = recognizer.view.frame.origin.x / minX;
    
    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        int x = recognizer.view.frame.origin.x;
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            quoteSlideIconImage.alpha = 0.0;
            [recognizer.view setFrame: CGRectMake(0, recognizer.view.frame.origin.y, recognizer.view.frame.size.width, recognizer.view.frame.size.height)];
        } completion:^(BOOL finished) {
            if (x > minX) {
                [self quoteMessage:nil];
            } else {
                _messageToQuote = nil;
            }
        }];
    }
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (self.chatVc.chatContent.editing == true) {
            return true;
        }
        CGPoint velocity = [((UIPanGestureRecognizer *) gestureRecognizer) velocityInView:self.chatVc.chatContent];
        if (fabs(velocity.x) >= fabs(velocity.y)) {
            if (velocity.x < 0) {
                quoteSlideIconImage.alpha = 0.0;
                [gestureRecognizer.view setFrame: CGRectMake(0, gestureRecognizer.view.frame.origin.y, gestureRecognizer.view.frame.size.width, gestureRecognizer.view.frame.size.height)];
                return false;
            }
        }
        return fabs(velocity.x) >= fabs(velocity.y);
    }
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] && [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return false;
    }
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return [otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]];
}

@end
