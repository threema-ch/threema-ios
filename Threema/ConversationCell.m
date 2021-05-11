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

#import <QuartzCore/QuartzCore.h>

#import "ConversationCell.h"
#import "Conversation.h"
#import "Contact.h"
#import "SystemMessage.h"
#import "Utils.h"
#import "AvatarMaker.h"
#import "UIImage+ColoredImage.h"
#import "BaseMessage+Accessibility.h"
#import "BundleUtil.h"
#import "UILabel+Markup.h"
#import "MessageDraftStore.h"
#import "ConversationUtils.h"
#import "ChatCallMessageCell.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "TextStyleUtils.h"
#import "PushSetting.h"
#import "GroupProxy.h"

@interface ConversationCell ()

@property BOOL showStatusIcon;
@property PushSetting *pushSetting;

@end

@implementation ConversationCell

@synthesize conversation;

- (void)dealloc {
    [self removeObservers];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    /* very minor adjustment to make base lines of name, date and draft align on Retina displays */
    if ([UIScreen mainScreen].scale == 2.0) {
        self.dateLabel.frame = CGRectOffset(self.dateLabel.frame, 0, -0.5);
        self.draftLabel.frame = CGRectOffset(self.draftLabel.frame, 0, -0.5);
    }
    
    self.draftLabel.text = self.draftLabel.text.uppercaseString;
    
    _threemaTypeIcon.image = [Utils threemaTypeIcon];
    
    self.messagePreviewLabel.userInteractionEnabled = NO;
    
    self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    
    [self setupColors];
}

- (void)setupColors {
    [Colors updateTableViewCellBackground:self];
    
    if (conversation.groupId == nil && (conversation.contact.state.intValue == kStateInactive || conversation.contact.state.intValue == kStateInvalid)) {
        self.nameLabel.textColor = [Colors fontLight];
        self.nameLabel.highlightedTextColor = [Colors fontLight];
    } else {
        self.nameLabel.textColor = [Colors fontNormal];
        self.nameLabel.highlightedTextColor = [Colors fontNormal];
    }
    
    [self.messagePreviewLabel setTextColor:[Colors fontLight]];
    self.messagePreviewLabel.highlightedTextColor = [Colors fontLight];
    [self.dateLabel setTextColor:[Colors fontLight]];
    self.dateLabel.highlightedTextColor = [Colors fontLight];
    
    self.markedView.backgroundColor = [Colors markTag];
    
    if (@available(iOS 11.0, *)) {
        _contactImage.accessibilityIgnoresInvertColors = true;
        _threemaTypeIcon.image = [Utils threemaTypeIcon];
    }
    
    _typingIndicator.image = [UIImage imageNamed:@"Typing" inColor:[Colors fontLight]];
}

- (void)removeObservers {
    [conversation removeObserver:self forKeyPath:@"typing"];
    [conversation removeObserver:self forKeyPath:@"lastMessage"];
    [conversation removeObserver:self forKeyPath:@"unreadMessageCount"];
    [conversation removeObserver:self forKeyPath:@"lastMessage.reverseGeocodingResult"];
    [conversation removeObserver:self forKeyPath:@"lastMessage.userack"];
    [conversation removeObserver:self forKeyPath:@"lastMessage.read"];
    [conversation removeObserver:self forKeyPath:@"lastMessage.delivered"];
    [conversation removeObserver:self forKeyPath:@"lastMessage.sendfailed"];
    [conversation removeObserver:self forKeyPath:@"lastMessage.sent"];
    [conversation removeObserver:self forKeyPath:@"groupName"];
    [conversation removeObserver:self forKeyPath:@"members"];
    [conversation removeObserver:self forKeyPath:@"contact.displayName"];
    [conversation removeObserver:self forKeyPath:@"contact.imageData"];
    [conversation removeObserver:self forKeyPath:@"groupImage"];
    [conversation removeObserver:self forKeyPath:@"contact.contactImage"];
    [conversation removeObserver:self forKeyPath:@"tags"];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)setConversation:(Conversation *)newConversation {
    
    if (conversation == newConversation) {
        [self setupColors];
        [self updateDateLabel];
        [self updateContactImage];
        [self updateLastMessagePreview];
        [self updateThreemaTypeIcon];
        [self updateName];
        [self updateTagsView];
        [self updateNotificationIcon];
                
        return;
    }
    
    [self removeObservers];
    
    conversation = newConversation;
    
    /* observe this conversation as the last message text could change */
    [conversation addObserver:self forKeyPath:@"typing" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"unreadMessageCount" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.reverseGeocodingResult" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.userack" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.read" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.delivered" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.sendfailed" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.sent" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"groupName" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"members" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"contact.displayName" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"contact.imageData" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"groupImage" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"contact.contactImage" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"tags" options:0 context:nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avatarChanged:) name:kNotificationIdentityAvatarChanged object:nil];
    
    [self updateName];
    
    [self updateLastMessagePreview];
    [self updateDateLabel];
    
    [self updateBadgeView];
    [self updateContactImage];
    [self updateTypingIndicator];
    
    [self setupColors];
    
    [self updateThreemaTypeIcon];
    
    [self updateTagsView];
    
    [self updateNotificationIcon];
}

- (void)updateLastMessagePreview {
    BaseMessage *lastMessage = conversation.lastMessage;
    
    NSString *messageTextForPreview = [lastMessage previewText];
    if (messageTextForPreview == nil) {
        messageTextForPreview = @"";
    }
    
    if (conversation.groupId != nil) {        
        self.statusIcon.image = [UIImage imageNamed:@"MessageStatus_group" inColor:[Colors fontLight]];
        self.statusIcon.highlightedImage = self.statusIcon.image;
        self.statusIcon.alpha = 1.0;
        self.statusIcon.hidden = NO;
    } else {
        NSString *iconName;
        UIColor *color = [Colors fontLight];
        
        if ([self isSystemCallMessage:lastMessage]) {
            iconName = @"call";
        }
        else {
            if (lastMessage.isOwn.boolValue && conversation.contact.isGatewayId == NO) {
                if (lastMessage.userackDate) {
                    if (lastMessage.userack.boolValue) {
                        iconName = @"thumb_up";
                        color = [Colors green];
                    } else if (lastMessage.userack.boolValue == NO) {
                        iconName = @"thumb_down";
                        color = [Colors orange];
                    }
                } else if (lastMessage.read.boolValue) {
                    iconName = @"read";
                } else if (lastMessage.delivered.boolValue) {
                    iconName = @"delivered";
                } else if (lastMessage.sendFailed.boolValue) {
                    iconName = @"sendfailed";
                    color = [Colors red];
                } else {
                    if (lastMessage.sent.boolValue) {
                        iconName = @"sent";
                    } else {
                        iconName = @"sending";
                    }
                }
            }
            else if (lastMessage == nil) {
                iconName = nil;
            }
            else if (!lastMessage.isOwn.boolValue && conversation.contact.isGatewayId == NO) {
                iconName = @"reply";
                if (lastMessage.userackDate) {
                    if (lastMessage.userack.boolValue) {
                        color = [Colors green];
                    } else if (lastMessage.userack.boolValue == NO) {
                        color = [Colors orange];
                    }
                }
            }
        }
        
        if ((iconName && [self isSystemCallMessage:lastMessage]) || (iconName && ![lastMessage isKindOfClass:[SystemMessage class]])) {
            if ([iconName isEqualToString:@"sendfailed"]) {
                self.statusIcon.image = [UIImage imageNamed:[NSString stringWithFormat:@"MessageStatus_%@", iconName]];
            }
            else if ([iconName isEqualToString:@"call"]) {
                self.statusIcon.image = [UIImage imageNamed:@"ThreemaPhone" inColor:color];
            }
            else if ([iconName isEqualToString:@"thumb_up"]) {
                self.statusIcon.image = [[UIImage imageNamed:@"hand.thumbsup.fill_regular.S" inColor:color] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            else if ([iconName isEqualToString:@"thumb_down"]) {
                self.statusIcon.image = [[UIImage imageNamed:@"hand.thumbsdown.fill_regular.S" inColor:color] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
            }
            else {
                self.statusIcon.image = [UIImage imageNamed:[NSString stringWithFormat:@"MessageStatus_%@", iconName] inColor:color];
            }
            self.statusIcon.highlightedImage = self.statusIcon.image;
            self.statusIcon.alpha = 1.0;
            self.statusIcon.hidden = NO;
        } else {
            self.statusIcon.hidden = YES;
        }
    }
    
    NSString *orgDraftMessage = [MessageDraftStore loadDraftForConversation:self.conversation];
    int maxLength = MIN((int)orgDraftMessage.length - 1, 100);
    NSString *draftMessage = [orgDraftMessage substringToIndex:NSMaxRange([orgDraftMessage rangeOfComposedCharacterSequenceAtIndex:maxLength])];
    NSAttributedString *attributedString;
    if (draftMessage) {
        self.dateLabel.hidden = YES;
        self.draftLabel.hidden = NO;
        
        NSAttributedString *draftAttributed = [TextStyleUtils makeAttributedStringFromString:draftMessage withFont:self.messagePreviewLabel.font textColor:[Colors fontLight] isOwn:true application:[UIApplication sharedApplication]];
        NSMutableAttributedString *formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.messagePreviewLabel applyMarkupFor:draftAttributed]];
        attributedString = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:self.messagePreviewLabel.font atColor:[[Colors fontLight] colorWithAlphaComponent:0.6] messageInfo:TextStyleUtilsMessageInfoOverview application:[UIApplication sharedApplication]];
        self.messagePreviewLabel.attributedText = attributedString;
        if (conversation.groupId == nil) {
            self.statusIcon.hidden = YES;
        }
        
        _draftLabel.textAlignment = [draftMessage textAlignment];
    } else {
        self.dateLabel.hidden = NO;
        self.draftLabel.hidden = YES;
        NSString *editedString;
        if ([self isSystemCallMessage:lastMessage]) {
            NSString *spaces = @"";
            for (int i = 0; i < (self.messagePreviewLabel.font.pointSize / 2.2); i++) {
                spaces = [NSString stringWithFormat:@"%@ ", spaces];
            }
            editedString = [NSString stringWithFormat:@"%@%@",spaces, messageTextForPreview];
        } else {
            editedString = messageTextForPreview;
        }
        
        NSMutableAttributedString *formattedAttributeString;
        NSString *contactString;
        NSMutableAttributedString *messageAttributeString;
        if (conversation.groupId != nil) {
            if (lastMessage != nil && ![lastMessage isKindOfClass:[SystemMessage class]]) {
                if (lastMessage.sender == nil) {
                    contactString = [[NSString alloc] initWithFormat:@"%@: ", [BundleUtil localizedStringForKey:@"me"]];
                } else {
                    contactString = [[NSString alloc] initWithFormat:@"%@: ", lastMessage.sender.displayName];
                }
            }
            
            NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:editedString withFont:self.messagePreviewLabel.font textColor:[Colors fontLight] isOwn:true application:[UIApplication sharedApplication]];
            messageAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.messagePreviewLabel applyMarkupFor:attributed]];
            NSAttributedString *attributedContact = [TextStyleUtils makeAttributedStringFromString:contactString withFont:self.messagePreviewLabel.font textColor:[Colors fontLight] isOwn:true application:[UIApplication sharedApplication]];
            formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedContact];
            [formattedAttributeString appendAttributedString:messageAttributeString];
        } else {
            NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:editedString withFont:self.messagePreviewLabel.font textColor:[Colors fontLight] isOwn:true application:[UIApplication sharedApplication]];
            formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.messagePreviewLabel applyMarkupFor:attributed]];
        }
        
        self.messagePreviewLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:self.messagePreviewLabel.font atColor:[[Colors fontLight] colorWithAlphaComponent:0.6] messageInfo:TextStyleUtilsMessageInfoOverview application:[UIApplication sharedApplication]];
        self.messagePreviewLabel.textAlignment = [editedString textAlignment];
    }
    
    
    if ([self isSystemCallMessage:lastMessage] && !draftMessage) {
        switch ([((SystemMessage *)lastMessage).type integerValue]) {
            case kSystemMessageCallEnded:
                if (((SystemMessage *)lastMessage).haveCallTime) {
                    if (!((SystemMessage *)lastMessage).isOwn.boolValue) {
                        _callImageView.image = [UIImage imageNamed:@"CallDownGreen" inColor:[Colors green]];
                    } else {
                        _callImageView.image = [UIImage imageNamed:@"CallUpGreen" inColor:[Colors green]];
                    }
                } else {
                    if (!((SystemMessage *)lastMessage).isOwn.boolValue) {
                        _callImageView.image = [UIImage imageNamed:@"CallLeftRed"];
                    } else {
                        _callImageView.image = [UIImage imageNamed:@"CallUpRed"];
                    }
                }
                break;
            case kSystemMessageCallRejected:
                if (!((SystemMessage *)lastMessage).isOwn.boolValue) {
                    _callImageView.image = [UIImage imageNamed:@"CallLeftOrange"];
                } else {
                    _callImageView.image = [UIImage imageNamed:@"CallRightRed"];
                }
                break;
            case kSystemMessageCallRejectedBusy:
                if (!((SystemMessage *)lastMessage).isOwn.boolValue) {
                    _callImageView.image = [UIImage imageNamed:@"CallLeftRed"];
                } else {
                    _callImageView.image = [UIImage imageNamed:@"CallRightRed"];
                }
                break;
            case kSystemMessageCallRejectedTimeout:
                if (!((SystemMessage *)lastMessage).isOwn.boolValue) {
                    _callImageView.image = [UIImage imageNamed:@"CallLeftRed"];
                } else {
                    _callImageView.image = [UIImage imageNamed:@"CallRightRed"];
                }
                break;
            case kSystemMessageCallRejectedDisabled:
                _callImageView.image = [UIImage imageNamed:@"CallRightRed"];
                break;
            case kSystemMessageCallMissed:
                _callImageView.image = [UIImage imageNamed:@"CallLeftRed"];
                break;
            default:
                _callImageView.image = [UIImage imageNamed:@"CallUpGreen" inColor:[Colors green]];
                break;
        }
        
        _callImageHeight.constant = self.messagePreviewLabel.font.pointSize * 1.2;
        _callImageView.hidden = NO;
    } else {
        _callImageView.hidden = YES;
    }
    
    _showStatusIcon = self.statusIcon.hidden == NO;
    
    // make sure typing indicator is in sync
    [self updateTypingIndicator];
}

- (void)updateDateLabel {
    BaseMessage *lastMessage = conversation.lastMessage;
    if (lastMessage.userackDate && lastMessage.isOwn.boolValue) {
        self.dateLabel.text = [Utils formatShortLastMessageDate:conversation.lastMessage.userackDate];
    } else if (lastMessage.read.boolValue && lastMessage.isOwn.boolValue) {
        self.dateLabel.text = [Utils formatShortLastMessageDate:conversation.lastMessage.readDate];
    } else if (lastMessage.delivered.boolValue && lastMessage.isOwn.boolValue) {
        self.dateLabel.text = [Utils formatShortLastMessageDate:conversation.lastMessage.deliveryDate];
    } else {
        self.dateLabel.text = [Utils formatShortLastMessageDate:conversation.lastMessage.remoteSentDate];
    }
}

- (void)updateContactImage {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.contactImage.image = [BundleUtil imageNamed:@"Unknown"];
    });
    
    [[AvatarMaker sharedAvatarMaker] avatarForConversation:conversation size:56.0f masked:YES onCompletion:^(UIImage *avatarImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contactImage.image = avatarImage;
        });
    }];
}

- (void)updateBadgeView {
    int badgeCount = conversation.unreadMessageCount.intValue;
    if (badgeCount > 0) {
        self.badgeView.alignment = NSTextAlignmentCenter;
        self.badgeView.font = [UIFont systemFontOfSize:13];
        self.badgeView.shadowOffset = CGSizeMake(1,1);
        self.badgeView.value = conversation.unreadMessageCount.intValue;
        self.badgeView.alpha = 1.0;
        self.badgeView.hidden = NO;
    } else {
        if (badgeCount == -1) {
            self.badgeView.alignment = NSTextAlignmentCenter;
            self.badgeView.font = [UIFont systemFontOfSize:13];
            self.badgeView.shadowOffset = CGSizeMake(1,1);
            self.badgeView.value = 0;
            self.badgeView.alpha = 1.0;
            self.badgeView.hidden = NO;
        } else {
            self.badgeView.alpha = 0.0;
            self.badgeView.hidden = YES;
        }
    }
}

- (void)updateTypingIndicator {
    
    if (conversation.typing.boolValue) {
        self.typingIndicator.alpha = 0.0;
        self.typingIndicator.hidden = NO;
        
        self.typingIndicator.alpha = 1.0;
        self.statusIcon.alpha = 0.0;
        self.statusIcon.hidden = YES;
    } else {
        if (_showStatusIcon) {
            self.statusIcon.hidden = NO;
        }
        
        self.typingIndicator.alpha = 0.0;
        self.statusIcon.alpha = 1.0;
        self.typingIndicator.hidden = YES;
    }
}

- (void)updateName {
    if (conversation.displayName) {
        if (conversation.groupId == nil && conversation.contact.state.intValue == kStateInvalid) {
            NSDictionary *strikethroughDict = @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleThick)};
            NSAttributedString *str = [[NSAttributedString alloc] initWithString:conversation.displayName attributes:strikethroughDict];
            if ([NSThread isMainThread]) {
                self.nameLabel.attributedText = str;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.nameLabel.attributedText = str;
                });
            }
        } else {
            NSMutableAttributedString *str = [[NSMutableAttributedString alloc] init];
            if ([[UserSettings sharedUserSettings].blacklist containsObject:conversation.contact.identity]) {
                [str appendAttributedString:[[NSAttributedString alloc] initWithString:@"🚫 " attributes:nil]];
            }
            [str appendAttributedString:[[NSAttributedString alloc] initWithString:conversation.displayName attributes:nil]];
            if ([NSThread isMainThread]) {
                self.nameLabel.attributedText = str;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.nameLabel.attributedText = str;
                });
            }
        }
    }
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleHeadline];
    CGFloat size = fontDescriptor.pointSize;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.nameLabel.font = [UIFont boldSystemFontOfSize:size];
    });
}

- (void)updateThreemaTypeIcon {
    if (self.conversation.isGroup) {
        _threemaTypeIcon.hidden = YES;
    } else {
        _threemaTypeIcon.hidden = [Utils hideThreemaTypeIconForContact:self.conversation.contact];
    }
}

- (void)updateTagsView {
    self.markedView.alpha = [conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]] ? 1.0 : 0.0;
}

- (void)updateNotificationIcon {
    _pushSetting = [PushSetting findPushSettingForConversation:conversation];
    UIImage *pushSettingIcon = nil;
    if (_pushSetting) {
        pushSettingIcon = [_pushSetting imageForEditedPushSetting];
    }
    if (pushSettingIcon != nil) {
        _notificationIcon.image = [pushSettingIcon imageWithTint:[Colors fontLight]];
        _notificationIcon.hidden = false;
    } else {
        _notificationIcon.image = nil;
        _notificationIcon.hidden = true;
    }
}

- (NSString *)accessibilityLabel {
    NSMutableString *text = [NSMutableString stringWithFormat:@"%@. ", self.nameLabel.text];
    
    if (_pushSetting) {
        if (_pushSetting.type == kPushSettingTypeOn && _pushSetting.silent) {
            [text appendFormat:@"%@ %@. ", NSLocalizedString(@"notification_sound_header", nil), NSLocalizedString(@"doNotDisturb_off", nil)];
        }
        else if (_pushSetting.type == kPushSettingTypeOff && !_pushSetting.mentions) {
            [text appendFormat:@"%@ %@. ", NSLocalizedString(@"doNotDisturb_title", nil), NSLocalizedString(@"doNotDisturb_on", nil)];
        }
        else if (_pushSetting.type == kPushSettingTypeOff && _pushSetting.mentions) {
            [text appendFormat:@"%@ %@, %@. ", NSLocalizedString(@"doNotDisturb_title", nil), NSLocalizedString(@"doNotDisturb_on", nil), NSLocalizedString(@"doNotDisturb_mention", @"")];
        }
        else if (_pushSetting.type == kPushSettingTypeOffPeriod && !_pushSetting.mentions) {
            [text appendFormat:@"%@ %@ %@. ", NSLocalizedString(@"doNotDisturb_title", nil), NSLocalizedString(@"doNotDisturb_onPeriod_time", nil), [DateFormatter getFullDateFor:_pushSetting.periodOffTillDate]];
        }
        else if (_pushSetting.type == kPushSettingTypeOffPeriod && _pushSetting.mentions) {
            [text appendFormat:@"%@ %@ %@, %@. ", NSLocalizedString(@"doNotDisturb_title", nil), NSLocalizedString(@"doNotDisturb_onPeriod_time", nil), [DateFormatter getFullDateFor:_pushSetting.periodOffTillDate], NSLocalizedString(@"doNotDisturb_mention", @"")];
        }
    }
    
    NSString *messagePreview = [conversation.lastMessage previewText];
    NSString *draftPreview = [MessageDraftStore loadDraftForConversation:self.conversation];
    if (draftPreview.length > 0) {
        [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"draft"]];
        if (conversation.unreadMessageCount.intValue > 0) {
            [text appendFormat:@"%@. ", NSLocalizedString(@"unread", nil)];
        }
        [text appendFormat:@"%@ ", [BundleUtil localizedStringForKey:@"from"]];
        [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"me"]];
        [text appendFormat:@"%@. ", draftPreview];
        [text appendFormat:@"%@. ", [conversation.lastMessage accessibilityMessageShortStatus]];
        return text;
    }
    
    [text appendFormat:@"%@. ", [conversation.lastMessage accessibilityMessageDate]];
    if (messagePreview.length > 0) {
        if (conversation.unreadMessageCount.intValue > 0) {
            [text appendFormat:@"%@. ", NSLocalizedString(@"unread", nil)];
        }
        [text appendFormat:@"%@ ", [BundleUtil localizedStringForKey:@"from"]];
        [text appendFormat:@"%@. ", [conversation.lastMessage accessibilityMessageSender]];
        [text appendFormat:@"%@. ", messagePreview];
        [text appendFormat:@"%@. ", [conversation.lastMessage accessibilityMessageShortStatus]];
    }
    
    if ([conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]]) {
        [text appendFormat:@"%@. ", NSLocalizedString(@"pinned_conversation", nil)];
    }
    
    return text;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (object == conversation) {
            if ([keyPath isEqualToString:@"lastMessage"]) {
                [self updateLastMessagePreview];
                [self updateDateLabel];
            } else if ([keyPath isEqualToString:@"contact.displayName"] || [keyPath isEqualToString:@"groupName"] || [keyPath isEqualToString:@"members"]) {
                [self updateName];
            } else if ([keyPath isEqualToString:@"contact.imageData"] || [keyPath isEqualToString:@"groupImage"] || [keyPath isEqualToString:@"contact.contactImage"]) {
                [self updateContactImage];
            } else if ([keyPath isEqualToString:@"typing"]) {
                [self updateTypingIndicator];
            } else if ([keyPath isEqualToString:@"unreadMessageCount"]) {
                [self updateBadgeView];
            } else if ([keyPath hasPrefix:@"lastMessage."]) {
                [self updateLastMessagePreview];
                [self updateDateLabel];
            } else if ([keyPath hasPrefix:@"tags"]) {
                [self updateTagsView];
            }
        }
    });
}

- (BOOL)isSystemCallMessage:(BaseMessage *)message {
    if ([message isKindOfClass:[SystemMessage class]]) {
        switch ([((SystemMessage *)message).type integerValue]) {
            case kSystemMessageCallEnded:
                return YES;
            case kSystemMessageCallRejected:
                return YES;
            case kSystemMessageCallRejectedBusy:
                return YES;
            case kSystemMessageCallRejectedTimeout:
                return YES;
            case kSystemMessageCallRejectedDisabled:
                return YES;
            case kSystemMessageCallMissed:
                return YES;
            case kSystemMessageCallRejectedUnknown:
                return YES;
            default:
                return NO;
        }
    }
    return NO;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [_messagePreviewLabel setHighlighted:NO];
}

- (void)voiceOverDeleteConversation {
    if ([_conversationCellDelegate respondsToSelector:@selector(voiceOverDeleteConversation:)]) {
        [_conversationCellDelegate voiceOverDeleteConversation:self];
    }
}

- (void)voiceOverLeaveGroup {
    if ([_conversationCellDelegate respondsToSelector:@selector(voiceOverLeaveGroup:)]) {
        [_conversationCellDelegate voiceOverLeaveGroup:self];
    }
}

- (void)voiceOverMarkConversation:(id)sender {
    [ConversationUtils markConversation:conversation];
}

- (void)voiceOverUnmarkConversation:(id)sender {
    [ConversationUtils unmarkConversation:conversation];
}

- (void)voiceOverReadMessage:(id)sender {
    [ConversationUtils unreadConversation:conversation];
}


#pragma mark - Accessibility

- (NSArray *)accessibilityCustomActions {
    UIAccessibilityCustomAction *readAction;
    UIAccessibilityCustomAction *markAction;
    NSMutableArray *actionArray = [NSMutableArray new];
    if (conversation.unreadMessageCount.intValue > 0) {
        readAction = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"read", @"") target:self selector:@selector(voiceOverReadMessage:)];
        [actionArray addObject:readAction];
    }
    if (conversation.marked.boolValue) {
        markAction = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"unpin", @"") target:self selector:@selector(voiceOverUnmarkConversation:)];
    } else {
        markAction = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"pin", @"") target:self selector:@selector(voiceOverMarkConversation:)];
    }
    [actionArray addObject:markAction];
    
    if (conversation.isGroup) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
        if ([group isSelfMember]) {
            UIAccessibilityCustomAction *leaveAction = [[UIAccessibilityCustomAction alloc] initWithName:[BundleUtil localizedStringForKey:@"leave_group"] target:self selector:@selector(voiceOverLeaveGroup)];
            [actionArray addObject:leaveAction];
        }
    }
    
    UIAccessibilityCustomAction *deleteAction = [[UIAccessibilityCustomAction alloc] initWithName:NSLocalizedString(@"delete", @"") target:self selector:@selector(voiceOverDeleteConversation)];
    [actionArray addObject:deleteAction];
    return actionArray;
}

#pragma mark - Notification

- (void)avatarChanged:(NSNotification*)notification
{
    if (notification.object && [conversation.contact.identity isEqualToString:notification.object] ) {
        [self updateContactImage];
    }
}

@end
