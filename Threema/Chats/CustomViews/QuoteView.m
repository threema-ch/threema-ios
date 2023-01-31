//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import "QuoteView.h"
#import "Contact.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import "UILabel+Markup.h"
#import "UIImage+ColoredImage.h"
#import "TextStyleUtils.h"
#import "TTTAttributedLabel.h"
#import "BundleUtil.h"
#import "NSString+Hex.h"
#import "BallotMessage.h"
#import "LocationMessage.h"
#import "UserSettings.h"
#import "FileMessagePreview.h"

#define QUOTE_FONT_SIZE_FACTOR 0.8

static CGFloat quoteTextSpacing = 8.0f;
static CGFloat quoteBarWidth = 2.0f;
static CGFloat quoteBarSpacing = 8.0f;
static CGFloat cancelButtonSpacing = 5.0f;
static CGFloat cancelButtonSize = 30.0f;
static CGFloat quoteImageSize = 60.0;
static CGFloat quoteImageSpacing = 8.0;
static CGFloat quoteIconSpacing = 8.0;

@implementation QuoteView {
    UIView *quoteBar;
    TTTAttributedLabel *quoteLabel;
    UIView *borderView;
    UIButton *cancelButton;
    UIImageView *quoteImage;
    UIImageView *quoteIcon;
    
    NSString *quotedText;
    Contact *quotedContact;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        quoteBar = [[UIView alloc] init];
        [self addSubview:quoteBar];
        
        quoteLabel = [[TTTAttributedLabel alloc] initWithFrame:CGRectZero];
        quoteLabel.numberOfLines = 4;
        quoteLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:quoteLabel];
        
        cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [cancelButton addTarget:self action:@selector(cancelQuote:) forControlEvents:UIControlEventTouchUpInside];
        cancelButton.accessibilityLabel = [BundleUtil localizedStringForKey:@"cancel"];
        [self addSubview:cancelButton];
        
        quoteImage = [[UIImageView alloc] initWithFrame:self.bounds];
        quoteImage.contentMode = UIViewContentModeScaleAspectFill;
        quoteImage.clipsToBounds = true;
        [self addSubview:quoteImage];
        
        quoteIcon = [[UIImageView alloc] initWithFrame:self.bounds];
        quoteIcon.contentMode = UIViewContentModeScaleAspectFill;
        quoteIcon.clipsToBounds = true;
        [self addSubview:quoteIcon];
        
        _buttonWidthHint = cancelButtonSize + cancelButtonSpacing;
        
        [self updateColors];
        [self setNeedsLayout];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    quoteBar.frame = CGRectMake(0, 0, quoteBarWidth, self.frame.size.height);
    if (!quoteImage.hidden) {
        if (quoteLabel.textAlignment == NSTextAlignmentRight) {
            quoteImage.frame = CGRectMake(quoteBarWidth + quoteTextSpacing, quoteBarSpacing, quoteImageSize, quoteImageSize);
            quoteLabel.frame = CGRectMake(quoteImage.frame.origin.x + quoteImageSize + quoteImageSpacing, 0, self.frame.size.width - quoteBarWidth - quoteTextSpacing - _buttonWidthHint - quoteImageSize - quoteImageSpacing, self.frame.size.height);
            cancelButton.frame = CGRectMake(1 + quoteLabel.frame.origin.x + quoteLabel.frame.size.width + (_buttonWidthHint - cancelButtonSize) / 2, (self.frame.size.height - cancelButtonSize) / 2, cancelButtonSize, cancelButtonSize);

        } else {
            quoteLabel.frame = CGRectMake(quoteBarWidth + quoteTextSpacing, 0, self.frame.size.width - quoteBarWidth - quoteTextSpacing - _buttonWidthHint - quoteImageSize - quoteImageSpacing, self.frame.size.height);
            quoteImage.frame = CGRectMake(quoteLabel.frame.origin.x + quoteLabel.frame.size.width + quoteImageSpacing, quoteBarSpacing, quoteImageSize, quoteImageSize);
            cancelButton.frame = CGRectMake(1 + quoteImage.frame.origin.x + quoteImage.frame.size.width + (_buttonWidthHint - cancelButtonSize) / 2, (self.frame.size.height - cancelButtonSize) / 2, cancelButtonSize, cancelButtonSize);

        }
    } else {
        if (!quoteIcon.hidden) {
            quoteLabel.frame = CGRectMake(quoteBarWidth + quoteTextSpacing + [quoteLabel.font pointSize] + quoteIconSpacing, 0, self.frame.size.width - quoteBarWidth - quoteTextSpacing - _buttonWidthHint - [quoteLabel.font pointSize] - quoteIconSpacing, self.frame.size.height);
            quoteIcon.frame = CGRectMake(quoteBarWidth + quoteTextSpacing, (self.frame.size.height / 2) - ([quoteLabel.font pointSize] / 2), [quoteLabel.font pointSize], [quoteLabel.font pointSize]);
            cancelButton.frame = CGRectMake(1 + quoteLabel.frame.origin.x + quoteLabel.frame.size.width + (_buttonWidthHint - cancelButtonSize) / 2, (self.frame.size.height - cancelButtonSize) / 2, cancelButtonSize, cancelButtonSize);
        } else {
            quoteLabel.frame = CGRectMake(quoteBarWidth + quoteTextSpacing, 0, self.frame.size.width - quoteBarWidth - quoteTextSpacing - _buttonWidthHint, self.frame.size.height);
            cancelButton.frame = CGRectMake(1 + quoteLabel.frame.origin.x + quoteLabel.frame.size.width + (_buttonWidthHint - cancelButtonSize) / 2, (self.frame.size.height - cancelButtonSize) / 2, cancelButtonSize, cancelButtonSize);
        }
    }
}

- (void)updateColors {
    quoteBar.backgroundColor = Colors.backgroundQuoteBar;
    [cancelButton setImage:[UIImage imageNamed:@"Close" inColor:Colors.backgroundButton] forState:UIControlStateNormal];
    quoteLabel.attributedText = [self makeQuoteAttributedString];
}

- (CGSize)sizeThatFits:(CGSize)size {
    // Calculate the size that we actually need, which may be less than what we have available
    UILabel *dummyLabel = [[UILabel alloc] init];
    dummyLabel.numberOfLines = 4;
    dummyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    dummyLabel.attributedText = [self makeQuoteAttributedString];
    
    CGFloat imageOrIconWidth = 0.0;
    if (!quoteImage.hidden) {
        imageOrIconWidth = quoteImageSpacing + quoteImageSize;
    }
    
    if (!quoteIcon.hidden) {
        imageOrIconWidth = quoteIconSpacing;
    }
    
    CGFloat reservedWidth = quoteBarWidth + quoteTextSpacing + _buttonWidthHint + imageOrIconWidth;
    CGSize availableSizeForLabel = CGSizeMake(size.width - reservedWidth, size.height);
    CGSize labelSize = [dummyLabel sizeThatFits:availableSizeForLabel];
    
    CGSize quoteSize = CGSizeMake(labelSize.width + reservedWidth, labelSize.height);
    if (!quoteImage.hidden && quoteSize.height < quoteImageSize + quoteBarSpacing) {
        quoteSize.height = quoteImageSize + quoteBarSpacing;
    }

    return quoteSize;
}

- (void)setQuotedText:(NSString *)newQuotedText quotedContact:(Contact *)newQuotedContact {
    quotedText = newQuotedText;
    quotedContact = newQuotedContact;
    
    quoteLabel.textAlignment = [newQuotedText textAlignment];
    
    quoteLabel.attributedText = [self makeQuoteAttributedString];
    quoteImage.hidden = true;
    quoteIcon.hidden = true;
    [self setNeedsLayout];
}

- (void)setQuotedMessage:(BaseMessage *)quotedMessage {
    _quotedMessage = quotedMessage;
    
    quotedText = _quotedMessage.quotePreviewText;
    
    quoteLabel.textAlignment = [quotedText textAlignment];
    
    Contact *sender;
    if (_quotedMessage.isOwn.boolValue) {
        sender = nil;
    } else if (_quotedMessage.sender != nil) {
        sender = _quotedMessage.sender;
    } else {
        sender = _quotedMessage.conversation.contact;
    }
    quotedContact = sender;
    
    quoteLabel.attributedText = [self makeQuoteAttributedString];
    
    quoteImage.hidden = true;
    quoteImage.image = nil;
    quoteIcon.hidden = true;
    quoteIcon.image = nil;
    
    if ([quotedMessage isKindOfClass:[ImageMessageEntity class]]) {
        if (((ImageMessageEntity *) quotedMessage).thumbnail != nil) {
            quoteImage.hidden = false;
            quoteImage.image = ((ImageMessageEntity *)quotedMessage).thumbnail.uiImage;
        }
    }
    else if ([quotedMessage isKindOfClass:[VideoMessageEntity class]]) {
        if (((VideoMessageEntity *) quotedMessage).thumbnail != nil) {
            quoteImage.hidden = false;
            quoteImage.image = ((VideoMessageEntity *)quotedMessage).thumbnail.uiImage;
        }
    }
    else if ([quotedMessage isKindOfClass:[FileMessageEntity class]]) {
        if (((FileMessageEntity *) quotedMessage).thumbnail != nil) {
            quoteImage.hidden = false;
            quoteImage.image = ((FileMessageEntity *)quotedMessage).thumbnail.uiImage;
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
    else if ([quotedMessage isKindOfClass:[BallotMessage class]]) {
        quoteIcon.hidden = false;
        quoteIcon.image = [[BundleUtil imageNamed:@"ActionBallot"] imageWithTint:Colors.textQuote];
    }
    else if ([quotedMessage isKindOfClass:[LocationMessage class]]) {
        quoteIcon.hidden = false;
        quoteIcon.image = [[BundleUtil imageNamed:@"CurrentLocation"] imageWithTint:Colors.textQuote];
    }

    [self setNeedsLayout];
}

- (void)cancelQuote:(id)sender {
    [self.delegate quoteCancelled];
}

- (NSAttributedString*)makeQuoteAttributedString {
    if (quotedText == nil)
        return nil;
    
    NSMutableAttributedString *quoteString = [[NSMutableAttributedString alloc] init];
    
    // Resolve identity to name
    NSString *identityNewline;
    if (quotedContact == nil) {
        identityNewline = [[BundleUtil localizedStringForKey:@"me"] stringByAppendingString:@"\n"];
    } else {
        identityNewline = [quotedContact.displayName stringByAppendingString:@"\n"];
    }
    
    [quoteString appendAttributedString:[[NSAttributedString alloc] initWithString:identityNewline attributes:@{
                                                                                                                NSForegroundColorAttributeName: Colors.textQuoteID,
                                                                                                                NSFontAttributeName: [QuoteView quoteIdentityFont],
                                                                                                                @"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                                                                                                @"NSTextCheckingResult": @"searchQuote"
                                                                                                                }]];
    
    NSAttributedString *quotedTextAttr = [[NSMutableAttributedString alloc] initWithString:quotedText attributes:@{
                                                                                                                   NSForegroundColorAttributeName: Colors.textQuote,
                                                                                                                   NSFontAttributeName: [QuoteView quoteFont],
                                                                                                                   @"ZSWTappableLabelTappableRegionAttributeName": @YES,
                                                                                                                   @"NSTextCheckingResult": @"searchQuote"
                                                                                                                   }];
    NSAttributedString *quotedTextAttrMarkup = [quoteLabel applyMarkupFor:quotedTextAttr];
    [quoteString appendAttributedString:quotedTextAttrMarkup];
    NSAttributedString *styledString =  [TextStyleUtils makeMentionsAttributedStringForAttributedString:quoteString textFont:[QuoteView quoteFont] atColor:[Colors.text colorWithAlphaComponent:0.4] messageInfo:TextStyleUtilsMessageInfoReceivedMessage application:[UIApplication sharedApplication]];
    return styledString;
}

+ (UIFont *)quoteFont {
    return [UIFont systemFontOfSize:[UserSettings sharedUserSettings].chatFontSize * QUOTE_FONT_SIZE_FACTOR];
}

+ (UIFont *)quoteIdentityFont {
    return [UIFont boldSystemFontOfSize:[UserSettings sharedUserSettings].chatFontSize * QUOTE_FONT_SIZE_FACTOR];
}

@end
