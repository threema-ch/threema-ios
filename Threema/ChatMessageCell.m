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

#import "ChatMessageCell.h"
#import "ChatDefines.h"
#import "TextMessage.h"
#import "Conversation.h"
#import "Contact.h"
#import "MessageSender.h"
#import "ChatViewController.h"
#import "CustomResponderTextView.h"
#import "Utils.h"
#import "UserSettings.h"
#import "EntityManager.h"
#import "AvatarMaker.h"
#import "ActivityUtil.h"
#import "UIImage+ColoredImage.h"
#import "QBPopupMenu.h"
#import "RectUtil.h"
#import "BaseMessage+Accessibility.h"
#import "BundleUtil.h"
#import "Threema-Swift.h"
#import "ContactGroupPickerViewController.h"
#import "ChatTextMessageCell.h"
#import "FileMessageSender.h"

#define DATE_LABEL_BG_COLOR [[Colors backgroundDark] colorWithAlphaComponent:0.9]
#define REQUIRED_MENU_HEIGHT 50.0
#define EMOJI_FONT_SIZE_FACTOR 3
#define EMOJI_MAX_FONT_SIZE 50
#define QUOTE_FONT_SIZE_FACTOR 0.8

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
    UIImageView *statusImage;
    UILabel *dateLabel;
    UIImageView *typingIndicator;
    UIImageView *groupSenderImage;
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
        
        self.backgroundColor = transparent ? [UIColor clearColor] : [Colors background]; // clearColor slows performance
        
        // Create message background image view
        msgBackground = [[UIImageView alloc] init];
        msgBackground.clearsContextBeforeDrawing = NO;
        msgBackground.backgroundColor = transparent ? [UIColor clearColor] : [Colors background]; // clearColor slows performance
        [self.contentView addSubview:msgBackground];
        
        // Status image
        statusImage = [[UIImageView alloc] init];
        statusImage.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:statusImage];
        
        // Date label
        if (transparent && [UserSettings sharedUserSettings].wallpaper) {
            dateLabel = [[RoundedRectLabel alloc] init];
            ((RoundedRectLabel*)dateLabel).cornerRadius = 6;
            dateLabel.backgroundColor = DATE_LABEL_BG_COLOR;
        } else {
            dateLabel = [[UILabel alloc] init];
            dateLabel.backgroundColor = [UIColor clearColor];
        }
        dateLabel.font = [UIFont systemFontOfSize:MAX(11.0f, MIN(14.0, roundf([UserSettings sharedUserSettings].chatFontSize * 11.0 / 16.0)))];
        dateLabel.numberOfLines = 2;
        [self.contentView addSubview:dateLabel];
        
        UIImage *quoteImage = [[BundleUtil imageNamed:@"Quote"] imageWithTint:[Colors fontNormal]];
        quoteSlideIconImage = [[UIImageView alloc] initWithImage:quoteImage];
        quoteSlideIconImage.alpha = 0.0;
        [self.contentView addSubview:quoteSlideIconImage];
        
        gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        
        // Typing indicator
        typingIndicator = [[UIImageView alloc] init];
        
        [self.contentView addSubview:typingIndicator];
        
        // Add gesture recognizers for copying (cannot use shouldShowMenuForRowAtIndexPath as we need
        // control over the horizontal position of the menu)
        if (@available(iOS 13.0, *)) {
        } else {
            UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
            [self addGestureRecognizer:lpgr];
            
            dtgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
            dtgr.numberOfTapsRequired = 2;
            [self addGestureRecognizer:dtgr];
        }
        
        pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panGestureCellAction:)];
        pan.delegate = self;
        [self.contentView addGestureRecognizer:pan];

        [self setupColors];
    }
    
    return self;
}

- (void)setupColors {
    dateLabel.textColor = [Colors fontLight];
    
    typingIndicator.image = [self getStatusImageNamed:@"Typing" withCustomColor:nil];
    
    self.tintColor = [Colors main];
    
    UIView *v = [[UIView alloc] init];
    v.backgroundColor = [[Colors main] colorWithAlphaComponent:0.1];
    self.selectedBackgroundView = v;
    
    quoteSlideIconImage.image = [[BundleUtil imageNamed:@"Quote"] imageWithTint:[Colors fontNormal]];
}

- (void)dealloc {
    @try {
        [message removeObserver:self forKeyPath:@"read"];
        [message removeObserver:self forKeyPath:@"delivered"];
        [message removeObserver:self forKeyPath:@"sent"];
        [message removeObserver:self forKeyPath:@"userack"];
    }
    @catch(NSException *e) {}
}

- (void)setMessage:(BaseMessage *)newMessage {
    @try {
        [message removeObserver:self forKeyPath:@"read"];
        [message removeObserver:self forKeyPath:@"delivered"];
        [message removeObserver:self forKeyPath:@"sent"];
        [message removeObserver:self forKeyPath:@"userack"];
    }
    @catch(NSException *e) {}
    
    message = newMessage;
    
    [self setupColors];

    [self setBubbleHighlighted:NO];
    
    if (message.isOwn.boolValue) { // right bubble
        msgBackground.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        statusImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        
        dateLabel.textAlignment = NSTextAlignmentRight;
        dateLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else { // left bubble
        msgBackground.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        statusImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        
        dateLabel.textAlignment = NSTextAlignmentLeft;
        dateLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    [self updateStatusImage];
    [self updateDateLabel];
    [self updateTypingIndicator];
    [self updateGroupSenderImage];
    
    [self setNeedsLayout];
    
    if (!self.chatVc.isOpenWithForceTouch) {
        [message addObserver:self forKeyPath:@"read" options:0 context:nil];
        [message addObserver:self forKeyPath:@"delivered" options:0 context:nil];
        [message addObserver:self forKeyPath:@"sent" options:0 context:nil];
        [message addObserver:self forKeyPath:@"userack" options:0 context:nil];
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
    
    CGSize dateLabelSize = [dateLabel sizeThatFits:CGSizeMake(60, 28)];
    CGFloat dateLabelWidth = ceilf(dateLabelSize.width);
    CGFloat dateLabelHeight = ceilf(dateLabelSize.height);
    
    if (message.isOwn.boolValue) { // right bubble
        msgBackground.frame = CGRectMake(self.contentView.frame.size.width-bubbleSize.width-bgSideMargin,
                                         bgTopOffset, bubbleSize.width, bubbleSize.height);
    
        CGFloat bubbleMaxY = CGRectGetMaxY(msgBackground.frame);

        statusImage.frame = CGRectMake(msgBackground.frame.origin.x - 8 - 20, bubbleMaxY - 27, 20, 18);
        dateLabel.frame = CGRectMake(statusImage.frame.origin.x - dateLabelWidth - 8, 0, dateLabelWidth, dateLabelHeight);;
        
        typingIndicator.frame = CGRectMake(4, bubbleMaxY - 22, 22, 20);
        
        if (statusImage.hidden) {
            dateLabel.frame = CGRectOffset(dateLabel.frame, 28, 0);
        }
        
        if (dateLabel.hidden == NO) {
            [self verticalAlignDateLabel];
        }
    } else { // left bubble
        msgBackground.frame = CGRectMake(bgSideMargin + self.contentLeftOffset, bgTopOffset, bubbleSize.width, bubbleSize.height);

        CGFloat bubbleMaxY = CGRectGetMaxY(msgBackground.frame);

        groupSenderImage.frame = CGRectMake(12, bubbleMaxY - 31, 27, 27);
        
        CGFloat xOffset = msgBackground.frame.origin.x + msgBackground.frame.size.width + 8;
        
        if (statusImage.hidden == NO) {
            statusImage.frame = CGRectMake(xOffset, bubbleMaxY - 27, 20, 18);
            xOffset += 28;
        }
        
        if (dateLabel.hidden == NO) {
            dateLabel.frame = CGRectMake(xOffset, bubbleMaxY - dateLabelHeight - 4, dateLabelWidth, dateLabelHeight);
            xOffset += 44;
            
            [self verticalAlignDateLabel];
        }
        
        if (typingIndicator.hidden == NO) {
            if (xOffset > (self.contentView.frame.size.width - 30)) {
                xOffset = self.contentView.frame.size.width - 30;
            }

            typingIndicator.frame = CGRectMake(xOffset, bubbleMaxY - 28, 22, 20);
        }
    }    
}

- (void)verticalAlignDateLabel {
    if (statusImage.hidden) {
        CGFloat bubbleMaxY = CGRectGetMaxY(msgBackground.frame);
        dateLabel.frame = [RectUtil setYPositionOf:dateLabel.frame y:bubbleMaxY - dateLabel.frame.size.height - 11];
    } else {
        dateLabel.frame = [RectUtil rect:dateLabel.frame alignVerticalWith:statusImage.frame round:YES];
    }
}

- (void)updateDateLabel {
    NSDate *date = [message dateForCurrentState];

    if (date != nil) {
        if (![Utils isSameDayWithDate1:date date2:message.remoteSentDate]) {
            dateLabel.text = [DateFormatter shortStyleDateTime:date];
        } else {
            dateLabel.text = [DateFormatter shortStyleTimeNoDate:date];
        }
        
        /* set background again as it seems to be lost sometimes with RoundedRectLabel */
        if (transparent && [UserSettings sharedUserSettings].wallpaper)
            dateLabel.backgroundColor = DATE_LABEL_BG_COLOR;
        else
            dateLabel.backgroundColor = [UIColor clearColor];
        
        dateLabel.hidden = NO;
    } else {
        dateLabel.hidden = YES;
    }
    
    /* received message - show timestamp only if setting is enabled */
    if (!message.isOwn.boolValue) {
        dateLabel.hidden = [UserSettings sharedUserSettings].showReceivedTimestamps == NO;
    }
}

- (void)updateTypingIndicator {    
    if (typing) {
        typingIndicator.hidden = NO;
        [self setNeedsLayout];
    } else {
        typingIndicator.hidden = YES;
    }
}

- (UIImage*)bubbleImageWithHighlight:(BOOL)bubbleHighlight {
    if (self.shouldHideBubbleBackground) {
        return nil;
    }
    
    if (message.isOwn.boolValue) {
        NSString *name = @"ChatBubbleSentMask";
        if (bubbleHighlight) {
            return [[UIImage imageNamed:name inColor:[Colors bubbleSentSelected]] stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        } else {
            return [[UIImage imageNamed:name inColor:[Colors bubbleSent]] stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        }
    } else {
        NSString *name = @"ChatBubbleReceivedMask";
        if (bubbleHighlight) {
            return [[UIImage imageNamed:name inColor:[Colors bubbleReceivedSelected]] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        } else {
            return [[UIImage imageNamed:name inColor:[Colors bubbleReceived]] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        }
    }
}


- (void)updateStatusImage {
    NSString *iconName;
    UIColor *color;
    
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
            } else {
                if (message.sent.boolValue) {
                    iconName = @"MessageStatus_sent";
                } else {
                    iconName = @"MessageStatus_sending";
                }
            }
        }
    }
    
    CGFloat alpha = 0.8;
    
    if (message.userackDate != nil) {
        if (message.userack.boolValue) {
            iconName = @"hand.thumbsup.fill_regular.S";
            color = [Colors green];
        } else if (message.userack.boolValue == NO) {
            iconName = @"hand.thumbsdown.fill_regular.S";
            color = [Colors orange];
        }
        
        alpha = 1.0;
    }
    
    if (iconName) {
        statusImage.image = [self getStatusImageNamed:iconName withCustomColor:color];

        statusImage.alpha = alpha;
        statusImage.hidden = NO;
    } else {
        statusImage.hidden = YES;
    }

    
    [self setNeedsLayout];
}

- (UIImage *)getStatusImageNamed:(NSString *)imageName withCustomColor:(UIColor *)color {
    if (color == nil && [UserSettings sharedUserSettings].wallpaper == nil) {
        color = [Colors fontLight];
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
        groupSenderImage.hidden = YES;
        groupSenderImage.image = nil;
        return;
    }
    
    if (groupSenderImage == nil) {
        groupSenderImage = [[UIImageView alloc] init];
        [self.contentView addSubview:groupSenderImage];
    }
    
    groupSenderImage.image = [BundleUtil imageNamed:@"Unknown"];
    [[AvatarMaker sharedAvatarMaker] avatarForContact:message.sender size:27.0f masked:YES onCompletion:^(UIImage *avatarImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            groupSenderImage.image = avatarImage;
        });
    }];
    
    
    
    groupSenderImage.hidden = NO;
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
        UIImage *ackImage = [UIImage imageNamed:@"hand.thumbsup.fill_regular.M" inColor:[Colors green]];
        
        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:ackImage target:self action:@selector(userackMessage:)];
        item.accessibilityLabel = NSLocalizedString(@"acknowledge", nil);
        [menuItems addObject:item];
    }
    
    if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
        UIImage *declineImage = [UIImage imageNamed:@"hand.thumbsdown.fill_regular.M" inColor:[Colors orange]];

        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:declineImage target:self action:@selector(userdeclineMessage:)];
        item.accessibilityLabel = NSLocalizedString(@"decline", nil);
        [menuItems addObject:item];
    }
    
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIImage *quoteImage = [UIImage imageNamed:@"Quote" inColor:[UIColor whiteColor]];
        QBPopupMenuItem *item = [QBPopupMenuItem itemWithImage:quoteImage target:self action:@selector(quoteMessage:)];
        item.accessibilityLabel = NSLocalizedString(@"quote", nil);
        [menuItems addObject:item];
    }
    
    if (UIAccessibilityIsSpeakSelectionEnabled()) {
        if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
            [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"speak", nil) target:self action:@selector(speakMessage:)]];
        }
    }
    
    if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"copy", nil) target:self action:@selector(copyMessage:)]];
    }
    
    if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"share", nil) target:self action:@selector(shareMessage:)]];
    }
    
    if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"try_again", nil) target:self action:@selector(resendMessage:)]];
    }
    
    if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"details", nil) target:self action:@selector(detailsMessage:)]];
    }
    
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"delete", nil) target:self action:@selector(deleteMessage:)]];
    }
    
    _popupMenu = [[QBPopupMenu alloc] initWithItems:menuItems];
    _popupMenu.delegate = self;
    _popupMenu.color = [Colors popupMenuBackground];
    _popupMenu.highlightedColor = [Colors popupMenuHighlight];
    _popupMenu.nextPageAccessibilityLabel = NSLocalizedString(@"showNext", nil);
    _popupMenu.previousPageAccessibilityLabel = NSLocalizedString(@"showPrevious", nil);

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
            UIImage *ackImage = [[UIImage imageNamed:@"hand.thumbsup.fill_regular.M" inColor:[Colors green]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"acknowledge", nil) image:ackImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self userackMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
            UIImage *declineImage = [[UIImage imageNamed:@"hand.thumbsdown.fill_regular.M" inColor:[Colors orange]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"decline", nil) image:declineImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self userdeclineMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
            UIImage *quoteImage = [UIImage systemImageNamed:@"quote.bubble.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"quote", nil) image:quoteImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self quoteMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if (UIAccessibilityIsSpeakSelectionEnabled()) {
            if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
                UIImage *speakImage = [UIImage systemImageNamed:@"text.bubble.fill" compatibleWithTraitCollection:self.traitCollection];
                UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"speak", nil) image:speakImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                    [self speakMessage:nil];
                }];
                [menuItems addObject:action];
            }
        }
        if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
            UIImage *copyImage = [UIImage systemImageNamed:@"doc.on.doc.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"copy", nil) image:copyImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self copyMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(forwardMessage:) withSender:nil]) {
            UIImage *forwardImage = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"forward", nil) image:forwardImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self forwardMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
            UIImage *shareImage = [UIImage systemImageNamed:@"square.and.arrow.up.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"share", nil) image:shareImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self shareMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
            UIImage *resendImage = [UIImage systemImageNamed:@"paperplane.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"try_again", nil) image:resendImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self resendMessage:nil];
            }];
            [menuItems addObject:action];
        }
        
        if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
            UIImage *detailsImage = [UIImage systemImageNamed:@"info.circle.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"details", nil) image:detailsImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self detailsMessage:nil];
            }];
            [menuItems addObject:action];
        }
        if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
            UIImage *deleteImage = [UIImage systemImageNamed:@"trash.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"delete", nil) image:deleteImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
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
        UIImage *ackImage = [[UIImage imageNamed:@"hand.thumbsup.fill_regular.M" inColor:[Colors green]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"acknowledge", nil) image:ackImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self userackMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
        UIImage *declineImage = [[UIImage imageNamed:@"hand.thumbsdown.fill_regular.M" inColor:[Colors orange]] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"decline", nil) image:declineImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self userdeclineMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIImage *quoteImage = [UIImage imageNamed:@"Quote" inColor:[Colors fontNormal]];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"quote", nil) image:quoteImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self quoteMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if (UIAccessibilityIsSpeakSelectionEnabled()) {
        if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
            UIImage *speakImage = [UIImage systemImageNamed:@"text.bubble.fill" compatibleWithTraitCollection:self.traitCollection];
            UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"speak", nil) image:speakImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                [self speakMessage:nil];
            }];
            [menuItems addObject:action];
        }
    }
    if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
        UIImage *copyImage = [UIImage systemImageNamed:@"doc.on.doc.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"copy", nil) image:copyImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self copyMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(forwardMessage:) withSender:nil]) {
        UIImage *forwardImage = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"forward", nil) image:forwardImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self forwardMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
        UIImage *shareImage = [UIImage systemImageNamed:@"square.and.arrow.up.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"share", nil) image:shareImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self shareMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
        UIImage *resendImage = [UIImage systemImageNamed:@"paperplane.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"try_again", nil) image:resendImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self resendMessage:nil];
        }];
        [menuItems addObject:action];
    }
    
    if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
        UIImage *detailsImage = [UIImage systemImageNamed:@"info.circle.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"details", nil) image:detailsImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self detailsMessage:nil];
        }];
        [menuItems addObject:action];
    }
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        UIImage *deleteImage = [UIImage systemImageNamed:@"trash.fill" compatibleWithTraitCollection:self.traitCollection];
        UIAction *action = [UIAction actionWithTitle:NSLocalizedString(@"delete", nil) image:deleteImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
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
        item.accessibilityLabel = NSLocalizedString(@"quote", nil);
        [menuItems addObject:item];
    }
    
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        [menuItems addObject:[QBPopupMenuItem itemWithTitle:NSLocalizedString(@"delete", nil) target:self action:@selector(deleteMessage:)]];
    }
    
    _popupMenu = [[QBPopupMenu alloc] initWithItems:menuItems];
    _popupMenu.delegate = self;
    _popupMenu.color = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    _popupMenu.highlightedColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.95];
    _popupMenu.nextPageAccessibilityLabel = NSLocalizedString(@"showNext", nil);
    _popupMenu.previousPageAccessibilityLabel = NSLocalizedString(@"showPrevious", nil);
    
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
    CGFloat minY = chatVc.topLayoutGuide.length;
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
    chatVc.prevAudioCategory = [AVAudioSession sharedInstance].category;
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
}

- (void)shareMessage:(UIMenuController *)menuController {
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
    if ([mdmSetup disableShareMedia] == true) {
        ModalNavigationController *navigationController = [ContactGroupPickerViewController pickerFromStoryboardWithDelegate:self];
        ContactGroupPickerViewController *picker = (ContactGroupPickerViewController *)navigationController.topViewController;
        picker.enableMultiSelection = true;
        picker.enableTextInput = true;
        picker.submitOnSelect = false;
        
        if ([self.message isKindOfClass: [FileMessage class]]) {
            picker.renderType = ((FileMessage *) self.message).type;
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
    
    if ([self.message isKindOfClass: [FileMessage class]]) {
        picker.renderType = ((FileMessage *) self.message).type;
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
    if (message.userackDate != nil && message.userack.boolValue == doAcknowledge) {
        return;
    }
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        if (doAcknowledge) {
            [MessageSender sendUserAckForMessages:@[message] toIdentity:message.conversation.contact.identity async:YES quickReply:NO];
            message.userack = [NSNumber numberWithBool:YES];
        } else {
            [MessageSender sendUserDeclineForMessages:@[message] toIdentity:message.conversation.contact.identity async:YES quickReply:NO];
            message.userack = [NSNumber numberWithBool:NO];
        }
        
        message.userackDate = [NSDate date];
        [self updateStatusImage];
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
        if (@available(iOS 13.0, *)) {
            MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:false];
            if ([mdmSetup disableShareMedia] == true) {
                return NO;
            }
        }
        return YES;
    } else if (action == @selector(userackMessage:) && !message.isOwn.boolValue && message.conversation.groupId == nil) {
        return YES;
    } else if (action == @selector(userdeclineMessage:) && !message.isOwn.boolValue && message.conversation.groupId == nil) {
        return YES;
    } else if (action == @selector(deleteMessage:)) {
        return YES;
    } else if (action == @selector(detailsMessage:)) {
        return YES;
    } else if (action == @selector(quoteMessage:)) {
        return YES;
    } else if (action == @selector(forwardMessage:)) {
        if (@available(iOS 13.0, *)) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == message) {
            [UIView animateWithDuration:0.5 animations:^{
                [self updateStatusImage];
                [self updateDateLabel];
                [self updateTypingIndicator];
            }];
        }
    });
}

- (void)setTyping:(BOOL)newTyping {
    typing = newTyping;
    [self updateTypingIndicator];
}

- (CGFloat)contentLeftOffset {
    if (message.sender == nil || message.isOwn.boolValue)
        return 0.0f;
    else
        return 40.0f;
}

+ (CGFloat)maxContentWidthForTableWidth:(CGFloat)tableWidth {
    return tableWidth - kMessageScreenMargin;
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

    NSString *dateText = [message accessibilityMessageDate];
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
    [attributedText addAttribute:NSForegroundColorAttributeName value:[Colors fontNormal] range:searchRange];
    
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
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"acknowledge", @"") target:self selector:@selector(userackMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(userdeclineMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"decline", @"") target:self selector:@selector(userdeclineMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(quoteMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"quote", @"") target:self selector:@selector(quoteMessage:)];
        [actions addObject:action];
    }
    
    if (UIAccessibilityIsSpeakSelectionEnabled()) {
        if ([self canPerformAction:@selector(speakMessage:) withSender:nil]) {
            UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"speak", @"") target:self selector:@selector(speakMessage:)];
            [actions addObject:action];
        }
    }
    
    if ([self canPerformAction:@selector(copyMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"copy", @"") target:self selector:@selector(copyMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(shareMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"share", @"") target:self selector:@selector(shareMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(resendMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"try_again", @"") target:self selector:@selector(resendMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(detailsMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"details", @"") target:self selector:@selector(detailsMessage:)];
        [actions addObject:action];
    }
    
    if ([self canPerformAction:@selector(deleteMessage:) withSender:nil]) {
        UIAccessibilityCustomAction *action = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"delete", @"") target:self selector:@selector(deleteMessage:)];
        [actions addObject:action];
    }
  
    return actions;
}


#pragma mark - Contact picker delegate

- (void)contactPicker:(ContactGroupPickerViewController*)contactPicker didPickConversations:(NSSet *)conversations renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    
    if ([self.message isKindOfClass: [TextMessage class]]) {
        TextMessage *textMessage = (TextMessage *)message;
        for (Conversation *conversation in conversations) {
            [MessageSender sendMessage:textMessage.text inConversation:conversation async:YES quickReply:NO requestId:nil onCompletion:^(TextMessage *message, Conversation *conv) {
                ;//nop
            }];
            if (contactPicker.additionalTextToSend) {
                [MessageSender sendMessage:contactPicker.additionalTextToSend inConversation:conversation async:YES quickReply:NO requestId:nil onCompletion:^(TextMessage *message, Conversation *conv) {
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
            [MessageSender sendLocation:coordinates accuracy:accurracy poiName:locationMessage.poiName poiAddress:nil inConversation:conversation onCompletion:^(NSData *messageId) {
                ;//nop
            }];
            if (contactPicker.additionalTextToSend) {
                [MessageSender sendMessage:contactPicker.additionalTextToSend inConversation:conversation async:YES quickReply:NO requestId:nil onCompletion:^(TextMessage *message, Conversation *conv) {
                    ;//nop
                }];
            }
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else if ([self.message isKindOfClass: [FileMessage class]] || sendAsFile == true) {
        [self handleFileMessagefromContactPicker:contactPicker didPickConversations:conversations];
 
    } else if ([self.message isKindOfClass: [AudioMessage class]]) {
        AudioMessage *audioMessage = (AudioMessage *)message;
        
        NSData *data = [audioMessage.audio.data copy];
        for (Conversation *conversation in conversations) {
            URLSenderItem *item = [URLSenderItem itemWithData:data fileName:@"audio.m4a" type:UTTYPE_AUDIO renderType:@1 sendAsFile:true];
            FileMessageSender *sender = [[FileMessageSender alloc] init];
            [sender sendItem:item inConversation:conversation requestId:nil];
            
            if (contactPicker.additionalTextToSend) {
                item.caption = contactPicker.additionalTextToSend;
            }
        }
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else if ([self.message isKindOfClass: [ImageMessage class]]) {
        ImageMessage *imageMessage = (ImageMessage *)message;
        NSString *caption = contactPicker.additionalTextToSend;
        // A ImageMessage can never be sent as file, thus the image data will always be converted
        [self forwardImageMessage:imageMessage toConversations:conversations additionalTextToSend:caption];
        
        [contactPicker dismissViewControllerAnimated:YES completion:nil];
    } else if ([self.message isKindOfClass: [VideoMessage class]]) {
        VideoMessage *videoMessage = (VideoMessage *)message;
        
        NSURL *videoURL = [VideoURLSenderItemCreator writeToTemporaryDirectoryWithData:videoMessage.video.data];
        
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
            
            FileMessageSender *sender = [[FileMessageSender alloc] init];
            [sender sendItem:senderItem inConversation:conversation requestId:nil];
        }
        [contactPicker dismissViewControllerAnimated:YES completion:^(){
            [VideoURLSenderItemCreator cleanTemporaryDirectory];
        }];
    }
}

- (void) handleFileMessagefromContactPicker:(ContactGroupPickerViewController *)contactPicker didPickConversations:(NSSet *)conversations {
    URLSenderItem *item;
    
    if ([self.message isKindOfClass: [FileMessage class]]) {
        FileMessage *fileMessage = (FileMessage *)message;
        NSNumber *type = fileMessage.type;
        item = [URLSenderItem itemWithData:fileMessage.data.data fileName:fileMessage.fileName type:fileMessage.blobGetUTI renderType:type sendAsFile:true];
    }
    else if ([self.message isKindOfClass: [AudioMessage class]]) {
        AudioMessage *audioMessage = (AudioMessage *)message;
        item = [URLSenderItem itemWithData:audioMessage.audio.data fileName:audioMessage.audio.getFilename type:audioMessage.blobGetUTI renderType:@1 sendAsFile:true];
    }
    else if ([self.message isKindOfClass: [ImageMessage class]]) {
        ImageMessage *imageMessage = (ImageMessage *)message;
        item = [URLSenderItem itemWithData:imageMessage.image.data fileName:imageMessage.image.getFilename type:imageMessage.blobGetUTI renderType:@0 sendAsFile:true];
    }
    else if ([self.message isKindOfClass: [VideoMessage class]]) {
        VideoMessage *videoMessage = (VideoMessage *)message;
        item = [URLSenderItem itemWithData:videoMessage.video.data fileName:videoMessage.video.getFilename type:videoMessage.blobGetUTI renderType:@0 sendAsFile:true];
    }
    if (contactPicker.additionalTextToSend) {
        item.caption = contactPicker.additionalTextToSend;
    }
    for (Conversation *conversation in conversations) {
        FileMessageSender *urlSender = [[FileMessageSender alloc] init];
        [urlSender sendItem:item inConversation:conversation];
    }
    [contactPicker dismissViewControllerAnimated:YES completion:nil];
}

- (void)forwardImageMessage:(ImageMessage *)imageMessage toConversations:(NSSet *)conversations additionalTextToSend:(NSString *)additionalText {
    // Images in ImageMessage are always jpg
    CFStringRef uti = kUTTypeJPEG;

    for (Conversation *conversation in conversations) {
        ImageURLSenderItemCreator *imageSender = [[ImageURLSenderItemCreator alloc] init];
        URLSenderItem *item = [imageSender senderItemFrom:imageMessage.image.data uti:(__bridge NSString *)uti];
        
        if (additionalText) {
            item.caption = additionalText;
        }
        
        FileMessageSender *sender = [[FileMessageSender alloc] init];
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
    
    if (quoteSlideIconImage.alpha < 0.8 && newAlpha >= 0.8) {
        [gen prepare];
    }
    
    if (quoteSlideIconImage.alpha < 1.0 && newAlpha >= 1.0) {
        [gen impactOccurred];
    }
    if (message.isOwn.boolValue) {
        quoteSlideIconImage.frame = CGRectMake(dateLabel.frame.origin.x - 30.0, recognizer.view.frame.origin.y + (recognizer.view.frame.size.height / 2) - 10.0, 20.0, 20.0);
    } else {
        if (message.conversation.isGroup == true) {
            quoteSlideIconImage.frame = CGRectMake(groupSenderImage.frame.origin.x - 30.0, recognizer.view.frame.origin.y + (recognizer.view.frame.size.height / 2) - 10.0, 20.0, 20.0);
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
