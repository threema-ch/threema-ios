//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2023 Threema GmbH
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

#import "ChatCallMessageCell.h"
#import "SystemMessage.h"
#import "ZSWTappableLabel.h"
#import "UILabel+Markup.h"
#import "ChatDefines.h"
#import "UserSettings.h"
#import "UIImage+ColoredImage.h"
#import "ImageUtils.h"
#import "QBPopupMenuItem.h"
#import "QBPopupMenu.h"
#import "Contact.h"
#import "UIDefines.h"
#import "TextStyleUtils.h"
#import "BundleUtil.h"
#import "ServerConnector.h"
#import "Old_ChatTableDataSource.h"
#import "Threema-Swift.h"

static CGFloat sideMargin = 2.0f;
static CGFloat ZSWTappableLabelSpace = 16.0f;


static Theme currentTheme;

@implementation ChatCallMessageCell {
    ZSWTappableLabel *titleLabel;
    ZSWTappableLabel *descriptionLabel;
    UIImageView *imageView;
    UIImageView *callIcon;
    
    UIAccessibilityElement *cellElement;
    NSString *titleText;
    NSString *descriptionText;
}

+ (CGFloat)heightForMessage:(BaseMessage*)message forTableWidth:(CGFloat)tableWidth {
    CGSize titleSize;
    CGSize descriptionSize;
    CGSize maxSize = CGSizeMake([ChatMessageCell maxContentWidthForTableWidth:tableWidth isGroup:message.conversation.isGroup] - ZSWTappableLabelSpace - sideMargin, CGFLOAT_MAX);
    NSString *text = [(SystemMessage *)message format];
    NSString *description = [(SystemMessage *)message callDetail];
    
    static ZSWTappableLabel *dummyTitleLabel = nil;
    
    if (dummyTitleLabel == nil) {
        dummyTitleLabel = [ChatCallMessageCell makeAttributedLabelWithFrame:CGRectMake(0.0, 0.0, maxSize.width, maxSize.height)];
    }
    
    dummyTitleLabel.font = [UIFont boldSystemFontOfSize:[ChatMessageCell textFontSize]];
    static dispatch_once_t onceToken;
    static BOOL canOpenPhoneLinks;
    dispatch_once(&onceToken, ^{
        canOpenPhoneLinks = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tel:0"]];
    });
    
    NSString *spaces = @"";
    for (int i = 0; i < (dummyTitleLabel.font.pointSize / 2.2); i++) {
        spaces = [NSString stringWithFormat:@"%@ ", spaces];
    }
    
    text = [NSString stringWithFormat:@"%@%@",spaces, [(SystemMessage *)message format]];
    
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithAttributedString:[dummyTitleLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:text withFont:dummyTitleLabel.font textColor:nil isOwn:true application:[UIApplication sharedApplication]]]];
    dummyTitleLabel.attributedText = titleString;
    
    titleSize = [dummyTitleLabel sizeThatFits:maxSize];
    
    static ZSWTappableLabel *dummyDescriptionLabel = nil;
    
    if (dummyDescriptionLabel == nil) {
        dummyDescriptionLabel = [ChatCallMessageCell makeAttributedLabelWithFrame:CGRectMake(0.0, 0.0, maxSize.width, maxSize.height)];
    }
    
    dummyDescriptionLabel.font = [UIFont systemFontOfSize:[ChatMessageCell textFontSize] - 2.0];
    if (description == nil || description.length == 0) {
        description = @" ";
    }
    dummyDescriptionLabel.attributedText = [dummyDescriptionLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:description withFont:dummyDescriptionLabel.font textColor:nil isOwn:true application:[UIApplication sharedApplication]]];
    
    descriptionSize = [dummyDescriptionLabel sizeThatFits:maxSize];
    
    return titleSize.height + descriptionSize.height;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier transparent:(BOOL)transparent
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier transparent:transparent];
    if (self) {
        
        // Create message text label
        titleLabel = [ChatCallMessageCell makeAttributedLabelWithFrame:self.bounds];
        
        descriptionLabel = [ChatCallMessageCell makeAttributedLabelWithFrame:self.bounds];
        descriptionLabel.textAlignment = NSTextAlignmentRight;
        
        imageView = [UIImageView new];
        imageView.contentMode = UIViewContentModeCenter;
        imageView.image = [ImageUtils imageWithImage:[UIImage imageNamed:@"ThreemaPhone" inColor:[UIColor whiteColor]] scaledToSize:CGSizeMake(25, 25)];
        imageView.clipsToBounds = YES;
        
        callIcon = [UIImageView new];
        callIcon.contentMode = UIViewContentModeScaleAspectFit;
        
        [self.contentView addSubview:titleLabel];
        [self.contentView addSubview:descriptionLabel];
        [self.contentView addSubview:imageView];
        [self.contentView addSubview:callIcon];
        
        UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tgr.numberOfTapsRequired = 1;
        [self addGestureRecognizer:tgr];
        
        if (self.dtgr != nil) {
            [tgr requireGestureRecognizerToFail:self.dtgr];
        }
        
        self.statusImage.hidden = YES;
    }
    return self;
}

- (void)updateColors {
    [super updateColors];
    
    [self updateLinkColors];
}

- (void)updateLinkColors {
    if (currentTheme != Colors.theme) {
        currentTheme = Colors.theme;
        titleLabel.attributedText = [titleLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:titleText withFont:titleLabel.font textColor:nil isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]]];
        descriptionLabel.attributedText = [descriptionLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:descriptionText withFont:descriptionLabel.font textColor:nil isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]]];
    }
}

- (void)layoutSubviews {
    CGFloat messageTextWidth = [ChatMessageCell maxContentWidthForTableWidth:self.safeAreaLayoutGuide.layoutFrame.size.width isGroup:self.message.conversation.isGroup];
    CGSize titleSize = [titleLabel sizeThatFits:CGSizeMake(messageTextWidth, CGFLOAT_MAX)];
    CGSize descriptionSize = [descriptionLabel sizeThatFits:CGSizeMake(messageTextWidth, CGFLOAT_MAX)];
    CGFloat callImageWidth = 40.0f;
    
    CGSize bubbleSize = CGSizeMake(MAX(titleSize.width, descriptionSize.width), titleSize.height + descriptionSize.height);
    [self setBubbleContentSize:bubbleSize];
    
    [super layoutSubviews];
    
    CGFloat x;
    if (self.message.isOwn.boolValue) {
        x = self.contentView.frame.size.width-bubbleSize.width-21.0f-sideMargin;
    } else {
        x = 20.0f + self.contentLeftOffset;
    }
    
    CGFloat y = 14.0f;
    
    if (descriptionSize.height == 0 || [descriptionLabel.text isEqualToString:@" "]) {
        titleLabel.frame = CGRectMake(x, (y/2) + (bubbleSize.height/2) - (titleSize.height/2), bubbleSize.width, titleSize.height);
        descriptionLabel.hidden = YES;
    } else {
        titleLabel.frame = CGRectMake(x, y - (ZSWTappableLabelSpace/2), bubbleSize.width, titleSize.height + (ZSWTappableLabelSpace/3));
        descriptionLabel.frame = CGRectMake(x, titleLabel.frame.origin.y + titleLabel.frame.size.height - (ZSWTappableLabelSpace/1.5), bubbleSize.width, descriptionSize.height + ZSWTappableLabelSpace);
        descriptionLabel.hidden = NO;
    }
    
    CAShapeLayer * maskLayer = [CAShapeLayer layer];
    
    if (self.message.isOwn.boolValue) {
        imageView.frame = CGRectMake(self.msgBackground.frame.origin.x, self.msgBackground.frame.origin.y + 1.0, callImageWidth, self.msgBackground.frame.size.height - 7.0);
        maskLayer.path = [UIBezierPath bezierPathWithRoundedRect: imageView.bounds byRoundingCorners: UIRectCornerTopLeft | UIRectCornerBottomLeft cornerRadii: (CGSize){10.0, 10.}].CGPath;
    } else {
        imageView.frame = CGRectMake(self.msgBackground.frame.origin.x + self.msgBackground.frame.size.width - callImageWidth, self.msgBackground.frame.origin.y + 1, callImageWidth, self.msgBackground.frame.size.height - 7.0);
        maskLayer.path = [UIBezierPath bezierPathWithRoundedRect: imageView.bounds byRoundingCorners: UIRectCornerTopRight | UIRectCornerBottomRight cornerRadii: (CGSize){10.0, 10.}].CGPath;
    }
    imageView.layer.mask = maskLayer;
    imageView.backgroundColor = Colors.chatCallButtonBubble;
    
    CGFloat lineHeight = titleLabel.font.lineHeight;
    if (descriptionSize.height == 0 || [descriptionLabel.text isEqualToString:@" "]) {
        callIcon.frame = CGRectMake(titleLabel.frame.origin.x, titleLabel.frame.origin.y + lineHeight - titleLabel.font.pointSize - 2.0, (titleLabel.font.pointSize/2)*3, titleLabel.font.pointSize);
    } else {
        callIcon.frame = CGRectMake(titleLabel.frame.origin.x, titleLabel.frame.origin.y + lineHeight - titleLabel.font.pointSize, (titleLabel.font.pointSize/2)*3, titleLabel.font.pointSize);
    }
}

- (NSString *)accessibilityLabelForContent {
    return [NSString stringWithFormat:@"%@, %@", titleLabel.text, descriptionLabel.text];
}

- (void)setMessage:(BaseMessage *)newMessage {
    [super setMessage:newMessage];
    
    NSError *error;
    SystemMessage *systemMessage = (SystemMessage *)self.message;
    if (systemMessage.arg) {
        NSDictionary *argDict = [NSJSONSerialization JSONObjectWithData:systemMessage.arg options:NSJSONReadingAllowFragments error:&error];
        if (error) {
            self.message.isOwn = @0;
        } else {
            self.message.isOwn = argDict[@"CallInitiator"];
        }
    } else {
        self.message.isOwn = @1;
    }
    
    NSString *spaces = @"";
    for (int i = 0; i < (titleLabel.font.pointSize / 2.2); i++) {
        spaces = [NSString stringWithFormat:@"%@ ", spaces];
    }
    
    titleText = [NSString stringWithFormat:@"%@%@",spaces, [systemMessage format]];
    descriptionText = systemMessage.callDetail;
    if (descriptionText == nil || descriptionText.length == 0) {
        descriptionText = @" ";
    }
    
    titleLabel.font = [UIFont boldSystemFontOfSize:[ChatMessageCell textFontSize]];
    descriptionLabel.font = [UIFont systemFontOfSize:[ChatMessageCell textFontSize] - 2.0];
    
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithAttributedString:[titleLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:titleText withFont:titleLabel.font textColor:nil isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]]]];
    
    switch ([systemMessage.type integerValue]) {
        case kSystemMessageCallEnded:
            if (systemMessage.haveCallTime) {
                if (!self.message.isOwn.boolValue) {
                    callIcon.image = [UIImage imageNamed:@"CallDownGreen" inColor:Colors.green];
                } else {
                    callIcon.image = [UIImage imageNamed:@"CallUpGreen" inColor:Colors.green];
                }
            } else {
                if (!self.message.isOwn.boolValue) {
                    callIcon.image = [UIImage imageNamed:@"CallLeftRed"];
                } else {
                    callIcon.image = [UIImage imageNamed:@"CallUpRed"];
                }
            }
            break;
        case kSystemMessageCallRejected:
            if (!self.message.isOwn.boolValue) {
                callIcon.image = [UIImage imageNamed:@"CallLeftOrange"];
            } else {
                callIcon.image = [UIImage imageNamed:@"CallRightRed"];
            }
            break;
        case kSystemMessageCallRejectedBusy:
            if (!self.message.isOwn.boolValue) {
                callIcon.image = [UIImage imageNamed:@"CallLeftRed"];
            } else {
                callIcon.image = [UIImage imageNamed:@"CallRightRed"];
            }
            break;
        case kSystemMessageCallRejectedTimeout:
            if (!self.message.isOwn.boolValue) {
                callIcon.image = [UIImage imageNamed:@"CallLeftRed"];
            } else {
                callIcon.image = [UIImage imageNamed:@"CallRightRed"];
            }
            break;
        case kSystemMessageCallRejectedDisabled:
            callIcon.image = [UIImage imageNamed:@"CallRightRed"];
            break;
        case kSystemMessageCallMissed:
            callIcon.image = [UIImage imageNamed:@"CallLeftRed"];
            break;
        default:
            callIcon.image = [UIImage imageNamed:@"CallUpGreen" inColor:Colors.green];
            break;
    }
    
    titleLabel.attributedText = titleString;
    
    descriptionLabel.attributedText = [descriptionLabel applyMarkupFor:[TextStyleUtils makeAttributedStringFromString:descriptionText withFont:descriptionLabel.font textColor:nil isOwn:self.message.isOwn.boolValue application:[UIApplication sharedApplication]]];
    if (self.message.isOwn.boolValue) {
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        descriptionLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    } else {
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        descriptionLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    }
    
    cellElement = nil;
    
    [self setNeedsLayout];
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


#pragma mark - Private functions

+ (NSAttributedString*)attachmentWithImage:(UIImage*)attachment label:(UILabel *)label boundsImage:(BOOL)boundsImage {
    NSTextAttachment* textAttachment = [[NSTextAttachment alloc] initWithData:nil ofType:nil];
    textAttachment.image = attachment;
    if (boundsImage) {
        textAttachment.bounds = CGRectMake(0.0, -label.font.pointSize/6, label.font.pointSize, label.font.pointSize);
    }
    
    NSAttributedString* string = [NSAttributedString attributedStringWithAttachment:textAttachment];
    return string;
}

- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self];
    if (CGRectContainsPoint(self.msgBackground.frame, p) && [UserSettings sharedUserSettings].enableThreemaCall) {
        if (gestureRecognizer.state == UIGestureRecognizerStateEnded && self.editing == NO) {
            [self showAlert];
        } else {
            [self selectOrDeselectCellForGestureRecognizer:gestureRecognizer];
        }
    } else {
        if (self.editing) {
            [self selectOrDeselectCellForGestureRecognizer:gestureRecognizer];
        }
    }
}

- (void)selectOrDeselectCellForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    UITableView *tableView = (UITableView *)self.superview;
    CGPoint p2 = [gestureRecognizer locationInView:tableView];
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:p2];
    
    if (indexPath != nil) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        
        if (cell != nil) {
            if (cell.selected) {
                [tableView deselectRowAtIndexPath:indexPath animated:NO];
                [((Old_ChatTableDataSource *) tableView.dataSource) tableView:tableView didDeselectRowAtIndexPath:indexPath];
            } else {
                [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
                [((Old_ChatTableDataSource *) tableView.dataSource) tableView:tableView didSelectRowAtIndexPath:indexPath];
            }
        }
    }
}

- (void)showAlert {
    if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
        NSInteger state = [[VoIPCallStateManager shared] currentCallState];
        if(state != CallStateIdle) {
            NSString *message = [BundleUtil localizedStringForKey:@"already_in_call"];
            UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
            [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"ok"] style:UIAlertActionStyleCancel handler:nil]];
            [self.chatVc presentViewController:errAlert animated:YES completion:nil];
            return;
        }
        NSString *message = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"call_contact_alert"], self.chatVc.conversation.contact.displayName];
        
        UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
        [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"call"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
            [self.chatVc startVoipCall:false];
        }]];
        [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:nil]];
        [self.chatVc presentViewController:errAlert animated:YES completion:nil];
    } else {
        // Alert no internet connection
        NSString *title = [BundleUtil localizedStringForKey:@"cannot_connect_title"];
        NSString *message = [BundleUtil localizedStringForKey:@"cannot_connect_message"];
        [UIAlertTemplate showAlertWithOwner:self.chatVc title:title message:message actionOk:nil];
    }
}

#pragma mark - Override functions

- (void)updateStatusImage {
    self.statusImage.hidden = YES;
    
    [self setNeedsLayout];
}

- (UIImage*)bubbleImageWithHighlight:(BOOL)bubbleHighlight {
    if (self.shouldHideBubbleBackground) {
        return nil;
    }
    
    if (self.message.isOwn.boolValue) {
        NSString *name = @"ChatBubbleSentMask";
        if (bubbleHighlight) {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleSent] stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        } else {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleSent] stretchableImageWithLeftCapWidth:15 topCapHeight:13];
        }
    } else {
        NSString *name = @"ChatBubbleReceivedMask";
        if (bubbleHighlight) {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleReceived] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        } else {
            return [[UIImage imageNamed:name inColor:Colors.chatBubbleReceived] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
        }
    }
}

- (void)setBubbleContentSize:(CGSize)size {
    CGFloat bgWidthMargin = 34.0f;
    CGFloat bgHeightMargin = 16.0f;
    CGFloat callImageWidth = 40.0f;
    
    self.bubbleSize = CGSizeMake(size.width+bgWidthMargin+callImageWidth, size.height+bgHeightMargin);
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(deleteMessage:)) {
        return YES;
    } else {
        return NO;
    }
}

- (NSString *)textForQuote {
    return titleText;
}


#pragma mark - ZSWTappableLabel delegate

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel tappedAtIndex:(NSInteger)idx withAttributes:(NSDictionary *)attributes {
}

- (void)tappableLabel:(ZSWTappableLabel *)tappableLabel longPressedAtIndex:(NSInteger)idx withAttributes:(NSDictionary<NSString *,id> *)attributes {
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.editing) {
        // don't event forward to label
        return self;
    }
    
    return [super hitTest:point withEvent:event];
}


#pragma mark - UIAccessibilityContainer

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSInteger)accessibilityElementCount {
    return [titleLabel accessibilityElementCount]+1;
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    // Fake an additional last element that encompasses the entire cell
    // and adds additional information about the message.
    if (index == ([titleLabel accessibilityElementCount])) {
        return [self cellElement];
    } else {
        return [titleLabel accessibilityElementAtIndex:index];
    }
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    if (element == [self cellElement])
        return [titleLabel accessibilityElementCount];
    else
        return [titleLabel indexOfAccessibilityElement:element];
}

- (UIAccessibilityElement*)cellElement {
    if (cellElement == nil) {
        cellElement = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
        cellElement.accessibilityLabel = [self accessibilityLabel];
        cellElement.accessibilityTraits = UIAccessibilityTraitStaticText;
    }
    cellElement.accessibilityFrame = [self convertRect:self.bounds toView:nil];
    return cellElement;
}

@end
