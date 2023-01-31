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

@import SafariServices;

#import "ChatTextMessageCell.h"
#import "TextMessage.h"
#import "ChatDefines.h"
#import "UserSettings.h"
#import "UILabel+Markup.h"
#import "NonFirstResponderActionSheet.h"
#import "QRCodeActivity.h"
#import "NSString+Emoji.h"
#import "MyIdentityStore.h"
#import "ContactStore.h"
#import "Contact.h"
#import "QuoteUtil.h"
#import "BundleUtil.h"
#import "TextStyleUtils.h"
#import "ChatLocationMessageCell.h"
#import "ActivityUtil.h"
#import "Threema-Swift.h"
#import "ChatCallMessageCell.h"
#import "FileMessagePreview.h"
#import "ThreemaFramework.h"

static NSDictionary *linkAttributes = nil;
static NSDictionary *activeLinkAttributes = nil;
static NSDictionary *inactiveLinkAttributes = nil;

static CGFloat sideMargin = 2.0f;
static CGFloat quoteBarWidth = 2.0f;
static CGFloat quoteBarSpacing = 8.0f;
static CGFloat quoteTextSpacing = 8.0f;
static CGFloat quoteRightSpacing = 3.0f;
static CGFloat ZSWTappableLabelSpace = 22.0f;
static CGFloat quoteImageSize = 60.0;
static CGFloat quoteImageSpacing = 8.0;
static CGFloat quoteIconSpacing = 8.0;

static Theme currentTheme;

@implementation ChatTextMessageCell  {
    EntityManager *entityManager;
    ZSWTappableLabel *textLabel;
    ZSWTappableLabel *quoteLabel;
    UIImageView *quoteIcon;
    UIImageView *quoteImagePreview;
    UIView *quoteBar;
    UIAccessibilityElement *cellElement;
    NSURL *actionUrl;
    NSString *actionPhone;
    NSInteger openButtonIndex, copyButtonIndex, callButtonIndex;
    
    NSString *origText;
    NSString *origQuotedText;
    NSString *origQuotedIdentity;
    BaseMessage *quotedMessage;
}

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {
    CGSize size;
    CGSize maxSize = CGSizeMake([ChatMessageCell maxContentWidthForTableWidth:tableWidth isGroup:message.conversation.isGroup], CGFLOAT_MAX);
    TextMessage *textMessage = (TextMessage*)message;
    NSString *text = [textMessage text];
    NSString *quotedText = nil;
    NSString *quotedIdentity = nil;
    UIImage *quotedImage = nil;
    UIImage *quoteIcon = nil;
    if (textMessage.quotedMessageId != nil) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        BaseMessage *quoteMessage = [entityManager.entityFetcher messageWithId:textMessage.quotedMessageId conversation:textMessage.conversation];
        if (quoteMessage != nil) {
            if (quoteMessage.isOwn.boolValue) {
                quotedIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
            } else {
                if (quoteMessage.sender) {
                    quotedIdentity = quoteMessage.sender.identity;
                } else {
                    quotedIdentity = quoteMessage.conversation.contact.identity;
                }
            }
            
            quotedText = quoteMessage.quotePreviewText;
            if ([quoteMessage isKindOfClass:[ImageMessageEntity class]]) {
                if (((ImageMessageEntity *) quoteMessage).thumbnail != nil) {
                    quotedImage = ((ImageMessageEntity *) quoteMessage).thumbnail.uiImage;
                }
            }
            else if ([quoteMessage isKindOfClass:[VideoMessageEntity class]]) {
                if (((VideoMessageEntity *) quoteMessage).thumbnail != nil) {
                    quotedImage = ((VideoMessageEntity *) quoteMessage).thumbnail.uiImage;
                }
            }
            else if ([quoteMessage isKindOfClass:[FileMessageEntity class]]) {
                if (((FileMessageEntity *) quoteMessage).thumbnail != nil) {
                    quotedImage = ((FileMessageEntity *) quoteMessage).thumbnail.uiImage;
                }
            }
            else if ([quoteMessage isKindOfClass:[AudioMessageEntity class]]) {
                quoteIcon = [BundleUtil imageNamed:@"ActionMicrophone"];
            }
            else if ([quoteMessage isKindOfClass:[BallotMessage class]]) {
                quoteIcon = [BundleUtil imageNamed:@"ActionBallot"];
            }
            else if ([quoteMessage isKindOfClass:[LocationMessage class]]) {
                quoteIcon = [BundleUtil imageNamed:@"CurrentLocation"];
            }
        } else {
            quotedIdentity = @"";
            quotedText = [BundleUtil localizedStringForKey:@"quote_not_found"];
        }
    } else {
        NSString *remainingBody = nil;
        quotedText = [QuoteUtil parseQuoteFromMessage:text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
        if (quotedText) {
            text = remainingBody;
        }
    }
        
    if (![UserSettings sharedUserSettings].disableBigEmojis && [text isOnlyEmojisMaxCount:3]) {
        static ZSWTappableLabel *dummyLabelEmoji = nil;
        
        if (dummyLabelEmoji == nil) {
            dummyLabelEmoji = [ChatTextMessageCell makeAttributedLabelWithFrame:CGRectMake(0.0, 0.0, maxSize.width, maxSize.height)];
        }
        
        dummyLabelEmoji.font = [ChatMessageCell emojiFont];
        dummyLabelEmoji.attributedText = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: [ChatMessageCell emojiFont]}];
        
        size = [dummyLabelEmoji sizeThatFits:maxSize];
    } else {
        static ZSWTappableLabel *dummyLabel = nil;
        
        if (dummyLabel == nil) {
            dummyLabel = [ChatTextMessageCell makeAttributedLabelWithFrame:CGRectMake(0.0, 0.0, maxSize.width, maxSize.height)];
        }
        
        dummyLabel.font = [ChatMessageCell textFont];

        NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:text withFont:[ChatMessageCell textFont] textColor:Colors.text isOwn:true application:[UIApplication sharedApplication]];
        NSMutableAttributedString *formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[dummyLabel applyMarkupFor:attributed]];
        dummyLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:[ChatMessageCell textFont] atColor:[dummyLabel.textColor colorWithAlphaComponent:0.4] messageInfo:message.isOwn.intValue application:[UIApplication sharedApplication]];
        
        size = [dummyLabel sizeThatFits:maxSize];
    }
    
    // Add quote?
    if (quotedText.length > 0 || textMessage.quotedMessageId != nil) {
        static ZSWTappableLabel *dummyLabelQuote = nil;
        CGSize maxSizeQuote;
        if (quotedImage != nil) {
            maxSizeQuote = CGSizeMake(maxSize.width - quoteBarWidth - quoteBarSpacing - quoteRightSpacing - quoteImageSize - quoteImageSpacing, CGFLOAT_MAX);
        } else {
            if (quoteIcon != nil) {
                maxSizeQuote = CGSizeMake(maxSize.width - quoteBarWidth - quoteBarSpacing - quoteRightSpacing - dummyLabelQuote.font.pointSize - quoteIconSpacing, CGFLOAT_MAX);
            } else {
                maxSizeQuote = CGSizeMake(maxSize.width - quoteBarWidth - quoteBarSpacing - quoteRightSpacing, CGFLOAT_MAX);
            }
        }
        
        if (dummyLabelQuote == nil) {
            dummyLabelQuote = [ChatTextMessageCell makeAttributedLabelWithFrame:CGRectMake(0.0, 0.0, maxSizeQuote.width, maxSizeQuote.height)];
        }
        
        dummyLabelQuote.font = [ChatMessageCell quoteFont];
        NSMutableAttributedString *quoteAttributed = [[NSMutableAttributedString alloc] initWithAttributedString:[ChatTextMessageCell makeQuoteAttributedStringForIdentity:quotedIdentity quotedText:quotedText inLabel:dummyLabelQuote]];

        dummyLabelQuote.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:quoteAttributed textFont:[ChatMessageCell quoteFont] atColor:[Colors.textQuote colorWithAlphaComponent:0.4] messageInfo:message.isOwn.intValue application:[UIApplication sharedApplication]];
        
        if (dummyLabelQuote.attributedText.length > 200) {
            NSMutableAttributedString *trimmedString = [[NSMutableAttributedString alloc] initWithAttributedString:[dummyLabelQuote.attributedText attributedSubstringFromRange:NSMakeRange(0, 200)]];
            NSAttributedString *ellipses = [[NSAttributedString alloc] initWithString:@"..." attributes:@{ NSForegroundColorAttributeName: Colors.textQuote, NSFontAttributeName: [ChatMessageCell quoteFont]}];
            [trimmedString appendAttributedString:ellipses];
            dummyLabelQuote.attributedText = trimmedString;
        }
        
        CGSize quoteSize = [dummyLabelQuote sizeThatFits:maxSizeQuote];
        if (quotedImage != nil && quoteSize.height < quoteImageSize + quoteImageSpacing) {
            quoteSize.height = quoteImageSize + quoteImageSpacing;
        }
        size.height += quoteSize.height + quoteTextSpacing;
        size.width = MAX(size.width, quoteSize.width + quoteRightSpacing);
    }
    return size.height;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        
        // Create message text label
        textLabel = [ChatTextMessageCell makeAttributedLabelWithFrame:self.bounds];
        textLabel.tapDelegate = self;
        textLabel.longPressDelegate = self;
                
        [self.contentView addSubview:textLabel];
        entityManager = [[EntityManager alloc] init];
    }
    return self;
}

- (void)updateColors {
    [super updateColors];
       
    [self updateLinkColors];
    [self updateQuoteLabel];
}

- (void)updateLinkColors {
    if (currentTheme != Colors.theme) {
        currentTheme = Colors.theme;
        textLabel.attributedText = [textLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:origText withFont:textLabel.font textColor:nil isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]]];
    }
}

- (void)layoutSubviews {
    CGFloat messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.safeAreaLayoutGuide.layoutFrame.size.width isGroup:self.message.conversation.isGroup];
    
    CGSize textSize = [textLabel sizeThatFits:CGSizeMake(messageTextWidth, CGFLOAT_MAX)];
    
    CGSize quoteSize = CGSizeMake(0, 0);
    
    CGSize bubbleSize = textSize;
    if (quoteLabel != nil && quoteLabel.hidden == NO) {
        if (quoteImagePreview.hidden == false) {
            quoteSize = [quoteLabel sizeThatFits:CGSizeMake(messageTextWidth - quoteBarWidth - quoteBarSpacing - quoteRightSpacing - quoteImageSize - quoteImageSpacing, CGFLOAT_MAX)];
            if (quoteSize.height < quoteImageSize + quoteBarSpacing) {
                quoteSize.height = quoteImageSize + quoteBarSpacing;
            }
            bubbleSize.height += quoteSize.height + quoteTextSpacing;
            bubbleSize.width = MAX(quoteSize.width + quoteImageSize + quoteImageSpacing + quoteRightSpacing, textSize.width);
        } else {
            if (quoteIcon.hidden == false) {
                quoteSize = [quoteLabel sizeThatFits:CGSizeMake(messageTextWidth - quoteBarWidth - quoteBarSpacing - quoteRightSpacing - [quoteLabel.font pointSize] + quoteIconSpacing, CGFLOAT_MAX)];
                bubbleSize.height += quoteSize.height + quoteTextSpacing;
                bubbleSize.width = MAX(quoteSize.width + quoteRightSpacing + [quoteLabel.font pointSize] + quoteIconSpacing, textSize.width + [quoteLabel.font pointSize] + quoteIconSpacing);
            } else {
                quoteSize = [quoteLabel sizeThatFits:CGSizeMake(messageTextWidth - quoteBarWidth - quoteBarSpacing - quoteRightSpacing, CGFLOAT_MAX)];
                bubbleSize.height += quoteSize.height + quoteTextSpacing;
                bubbleSize.width = MAX(quoteSize.width + quoteRightSpacing, textSize.width);
            }
        }
    }
    
    [self setBubbleContentSize:bubbleSize];
    
    [super layoutSubviews];
    
    CGFloat x;
    CGFloat xLeftAligned;
    if (self.message.isOwn.boolValue) {
        xLeftAligned = self.contentView.frame.size.width-bubbleSize.width-21.0f-sideMargin;
        if (textLabel.textAlignment == NSTextAlignmentRight) {
            x = xLeftAligned + (bubbleSize.width - textSize.width + sideMargin);
        } else {
            x = xLeftAligned;
        }
    } else {
        xLeftAligned = 20.0f + self.contentLeftOffset;
        if (textLabel.textAlignment == NSTextAlignmentRight) {
            x = xLeftAligned + (bubbleSize.width - textSize.width + sideMargin);
        } else {
            x = xLeftAligned;
        }
        
    }
    
    CGFloat y = 7.0f;
    
    if (quoteLabel != nil && quoteLabel.hidden == NO) {
        if (quoteIcon.hidden == false) {
            quoteLabel.frame = CGRectMake(xLeftAligned + quoteBarWidth + quoteBarSpacing + [quoteLabel.font pointSize] + quoteIconSpacing, y, quoteSize.width, quoteSize.height);
            quoteIcon.frame = CGRectMake(xLeftAligned + quoteBarWidth + quoteBarSpacing, y + (quoteLabel.frame.size.height / 2) - ([quoteLabel.font pointSize] / 2), [quoteLabel.font pointSize], [quoteLabel.font pointSize]);
        } else {
            if (quoteLabel.textAlignment == NSTextAlignmentRight) {
                quoteLabel.frame = CGRectMake(xLeftAligned + bubbleSize.width + sideMargin - quoteSize.width, y, quoteSize.width, quoteSize.height);
            } else {
                quoteLabel.frame = CGRectMake(xLeftAligned + quoteBarWidth + quoteBarSpacing, y, quoteSize.width, quoteSize.height);
            }
        }
        
        if (quoteLabel.textAlignment == NSTextAlignmentRight) {
            quoteBar.frame = CGRectMake(xLeftAligned, y, quoteBarWidth, quoteSize.height);
            quoteImagePreview.frame = CGRectMake(xLeftAligned + quoteBarWidth + quoteImageSpacing, quoteBarSpacing, quoteImageSize, quoteImageSize);
        } else {
            quoteBar.frame = CGRectMake(xLeftAligned, y, quoteBarWidth, quoteSize.height);
            quoteImagePreview.frame = CGRectMake(quoteLabel.frame.origin.x + quoteLabel.frame.size.width + quoteImageSpacing, quoteBarSpacing, quoteImageSize, quoteImageSize);
        }
        
        y += quoteLabel.frame.size.height;
        y += quoteTextSpacing;
    }
    
    textLabel.frame = CGRectMake(ceil(x), ceil(y - (ZSWTappableLabelSpace/2)), ceil(textSize.width), ceil(textSize.height + ZSWTappableLabelSpace));
}

- (NSString *)accessibilityLabelForContent {
    if (((NSString *)quoteLabel.text).length > 0) {
        NSMutableString *accessibilityText = [[NSMutableString alloc] initWithString:textLabel.text];
        [accessibilityText appendString:@"\n"];
        [accessibilityText appendString:[BundleUtil localizedStringForKey:@"in_reply_to"]];
        [accessibilityText appendString:@"\n"];
        [accessibilityText appendString:quoteLabel.text];
        return accessibilityText;
    } else {
        return textLabel.text;
    }
}

- (void)setMessage:(BaseMessage *)newMessage {
    [super setMessage:newMessage];
    
    TextMessage *textMessage = (TextMessage*)self.message;
    origText = textMessage.text;
    
    [self updateQuoteLabel];
    
    if (![UserSettings sharedUserSettings].disableBigEmojis && [origText isOnlyEmojisMaxCount:3]) {
        textLabel.font = [ChatMessageCell emojiFont];
        textLabel.attributedText = [[NSAttributedString alloc] initWithString:origText attributes:@{NSFontAttributeName: [ChatMessageCell emojiFont]}];
    } else {
        textLabel.textAlignment = [origText textAlignment];
        textLabel.font = [ChatMessageCell textFont];
        
        NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:origText withFont:textLabel.font textColor:Colors.text isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]];
        NSMutableAttributedString *formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[textLabel applyMarkupFor:attributed]];
        textLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:textLabel.font atColor:[textLabel.textColor colorWithAlphaComponent:0.4] messageInfo:textMessage.isOwn.intValue application:[UIApplication sharedApplication]];
    }
    
    if (self.message.isOwn.boolValue) {
        textLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else {
        textLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    cellElement = nil;
    
    [self setNeedsLayout];
}

- (void)updateQuoteLabel {
    TextMessage *textMessage = (TextMessage*)self.message;
    
    if (quoteLabel == nil) {
        quoteLabel = [ChatTextMessageCell makeAttributedLabelWithFrame:self.bounds];
        quoteLabel.font = [ChatMessageCell quoteFont];
        quoteLabel.tapDelegate = self;
        quoteLabel.longPressDelegate = self;
        
        [self.contentView addSubview:quoteLabel];
        
        quoteBar = [[UIView alloc] init];
        
        [self.contentView addSubview:quoteBar];
    }
    
    if (quoteImagePreview == nil) {
        quoteImagePreview = [[UIImageView alloc] initWithFrame:self.bounds];
        quoteImagePreview.contentMode = UIViewContentModeScaleAspectFill;
        quoteImagePreview.clipsToBounds = true;
        [self.contentView addSubview:quoteImagePreview];
    }
    
    if (quoteIcon == nil) {
        quoteIcon = [[UIImageView alloc] initWithFrame:self.bounds];
        quoteIcon.contentMode = UIViewContentModeScaleAspectFill;
        quoteIcon.clipsToBounds = true;
        [self.contentView addSubview:quoteIcon];
    }
    
    quotedMessage = nil;
    
    if (textMessage.quotedMessageId != nil) {
        BaseMessage *quoteMessage = [entityManager.entityFetcher messageWithId:textMessage.quotedMessageId conversation:textMessage.conversation];
                
        quoteBar.backgroundColor = Colors.backgroundQuoteBar;
        NSString *quotedText = nil;
        if (quoteMessage != nil) {
            quotedMessage = quoteMessage;
            if (quoteMessage.isOwn.boolValue) {
                origQuotedIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
            } else {
                if (quoteMessage.sender) {
                    origQuotedIdentity = quoteMessage.sender.identity;
                } else {
                    origQuotedIdentity = quoteMessage.conversation.contact.identity;
                }
            }
            quotedText = quoteMessage.quotePreviewText;
        } else {
            origQuotedIdentity = @"";
            quotedText = [BundleUtil localizedStringForKey:@"quote_not_found"];
            origQuotedText = nil;
        }
                
        NSMutableAttributedString *quoteAttributed = [[NSMutableAttributedString alloc] initWithAttributedString:[ChatTextMessageCell makeQuoteAttributedStringForIdentity:origQuotedIdentity quotedText:quotedText inLabel:quoteLabel]];
        quoteLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:quoteAttributed textFont:quoteLabel.font atColor:[Colors.text colorWithAlphaComponent:0.4] messageInfo:self.message.isOwn.intValue application:[UIApplication sharedApplication]];
        
        if (quoteLabel.attributedText.length > 200) {
            NSMutableAttributedString *trimmedString = [[NSMutableAttributedString alloc] initWithAttributedString:[quoteLabel.attributedText attributedSubstringFromRange:NSMakeRange(0, 200)]];
            NSAttributedString *ellipses = [[NSAttributedString alloc] initWithString:@"..." attributes:@{ NSForegroundColorAttributeName: Colors.textQuote, NSFontAttributeName: [ChatMessageCell quoteFont]}];
            [trimmedString appendAttributedString:ellipses];
            quoteLabel.attributedText = trimmedString;
        }
        
        quoteLabel.textAlignment = [quotedText textAlignment];
        
        quoteLabel.hidden = NO;
        quoteBar.hidden = NO;
        quoteImagePreview.hidden = true;
        quoteImagePreview.image = nil;
        quoteIcon.hidden = true;
        quoteIcon.image = nil;
        
        if ([quotedMessage isKindOfClass:[ImageMessageEntity class]]) {
            if (((ImageMessageEntity *) quoteMessage).thumbnail != nil) {
                quoteImagePreview.hidden = false;
                quoteImagePreview.image = ((ImageMessageEntity *)quoteMessage).thumbnail.uiImage;
            }
        }
        else if ([quotedMessage isKindOfClass:[VideoMessageEntity class]]) {
            if (((VideoMessageEntity *) quoteMessage).thumbnail != nil) {
                quoteImagePreview.hidden = false;
                quoteImagePreview.image = ((VideoMessageEntity *)quoteMessage).thumbnail.uiImage;
            }
        }
        else if ([quotedMessage isKindOfClass:[FileMessageEntity class]]) {
            if (((FileMessageEntity *) quotedMessage).thumbnail != nil) {
                quoteImagePreview.hidden = false;
                quoteImagePreview.image = ((FileMessageEntity *)quotedMessage).thumbnail.uiImage;
            }
            else if ([((FileMessageEntity *) quotedMessage) renderFileAudioMessage] == true) {
                quoteIcon.hidden = false;
                quoteIcon.image = [[BundleUtil imageNamed:@"ActionMicrophone"] imageWithTint:Colors.textQuote];
            }
            else {
                quoteIcon.hidden = false;
                quoteIcon.image = [[FileMessagePreview thumbnailForFileMessageEntity:((FileMessageEntity *) quotedMessage)] imageWithTint:Colors.textQuote];
            }
        }
        else if ([quotedMessage isKindOfClass:[AudioMessageEntity class]]) {
            quoteIcon.hidden = false;
            quoteIcon.image = [[BundleUtil imageNamed:@"ActionMicrophone"] imageWithTint:Colors.textQuote];
        }
        else if ([quoteMessage isKindOfClass:[BallotMessage class]]) {
            quoteIcon.hidden = false;
            quoteIcon.image = [[BundleUtil imageNamed:@"ActionBallot"] imageWithTint:Colors.textQuote];
        }
        else if ([quoteMessage isKindOfClass:[LocationMessage class]]) {
            quoteIcon.hidden = false;
            quoteIcon.image = [[BundleUtil imageNamed:@"CurrentLocation"] imageWithTint:Colors.textQuote];
        }
        
        return;
    }
    
    quoteImagePreview.image = nil;
    quoteIcon.image = nil;
    
    if (origText == nil) {
        return;
    }
    
    NSString *quotedIdentity = nil;
    NSString *remainingBody = nil;
    
    NSString *quotedText = [QuoteUtil parseQuoteFromMessage:textMessage.text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
    if (quotedText != nil) {
        origQuotedText = quotedText;
        origText = remainingBody;
        origQuotedIdentity = quotedIdentity;
        
        quoteLabel.textAlignment = [origQuotedText textAlignment];
        
        quoteBar.backgroundColor = Colors.backgroundQuoteBar;
                
        NSMutableAttributedString *quoteAttributed = [[NSMutableAttributedString alloc] initWithAttributedString:[ChatTextMessageCell makeQuoteAttributedStringForIdentity:quotedIdentity quotedText:quotedText inLabel:quoteLabel]];
        quoteLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:quoteAttributed textFont:quoteLabel.font atColor:[Colors.text colorWithAlphaComponent:0.4] messageInfo:self.message.isOwn.intValue application:[UIApplication sharedApplication]];
        
        if (quoteLabel.attributedText.length > 200) {
            NSMutableAttributedString *trimmedString = [[NSMutableAttributedString alloc] initWithAttributedString:[quoteLabel.attributedText attributedSubstringFromRange:NSMakeRange(0, 200)]];
            NSAttributedString *ellipses = [[NSAttributedString alloc] initWithString:@"..." attributes:@{ NSForegroundColorAttributeName: Colors.textQuote, NSFontAttributeName: [ChatMessageCell quoteFont]}];
            [trimmedString appendAttributedString:ellipses];
            quoteLabel.attributedText = trimmedString;
        }
        
        quoteLabel.hidden = NO;
        quoteBar.hidden = NO;
        quoteImagePreview.hidden = YES;
        quoteIcon.hidden = YES;
    } else {
        origQuotedText = nil;
        origQuotedIdentity = nil;
        quoteLabel.text = nil;
        quoteLabel.hidden = YES;
        quoteBar.hidden = YES;
        quoteImagePreview.hidden = YES;
        quoteIcon.hidden = YES;
    }
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(resendMessage:) && self.message.isOwn) {
        return self.message.sendFailed != nil && self.message.sendFailed.boolValue;
    }
    if (action == @selector(speakMessage:)) {
        return YES;
    } else {
        return [super canPerformAction:action withSender:sender];
    }
}

- (void)resendMessage:(UIMenuController*)menuController {
    TextMessage *textMessage = (TextMessage*)self.message;
    
    EntityManager *temporaryEntityManager = [[EntityManager alloc] init];
    [temporaryEntityManager performSyncBlockAndSafe:^{
        TextMessage *textMessage = [[entityManager entityFetcher] existingObjectWithID:self.message.objectID];
        textMessage.id = [[NaClCrypto sharedCrypto] randomBytes:kMessageIdLen];
    }];
    
    [MessageSender sendBaseMessage:textMessage];
}

- (void)updateStatusImage {
    if (!self.message.sent.boolValue && self.message.sendFailed.boolValue) {
        self.statusImage.image = [UIImage imageNamed:@"MessageStatus_sendfailed"];
        self.statusImage.alpha = 0.8;
        self.statusImage.hidden = NO;
        [self setNeedsLayout];
    } else {
        [super updateStatusImage];
    }
}


- (BOOL)highlightOccurencesOf:(NSString *)pattern {
    NSAttributedString *attributedString = [ChatMessageCell highlightedOccurencesOf:pattern inString:origText];
    
    if (![UserSettings sharedUserSettings].disableBigEmojis && [origText isOnlyEmojisMaxCount:3]) {
        textLabel.font = [ChatMessageCell emojiFont];
        NSAttributedString *emoji =[[NSAttributedString alloc] initWithString:origText attributes:@{NSFontAttributeName: [ChatMessageCell emojiFont]}];
        textLabel.attributedText = emoji;
        if (attributedString) {
            return YES;
        } else {
            return NO;
        }
    } else {
        if (attributedString) {
            NSMutableAttributedString *markupString = [[NSMutableAttributedString alloc] initWithAttributedString:[textLabel applyMarkupFor:attributedString]];
            textLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:markupString textFont:textLabel.font atColor:[textLabel.textColor colorWithAlphaComponent:0.4] messageInfo:self.message.isOwn.intValue application:[UIApplication sharedApplication]];
            return YES;
        } else {
            NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:origText withFont:textLabel.font textColor:Colors.text isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]];
            NSMutableAttributedString *formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[textLabel applyMarkupFor:attributed]];
            textLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:textLabel.font atColor:[textLabel.textColor colorWithAlphaComponent:0.4] messageInfo:self.message.isOwn.intValue application:[UIApplication sharedApplication]];
            return NO;
        }
    }
}

- (void)copyMessage:(UIMenuController *)menuController {
    [[UIPasteboard generalPasteboard] setString:origText];
}

- (void)speakMessage:(UIMenuController *)menuController {
    [[[SpeechSynthesizerManger alloc] init] speak:origText];
}

- (NSString *)textForQuote {
    return origText;
}

- (void)handleTapResult:(id)result {
    if ([result isKindOfClass:[Contact class]]) {
        [self.chatVc mentionTapped:(Contact *)result];
    } else {
        if ([result isKindOfClass:[NSString class]]) {
            if ([(NSString *)result isEqualToString:@"meContact"]) {
                [self.chatVc mentionTapped:(NSString *)result];
            } else {
                if ([(NSString *)result isEqualToString:@"searchQuote"]) {
                    if (quotedMessage != nil) {
                        [self.chatVc showQuotedMessage:quotedMessage];
                    } else {
                        if (origQuotedText != nil) {
                            __block BaseMessage *foundMessage = nil;
                            NSArray *messageHits = [entityManager.entityFetcher quoteMessagesContaining:origQuotedText message:self.message inConversation:self.message.conversation];
                            [messageHits enumerateObjectsUsingBlock:^(BaseMessage *bm, NSUInteger idx, BOOL * _Nonnull stop) {
                                if (( bm.conversation.isGroup && ( [bm.sender.identity isEqualToString:origQuotedIdentity] || ( bm.isOwn.boolValue && [[[MyIdentityStore sharedMyIdentityStore] identity] isEqualToString:origQuotedIdentity] ) ) ) || ( !bm.conversation.isGroup && ( [bm.conversation.contact.identity isEqualToString:origQuotedIdentity]  || ( bm.isOwn.boolValue && [[[MyIdentityStore sharedMyIdentityStore] identity] isEqualToString:origQuotedIdentity] ) ) )) {
                                    if ([bm isKindOfClass:[TextMessage class]]) {
                                        NSString *quotedIdentity = nil;
                                        NSString *remainingBody = nil;

                                        NSString *quotedText = [QuoteUtil parseQuoteFromMessage:((TextMessage *)bm).text quotedIdentity:&quotedIdentity remainingBody:&remainingBody];
                                        if (quotedText != nil) {
                                            NSString *remaining = [remainingBody stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                            NSString *originalText = [origQuotedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                            if ([remaining isEqualToString:originalText]) {
                                                foundMessage = bm;
                                                *stop = YES;
                                            }
                                        } else {
                                            NSString *cellText = [((TextMessage *)bm).text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                            NSString *originalText = [origQuotedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                            if ([cellText isEqualToString:originalText]) {
                                                foundMessage = bm;
                                                *stop = YES;
                                            }
                                        }
                                    }
                                    else if ([bm isKindOfClass:[ImageMessageEntity class]]) {
                                        if ([[((ImageMessageEntity *)bm).image getCaption] isEqualToString:origQuotedText]) {
                                            foundMessage = bm;
                                            *stop = YES;
                                        }
                                    }
                                    else if ([bm isKindOfClass:[FileMessageEntity class]]) {
                                        if ([((FileMessageEntity *)bm).caption isEqualToString:origQuotedText]) {
                                            foundMessage = bm;
                                            *stop = YES;
                                        }
                                    }
                                    else if ([bm isKindOfClass:[LocationMessage class]]) {
                                        NSString *locationText = [ChatLocationMessageCell displayTextForLocationMessage:(LocationMessage *)bm];
                                        if ([origQuotedText containsString:locationText]) {
                                            foundMessage = bm;
                                            *stop = YES;
                                        }
                                    }
                                }
                            }];
                            
                            if (foundMessage) {
                                [self.chatVc showQuotedMessage:foundMessage];
                            } else {
                                [UIAlertTemplate showAlertWithOwner:self.chatVc title:@"" message:[BundleUtil localizedStringForKey:@"quote_not_found"] actionOk:nil];
                            }
                        }
                    }
                }
            }
        }
        else if ([result isKindOfClass:[NSTextCheckingResult class]]) {
            [self openLinkWithTextCheckingResult:(NSTextCheckingResult *)result];
        }
    }
}

- (void)handleLongPressResult:(NSTextCheckingResult *)result {
    if ([result isKindOfClass:[NSString class]]) {
        return;
    }
    if ([result isKindOfClass:[Contact class]]) {
        [self.chatVc mentionTapped:(Contact *)result];
    }
    else if (result.resultType == NSTextCheckingTypeLink) {
        actionUrl = result.URL;
        actionPhone = nil;
        
        UIAlertController *actionSheet = [NonFirstResponderActionSheet alertControllerWithTitle:[self displayStringForUrl:actionUrl] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"open"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
            [IDNSafetyHelper safeOpenWithUrl:actionUrl viewController:self.chatVc];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"copy"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
            if (actionPhone != nil)
                [[UIPasteboard generalPasteboard] setString:actionPhone];
            else
                [[UIPasteboard generalPasteboard] setString:[self displayStringForUrl:actionUrl]];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleDefault handler:nil]];
        
        if (SYSTEM_IS_IPAD) {
            actionSheet.popoverPresentationController.sourceView = self;
            actionSheet.popoverPresentationController.sourceRect = self.bounds;
        }
        
        [self.chatVc.chatBar resignFirstResponder];
        [self.chatVc presentViewController:actionSheet animated:YES completion:nil];
        
    } else if (result.resultType == NSTextCheckingTypePhoneNumber) {
        actionPhone = result.phoneNumber;
        actionUrl = nil;
        
        UIAlertController *actionSheet = [NonFirstResponderActionSheet alertControllerWithTitle:actionPhone message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"call"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
            [self callPhoneNumber:actionPhone];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"copy"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
            if (actionPhone != nil)
                [[UIPasteboard generalPasteboard] setString:actionPhone];
            else
                [[UIPasteboard generalPasteboard] setString:[self displayStringForUrl:actionUrl]];
        }]];
        [actionSheet addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleDefault handler:nil]];
        
        if (SYSTEM_IS_IPAD) {
            actionSheet.popoverPresentationController.sourceView = self;
            actionSheet.popoverPresentationController.sourceRect = self.bounds;
        }
        
        [self.chatVc.chatBar resignFirstResponder];
        [self.chatVc presentViewController:actionSheet animated:YES completion:nil];

    }
}

- (NSString*)displayStringForUrl:(NSURL*)url {
    NSString *urlString = [url.absoluteString stringByReplacingOccurrencesOfString:@"mailto:" withString:@""];
    return urlString;
}

+ (ZSWTappableLabel*)makeAttributedLabelWithFrame:(CGRect)rect {
    ZSWTappableLabel *label = [[ZSWTappableLabel alloc] initWithFrame:rect];
    label.clearsContextBeforeDrawing = NO;
    label.backgroundColor = [UIColor clearColor];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.font = [ChatMessageCell textFont];
    label.contentMode = UIViewContentModeScaleToFill;
    
    return label;
}

+ (NSAttributedString*)makeQuoteAttributedStringForIdentity:(NSString*)identity quotedText:(NSString*)quotedText inLabel:(UILabel*)label {
    NSMutableAttributedString *quoteString = [[NSMutableAttributedString alloc] init];
    
    // Resolve identity to name
    Contact *contact = [[ContactStore sharedContactStore] contactForIdentity:identity];
    NSString *identityNewline = @"";
    
    if ([identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        identityNewline = [[BundleUtil localizedStringForKey:@"me"] stringByAppendingString:@"\n"];
    } else if (contact != nil) {
        identityNewline = [contact.displayName stringByAppendingString:@"\n"];
    } else {
        if ([identity length] > 0) {
            identityNewline = [identity stringByAppendingString:@"\n"];
        }
    }
    
    [quoteString appendAttributedString:[[NSAttributedString alloc] initWithString:identityNewline attributes:@{
                                                                                                         NSForegroundColorAttributeName: Colors.textQuoteID,
                                                                                                         NSFontAttributeName: [ChatMessageCell quoteIdentityFont],
                                                                                                         @"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                                                                                         @"NSTextCheckingResult": @"searchQuote"
                                                                                                         }]];
    
    NSMutableAttributedString *quotedTextAttr = [[NSMutableAttributedString alloc] initWithString:quotedText attributes:@{
                                                                                                                   NSForegroundColorAttributeName: Colors.textQuote,
                                                                                                                   NSFontAttributeName: [ChatMessageCell quoteFont],
                                                                                                                   @"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                                                                                                   @"NSTextCheckingResult": @"searchQuote"
                                                                                                                   }];
    
    NSAttributedString *quotedTextAttrMarkup = [label applyMarkupFor:quotedTextAttr];
    [quoteString appendAttributedString:quotedTextAttrMarkup];
    
    return quoteString;
}

- (UIViewController *)previewViewControllerFor:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    id<ZSWTappableLabelTappableRegionInfo> regionInfo = [textLabel tappableRegionInfoForPreviewingContext:previewingContext location:location];
    if (!regionInfo) {
        return nil;
    }
    
    NSTextCheckingResult *result = regionInfo.attributes[@"NSTextCheckingResult"];
    if ([result isKindOfClass:[NSTextCheckingResult class]]) {
        if (result.resultType == NSTextCheckingTypeLink && ![[result.URL absoluteString] hasPrefix:@"mailto:"]) {
            NSURL *url = result.URL;
            if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
                [regionInfo configurePreviewingContext:previewingContext];
                ThreemaSafariViewController *webController = [[ThreemaSafariViewController alloc] initWithURL:result.URL];
                webController.url = result.URL;
                
                return webController;
            }
        }
    } 
    return nil;
}

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if (!self.editing) {
        CGPoint convertedPoint = [textLabel convertPoint:point fromView:self.chatVc.chatContent];
        NSDictionary *regionInfo = [textLabel checkIsPointAction:convertedPoint];
        if (regionInfo != nil) {
            NSTextCheckingResult *result = regionInfo[@"NSTextCheckingResult"];
            if ([result isKindOfClass:[NSTextCheckingResult class]]) {
                if (result.resultType == NSTextCheckingTypeLink && ![[result.URL absoluteString] hasPrefix:@"mailto:"]) {
                    NSURL *url = result.URL;
                    if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
                        ThreemaSafariViewController *webController = [[ThreemaSafariViewController alloc] initWithURL:result.URL];
                        webController.url = result.URL;
                        UIContextMenuConfiguration *conf = [UIContextMenuConfiguration configurationWithIdentifier:indexPath previewProvider:^UIViewController * _Nullable{
                            return webController;
                        } actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
                            NSMutableArray *menuItems = [NSMutableArray array];
                            UIImage *copyImage = [UIImage systemImageNamed:@"doc.on.doc.fill" compatibleWithTraitCollection:self.traitCollection];
                            UIAction *action = [UIAction actionWithTitle:[BundleUtil localizedStringForKey:@"copy"] image:copyImage identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
                                [[UIPasteboard generalPasteboard] setString:[self displayStringForUrl:result.URL]];
                            }];
                            [menuItems addObject:action];
                            return [UIMenu menuWithTitle:@"" image:nil identifier:UIMenuApplication options:UIMenuOptionsDisplayInline children:menuItems];
                        }];
                        return conf;
                    }
                }
            }
            return nil;
        }
    }
    
    return [super getContextMenu:indexPath point:point];
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
        if (CGRectContainsPoint(quoteImagePreview.frame, point)) {
            [self handleTapResult:@"searchQuote"];
            return;
        }
    }
    
    [super touchesEnded:touches withEvent:event];
}


#pragma mark - ZSWTappableLabel delegate

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel tappedAtIndex:(NSInteger)idx withAttributes:(NSDictionary *)attributes {
    [self handleTapResult:attributes[@"NSTextCheckingResult"]];
}

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel longPressedAtIndex:(NSInteger)idx withAttributes:(NSDictionary<NSString *,id> *)attributes {
    [self handleLongPressResult:attributes[@"NSTextCheckingResult"]];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.editing) {
         // don't event forward to label
         return self;
     }
    return [super hitTest:point withEvent:event];
}
         
- (void)callPhoneNumber:(NSString*)phoneNumber {
    NSString *cleanString = [phoneNumber stringByReplacingOccurrencesOfString:@"\u00a0" withString:@""];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", [cleanString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]]];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

#pragma mark - UIAccessibilityContainer

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSArray *)accessibilityCustomActions {
    NSMutableArray *actions =  [[NSMutableArray alloc] initWithArray:[super accessibilityCustomActions]];
    int indexCounter = 0;
    NSMutableArray *tmpArray = [NSMutableArray new];
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    for (int i = 0; i < textLabel.accessibilityElementCount; i++) {
        UIAccessibilityElement *element = [textLabel accessibilityElementAtIndex:i];
        if (![element.accessibilityLabel isEqualToString:@"."] && ![element.accessibilityLabel isEqualToString:@"@"]) {
            
            NSTextCheckingResult *urlResult = [self checkTextResult:element.accessibilityLabel];
            
            if (urlResult) {
                UIAccessibilityCustomAction *linkAction = [[UIAccessibilityCustomAction alloc] initWithName:[NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"open"], element.accessibilityLabel] target:self selector:@selector(openLink:)];
                [tmpArray addObject:linkAction];
                [indexSet addIndex:indexCounter];
                indexCounter ++;
                UIAccessibilityCustomAction *shareAction = [[UIAccessibilityCustomAction alloc] initWithName:[NSString stringWithFormat:@"%@: %@", [BundleUtil localizedStringForKey:@"share"], element.accessibilityLabel] target:self selector:@selector(shareLink:)];
                [tmpArray addObject:shareAction];
                [indexSet addIndex:indexCounter];
                indexCounter ++;
                
            } else {
                UIAccessibilityCustomAction *mentionAction = [[UIAccessibilityCustomAction alloc] initWithName:[NSString stringWithFormat:@"%@ @%@", [BundleUtil localizedStringForKey:@"details"], element.accessibilityLabel] target:self selector:@selector(openMention:)];
                [tmpArray addObject:mentionAction];
                [indexSet addIndex:indexCounter];
                indexCounter ++;
            }
        }
    }
    
    if (tmpArray.count > 0) {
        [actions insertObjects:tmpArray atIndexes:indexSet];
    }
    
    return actions;
}

- (BOOL)openLink:(UIAccessibilityCustomAction *)action {
    [self openLinkWithTextCheckingResult:[self checkTextResult:action.name]];
    return YES;
}

- (void)openLinkWithTextCheckingResult:(NSTextCheckingResult*)urlResult {
    if (urlResult.resultType == NSTextCheckingTypeLink) {
        [IDNSafetyHelper safeOpenWithUrl:urlResult.URL viewController:self.chatVc];
    } else if (urlResult.resultType == NSTextCheckingTypePhoneNumber) {
        [self callPhoneNumber:urlResult.phoneNumber];
    }
}

- (BOOL)shareLink:(UIAccessibilityCustomAction *)action {
    NSTextCheckingResult *urlResult = [self checkTextResult:action.name];
    
    if (urlResult.resultType == NSTextCheckingTypeLink) {
        UIActivityViewController *activityViewController =  [ActivityUtil activityViewControllerWithActivityItems:@[urlResult.URL] applicationActivities:@[]];
        [self.chatVc presentActivityViewController:activityViewController animated:YES fromView:self];
    }
    else if (urlResult.resultType == NSTextCheckingTypePhoneNumber) {
        UIActivityViewController *activityViewController =  [ActivityUtil activityViewControllerWithActivityItems:@[urlResult.phoneNumber] applicationActivities:@[]];
        [self.chatVc presentActivityViewController:activityViewController animated:YES fromView:self];
    }
    
    return YES;
}

- (BOOL)openMention:(UIAccessibilityCustomAction *)action {
    NSString *identity = [action.name stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@ @", [BundleUtil localizedStringForKey:@"details"]] withString:@""];
    if ([identity isEqualToString:[BundleUtil localizedStringForKey:@"me"]]) {
        [self handleTapResult:@"meContact"];
    } else {
        Contact *contact = [[ContactStore sharedContactStore] contactForIdentity:identity];
        [self handleTapResult:contact];
    }
    return YES;
}

- (NSTextCheckingResult *)checkTextResult:(NSString *)text {
    NSTextCheckingTypes textCheckingTypes = NSTextCheckingTypeLink;
    
    static dispatch_once_t onceToken;
    static BOOL canOpenPhoneLinks;
    dispatch_once(&onceToken, ^{
        canOpenPhoneLinks = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:0"]];
    });
    if (canOpenPhoneLinks)
        textCheckingTypes |= NSTextCheckingTypePhoneNumber;
    
    __block NSTextCheckingResult *urlResult = nil;
    
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:textCheckingTypes error:NULL];
    [detector enumerateMatchesInString:text options:0 range:NSMakeRange(0, text.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        urlResult = result;
    }];
    return urlResult;
}

@end
