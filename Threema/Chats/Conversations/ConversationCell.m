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

#import <QuartzCore/QuartzCore.h>
#import "ConversationCell.h"
#import "Conversation.h"
#import "Contact.h"
#import "SystemMessage.h"
#import "ThreemaUtilityObjC.h"
#import "AvatarMaker.h"
#import "UIImage+ColoredImage.h"
#import "BaseMessage+Accessibility.h"
#import "BundleUtil.h"
#import "UILabel+Markup.h"
#import "MessageDraftStore.h"
#import "ChatCallMessageCell.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "TextStyleUtils.h"
#import "PushSetting.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

@interface ConversationCell ()

@property BOOL showStatusIcon;
@property PushSetting *pushSetting;
@property Group *group;
@property NSTimer *lastMessageIconsAndDateTimer;

@end

@implementation ConversationCell

@synthesize conversation;

- (void)dealloc {
    [self removeObservers];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    /* very minor adjustment to make base lines of name, date and draft align on Retina displays */
    if ([UIScreen mainScreen].scale == 2.0) {
        self.dateLabel.frame = CGRectOffset(self.dateLabel.frame, 0, -0.5);
        self.draftLabel.frame = CGRectOffset(self.draftLabel.frame, 0, -0.5);
    }
    
    self.draftLabel.text = self.draftLabel.text.uppercaseString;
    
    _threemaTypeIcon.image = [ThreemaUtilityObjC threemaTypeIcon];
    
    self.messagePreviewLabel.userInteractionEnabled = NO;
    
    self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
    
    [self updateColors];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    [self removeObservers];
}

- (void)updateColors {
    if (conversation.groupId == nil && (conversation.contact.state.intValue == kStateInactive || conversation.contact.state.intValue == kStateInvalid)) {
        self.nameLabel.textColor = Colors.textLight;
        self.nameLabel.highlightedTextColor = Colors.textLight;
    } else {
        self.nameLabel.textColor = Colors.text;
        self.nameLabel.highlightedTextColor = Colors.text;
    }
    
    _draftLabel.textColor = Colors.red;
    
    [self.messagePreviewLabel setTextColor:Colors.textLight];
    self.messagePreviewLabel.highlightedTextColor = Colors.textLight;
    self.dateLabel.textColor = Colors.textLight;
    self.dateLabel.highlightedTextColor = Colors.textLight;
    
    self.markedView.backgroundColor = Colors.backgroundPinChat;
    
    _contactImage.accessibilityIgnoresInvertColors = true;
    _threemaTypeIcon.image = [ThreemaUtilityObjC threemaTypeIcon];
    
    _typingIndicator.image = [UIImage imageNamed:@"Typing" inColor:Colors.textLight];
}

- (void)addObservers {
    /* observe this conversation as the last message text could change */
    [self addLastMessageObservers];
    [conversation addObserver:self forKeyPath:@"groupImage" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"contact.displayName" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"contact.imageData" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [conversation addObserver:self forKeyPath:@"contact.contactImage" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    [_group addObserver:self forKeyPath:@"state" options:0 context:nil];
    [[UserSettings sharedUserSettings] addObserver:self forKeyPath:@"pushSettingsList" options:0 context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avatarChanged:) name:kNotificationIdentityAvatarChanged object:nil];
    
    [self updateAllViewsAndReset:false];
}

- (void)addLastMessageObservers {
    [conversation addObserver:self forKeyPath:@"lastMessage.poiAddress" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.userack" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.read" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.delivered" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.sendfailed" options:0 context:nil];
    [conversation addObserver:self forKeyPath:@"lastMessage.sent" options:0 context:nil];
}

- (void)removeObservers {
    if (conversation != nil) {
        [self removeLastMessageObservers];
        @try{
            [conversation removeObserver:self forKeyPath:@"groupImage"];
            [conversation removeObserver:self forKeyPath:@"contact.displayName"];
            [conversation removeObserver:self forKeyPath:@"contact.imageData"];
            [conversation removeObserver:self forKeyPath:@"contact.contactImage"];
            [_group removeObserver:self forKeyPath:@"state"];
            [[UserSettings sharedUserSettings] removeObserver:self forKeyPath:@"pushSettingsList"];
        } @catch(id anException) {
            //do nothing, observer wasn't registered because an exception was thrown
            if ([anException isKindOfClass:[NSException class]]) {
                DDLogVerbose(@"Can't remove conversation observers: %@", [((NSException *)anException) description]);
            }
        }
    }
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)removeLastMessageObservers {
    @try{
        [conversation removeObserver:self forKeyPath:@"lastMessage.poiAddress"];
        [conversation removeObserver:self forKeyPath:@"lastMessage.userack"];
        [conversation removeObserver:self forKeyPath:@"lastMessage.read"];
        [conversation removeObserver:self forKeyPath:@"lastMessage.delivered"];
        [conversation removeObserver:self forKeyPath:@"lastMessage.sendfailed"];
        [conversation removeObserver:self forKeyPath:@"lastMessage.sent"];
    } @catch(id anException) {
        //do nothing, observer wasn't registered because an exception was thrown
        if ([anException isKindOfClass:[NSException class]]) {
            DDLogVerbose(@"Can't remove conversation lastMessage observers: %@", [((NSException *)anException) description]);
        }
    }
}

- (void)setConversation:(Conversation *)newConversation {
    
    if (conversation == newConversation) {
        [self updateAllViewsAndReset:false];
        return;
    }
    
    conversation = newConversation;
    EntityManager *entityManager = [[EntityManager alloc] init];
    GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
    _group = [groupManager getGroupWithConversation:conversation];
    
    [self updateAllViewsAndReset:true];
}

- (void)changedValuesForConversation:(NSDictionary *)changedValuesForCurrentEvent {
    
    if (changedValuesForCurrentEvent[@"lastMessage"] != nil) {
        [self removeLastMessageObservers];
        [self addLastMessageObservers];
        [self updateLastMessageIcons];
        [self updateLastMessagePreview];
        [self updateDateLabel];
    }
    if ([[changedValuesForCurrentEvent allKeys] containsObject:@"groupName"] || [[changedValuesForCurrentEvent allKeys] containsObject:@"members"]) {
        [self updateName];
    }
    if ([[changedValuesForCurrentEvent allKeys] containsObject:@"groupImage"] || [[changedValuesForCurrentEvent allKeys] containsObject:@"groupImageSetDate"]) {
        [self updateContactImageAndReset:true];
    }
    if ([[changedValuesForCurrentEvent allKeys] containsObject:@"typing"]) {
        [self updateTypingIndicator];
    }
    if ([[changedValuesForCurrentEvent allKeys] containsObject:@"unreadMessageCount"]) {
        [self updateBadgeView];
    }
    if ([[changedValuesForCurrentEvent allKeys] containsObject:@"tags"] || [[changedValuesForCurrentEvent allKeys] containsObject:@"marked"]) {
        [self updateTagsView];
    }
    if ([[changedValuesForCurrentEvent allKeys] containsObject:@"category"]) {
        [self updateLastMessageIcons];
        [self updateLastMessagePreview];
        [self updateDateLabel];
    }
}

- (void)updateAllViewsAndReset:(BOOL) reset {
    [self updateName];
    [self updateLastMessageIcons];
    [self updateLastMessagePreview];
    [self updateDateLabel];
    [self updateBadgeView];
    [self updateTypingIndicator];
    [self updateColors];
    [self updateThreemaTypeIcon];
    [self updateTagsView];
    [self updateBadgeView];
    [self updateContactImageAndReset:reset];
}

- (void)updateLastMessageIconsAndDate {
    [self updateLastMessageIcons];
    [self updateDateLabel];
}

- (void)updateLastMessageIcons {
    // If is PrivateChat, hide a lot of things
    if ([self handlePrivateConversation]) {
        return;
    }
    
    BaseMessage *lastMessage = conversation.lastMessage;
    if (conversation.isGroup) {
        self.statusIcon.image = [UIImage imageNamed:@"MessageStatus_group" inColor:Colors.textLight];
        self.statusIcon.highlightedImage = self.statusIcon.image;
        self.statusIcon.alpha = 1.0;
        self.statusIcon.hidden = NO;
    } else {
        NSString *iconName;
        UIColor *color = Colors.textLight;
        
        if ([self isSystemCallMessage:lastMessage]) {
            iconName = @"call";
        }
        else {
            if (lastMessage.isOwn.boolValue && conversation.contact.isGatewayId == NO) {
                if (lastMessage.userackDate) {
                    if (lastMessage.userack.boolValue) {
                        iconName = @"thumb_up";
                        color = Colors.thumbUp;
                    } else if (lastMessage.userack.boolValue == NO) {
                        iconName = @"thumb_down";
                        color = Colors.thumbDown;
                    }
                } else if (lastMessage.read.boolValue) {
                    iconName = @"read";
                } else if (lastMessage.delivered.boolValue) {
                    iconName = @"delivered";
                } else if (lastMessage.sendFailed.boolValue) {
                    iconName = @"sendfailed";
                    color = Colors.red;
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
                        color = Colors.thumbUp;
                    } else if (lastMessage.userack.boolValue == NO) {
                        color = Colors.thumbDown;
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
            self.statusIcon.alpha = _typingIndicator.hidden ? 1.0 : 0.0;
            self.statusIcon.hidden = NO;
        } else {
            self.statusIcon.hidden = YES;
        }
    }
    
    [self updateNotificationIcon];
}

- (BOOL)handlePrivateConversation {
    if (conversation.conversationCategory == ConversationCategoryPrivate) {
        self.callImageView.hidden = YES;
        self.statusIcon.image = [BundleUtil imageNamed:@"lock.fill_regular.S"];
        self.statusIcon.highlightedImage = [BundleUtil imageNamed:@"lock.fill_regular.S"];
        self.statusIcon.tintColor = [Colors textLight];
        self.statusIcon.hidden = NO;
        self.draftLabel.hidden = YES;
        self.messagePreviewLabel.text = [BundleUtil localizedStringForKey:@"private_chat_label"];
        self.messagePreviewLabel.textColor = [Colors textLight];
        return true;
    }
    return false;
}

- (void)updateLastMessagePreview {
    BaseMessage *lastMessage = conversation.lastMessage;
    
    // If is PrivateChat, hide a lot of things
    if ([self handlePrivateConversation]) {
        return;
    }
    
    NSString *messageTextForPreview = [lastMessage previewText];
    if (messageTextForPreview == nil) {
        messageTextForPreview = @"";
    }
        
    NSString *orgDraftMessage = [MessageDraftStore loadDraftForConversation:self.conversation];
    int maxLength = MIN((int)orgDraftMessage.length - 1, 100);
    NSString *draftMessage = [orgDraftMessage substringToIndex:NSMaxRange([orgDraftMessage rangeOfComposedCharacterSequenceAtIndex:maxLength])];
    NSAttributedString *attributedString;
    if (draftMessage) {
        self.dateLabel.hidden = YES;
        self.draftLabel.hidden = NO;
        
        NSAttributedString *draftAttributed = [TextStyleUtils makeAttributedStringFromString:draftMessage withFont:self.messagePreviewLabel.font textColor:Colors.textLight isOwn:true application:[UIApplication sharedApplication]];
        NSMutableAttributedString *formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.messagePreviewLabel applyMarkupFor:draftAttributed]];
        attributedString = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:self.messagePreviewLabel.font atColor:[Colors.textLight colorWithAlphaComponent:0.6] messageInfo:TextStyleUtilsMessageInfoOverview application:[UIApplication sharedApplication]];
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
            
            NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:editedString withFont:self.messagePreviewLabel.font textColor:Colors.textLight isOwn:true application:[UIApplication sharedApplication]];
            messageAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.messagePreviewLabel applyMarkupFor:attributed]];
            NSAttributedString *attributedContact = [TextStyleUtils makeAttributedStringFromString:contactString withFont:self.messagePreviewLabel.font textColor:Colors.textLight isOwn:true application:[UIApplication sharedApplication]];
            formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedContact];
            [formattedAttributeString appendAttributedString:messageAttributeString];
        } else {
            NSAttributedString *attributed = [TextStyleUtils makeAttributedStringFromString:editedString withFont:self.messagePreviewLabel.font textColor:Colors.textLight isOwn:true application:[UIApplication sharedApplication]];
            formattedAttributeString = [[NSMutableAttributedString alloc] initWithAttributedString:[self.messagePreviewLabel applyMarkupFor:attributed]];
        }
        
        self.messagePreviewLabel.attributedText = [TextStyleUtils makeMentionsAttributedStringForAttributedString:formattedAttributeString textFont:self.messagePreviewLabel.font atColor:[Colors.textLight colorWithAlphaComponent:0.6] messageInfo:TextStyleUtilsMessageInfoOverview application:[UIApplication sharedApplication]];
        self.messagePreviewLabel.textAlignment = [editedString textAlignment];
    }
    
    if ([self isSystemCallMessage:lastMessage] && !draftMessage) {
        switch ([((SystemMessage *)lastMessage).type integerValue]) {
            case kSystemMessageCallEnded:
                if (((SystemMessage *)lastMessage).haveCallTime) {
                    if (!((SystemMessage *)lastMessage).isOwn.boolValue) {
                        _callImageView.image = [UIImage imageNamed:@"CallDownGreen" inColor:Colors.green];
                    } else {
                        _callImageView.image = [UIImage imageNamed:@"CallUpGreen" inColor:Colors.green];
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
                _callImageView.image = [UIImage imageNamed:@"CallUpGreen" inColor:Colors.green];
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
        self.dateLabel.text = [ThreemaUtilityObjC formatShortLastMessageDate:conversation.lastMessage.userackDate];
    } else if (lastMessage.read.boolValue && lastMessage.isOwn.boolValue) {
        self.dateLabel.text = [ThreemaUtilityObjC formatShortLastMessageDate:conversation.lastMessage.readDate];
    } else if (lastMessage.delivered.boolValue && lastMessage.isOwn.boolValue) {
        self.dateLabel.text = [ThreemaUtilityObjC formatShortLastMessageDate:conversation.lastMessage.deliveryDate];
    } else {
        self.dateLabel.text = [ThreemaUtilityObjC formatShortLastMessageDate:conversation.lastMessage.remoteSentDate];
    }
    
    if (conversation.conversationCategory == ConversationCategoryPrivate) {
        self.dateLabel.text = nil;
    }
}

- (void)updateContactImageAndReset:(BOOL) reset {
    // To avoid switching from the correct image to the unknown image to the correct image we only display the unknown image on first use
    if (self.contactImage.image == nil || reset) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contactImage.image = [BundleUtil imageNamed:@"Unknown"];
        });
    }
    
    [[AvatarMaker sharedAvatarMaker] avatarForConversation:conversation size:56.0f masked:YES onCompletion:^(UIImage *avatarImage, NSManagedObjectID *objectID) {
        if (conversation.objectID == objectID) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.contactImage.image = avatarImage;
            });
        }
        else if ([objectID isTemporaryID]) {
            [self updateContactImageAndReset:false];
        }
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
    if (conversation.typing.boolValue && !(conversation.conversationCategory == ConversationCategoryPrivate)) {
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
        NSMutableAttributedString *str = nil;
        if (conversation.groupId == nil && conversation.contact.state.intValue == kStateInvalid) {
            NSDictionary *strikethroughDict = @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleThick)};
            str = [[NSMutableAttributedString alloc] initWithString:conversation.displayName attributes:strikethroughDict];
        }
        else if ([[UserSettings sharedUserSettings].blacklist containsObject:conversation.contact.identity]) {
            str = [[NSMutableAttributedString alloc] init];
            [str appendAttributedString:[[NSAttributedString alloc] initWithString:@"🚫 " attributes:nil]];
            [str appendAttributedString:[[NSAttributedString alloc] initWithString:conversation.displayName attributes:nil]];
        }
        else if (conversation.isGroup) {
            NSDictionary *strikethroughDict = nil; @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleThick)};
            if (!_group.isSelfMember) {
                strikethroughDict = @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleThick)};
            }
            str = [[NSMutableAttributedString alloc] initWithString:conversation.displayName attributes:strikethroughDict];
        }
        else {
            str = [[NSMutableAttributedString alloc] initWithString:conversation.displayName];
        }
        
        if ([NSThread isMainThread]) {
            self.nameLabel.attributedText = str;
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.nameLabel.attributedText = str;
            });
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
        _threemaTypeIcon.hidden = [ThreemaUtilityObjC hideThreemaTypeIconForContact:self.conversation.contact];
    }
}

- (void)updateTagsView {
    self.markedView.alpha = [conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]] ? 1.0 : 0.0;
}

- (void)updateNotificationIcon {
    _pushSetting = [PushSetting pushSettingForConversation:conversation];
    UIImage *pushSettingIcon = [_pushSetting imageForEditedPushSetting];
    if (pushSettingIcon != nil) {
        _notificationIcon.image = [pushSettingIcon imageWithTint:Colors.textLight];
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
            [text appendFormat:@"%@ %@. ", [BundleUtil localizedStringForKey:@"notification_sound_header"], [BundleUtil localizedStringForKey:@"doNotDisturb_off"]];
        }
        else if (_pushSetting.type == kPushSettingTypeOff && !_pushSetting.mentions) {
            [text appendFormat:@"%@ %@. ", [BundleUtil localizedStringForKey:@"doNotDisturb_title"], [BundleUtil localizedStringForKey:@"doNotDisturb_on"]];
        }
        else if (_pushSetting.type == kPushSettingTypeOff && _pushSetting.mentions) {
            [text appendFormat:@"%@ %@, %@. ", [BundleUtil localizedStringForKey:@"doNotDisturb_title"], [BundleUtil localizedStringForKey:@"doNotDisturb_on"], [BundleUtil localizedStringForKey:@"doNotDisturb_mention"]];
        }
        else if (_pushSetting.type == kPushSettingTypeOffPeriod && !_pushSetting.mentions) {
            [text appendFormat:@"%@ %@ %@. ", [BundleUtil localizedStringForKey:@"doNotDisturb_title"], [BundleUtil localizedStringForKey:@"doNotDisturb_onPeriod_time"], [DateFormatter getFullDateFor:_pushSetting.periodOffTillDate]];
        }
        else if (_pushSetting.type == kPushSettingTypeOffPeriod && _pushSetting.mentions) {
            [text appendFormat:@"%@ %@ %@, %@. ", [BundleUtil localizedStringForKey:@"doNotDisturb_title"], [BundleUtil localizedStringForKey:@"doNotDisturb_onPeriod_time"], [DateFormatter getFullDateFor:_pushSetting.periodOffTillDate], [BundleUtil localizedStringForKey:@"doNotDisturb_mention"]];
        }
    }
    
    NSString *messagePreview = [conversation.lastMessage previewText];
    NSString *draftPreview = [MessageDraftStore loadDraftForConversation:self.conversation];
    if (draftPreview.length > 0) {
        
        
        if (conversation.conversationCategory == ConversationCategoryPrivate) {
            [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"private_chat_accessibility"]];
            if (conversation.unreadMessageCount.intValue > 0) {
                [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"unread"]];
            }
            return text;
        }
        
        if (conversation.unreadMessageCount.intValue > 0) {
            [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"unread"]];
        }
                
        [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"draft"]];
        [text appendFormat:@"%@ ", [BundleUtil localizedStringForKey:@"from"]];
        [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"me"]];
        [text appendFormat:@"%@. ", draftPreview];
        [text appendFormat:@"%@. ", [conversation.lastMessage accessibilityMessageStatus]];
        return text;
    }
    
    if (conversation.conversationCategory == ConversationCategoryPrivate) {
        [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"private_chat_accessibility"]];
        if (conversation.unreadMessageCount.intValue > 0) {
            [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"unread"]];
        }
        return text;
    }
    
    [text appendFormat:@"%@. ", [DateFormatter accessibilityRelativeDayTime:conversation.lastMessage.displayDate]];
    if (messagePreview.length > 0) {
        if (conversation.unreadMessageCount.intValue > 0) {
            [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"unread"]];
        }
        [text appendFormat:@"%@ ", [BundleUtil localizedStringForKey:@"from"]];
        [text appendFormat:@"%@. ", [conversation.lastMessage accessibilityMessageSender]];
        [text appendFormat:@"%@. ", messagePreview];
        [text appendFormat:@"%@. ", [DateFormatter accessibilityRelativeDayTime:conversation.lastMessage.displayDate]];
    }
    
    if ([conversation.marked isEqualToNumber:[NSNumber numberWithBool:YES]]) {
        [text appendFormat:@"%@. ", [BundleUtil localizedStringForKey:@"pinned_conversation"]];
    }
    
    return text;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSDictionary *changeCopy = [change copy];
    NSString *keyPathCopy = [keyPath copy];
    if ([object isKindOfClass:[Conversation class]]) {
        @try {
            Conversation *conversationObject = (Conversation *)object;
            if (conversationObject.objectID == conversation.objectID) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([keyPathCopy isEqualToString:@"lastMessage"]) {
                        [self updateLastMessageIcons];
                        [self updateLastMessagePreview];
                        [self updateDateLabel];
                    } else if ([keyPathCopy isEqualToString:@"contact.displayName"] || [keyPathCopy isEqualToString:@"groupName"] || [keyPathCopy isEqualToString:@"members"]) {
                        [self updateName];
                    } else if ([keyPathCopy isEqualToString:@"contact.imageData"] || [keyPathCopy isEqualToString:@"contact.contactImage"]) {
                        if ([changeCopy[@"old"] isKindOfClass:[ImageData class]] && [changeCopy[@"new"] isKindOfClass:[ImageData class]]) {
                            ImageData *old = (ImageData *)changeCopy[@"old"];
                            ImageData *new = (ImageData *)changeCopy[@"new"];
                            if (old.objectID != new.objectID) {
                                if (conversation.contact != nil) {
                                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationContactImageChanged object:conversation.contact];
                                }
                                [self updateContactImageAndReset:true];
                            }
                        }
                    } else if ([keyPathCopy isEqualToString:@"groupImage"]) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationGroupConversationImageChanged object:conversation];
                        [self updateContactImageAndReset:true];
                    } else if ([keyPathCopy isEqualToString:@"typing"]) {
                        [self updateTypingIndicator];
                    } else if ([keyPathCopy isEqualToString:@"unreadMessageCount"]) {
                        [self updateBadgeView];
                    } else if ([keyPathCopy isEqualToString:@"lastMessage.poiAdress"]) {
                        [self updateLastMessageIcons];
                        [self updateLastMessagePreview];
                        [self updateDateLabel];
                    } else if ([keyPathCopy hasPrefix:@"lastMessage."]) {
                        [_lastMessageIconsAndDateTimer invalidate];
                        _lastMessageIconsAndDateTimer = [NSTimer timerWithTimeInterval:0.4 target:self selector:@selector(updateLastMessageIconsAndDate) userInfo:nil repeats:NO];
                        [[NSRunLoop mainRunLoop] addTimer:_lastMessageIconsAndDateTimer forMode:NSDefaultRunLoopMode];
                    } else if ([keyPathCopy hasPrefix:@"tags"]) {
                        [self updateTagsView];
                    }
                });
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into conversation");
        }
    }
    else if ([object isKindOfClass:[Group class]]) {
        @try {
            Group *groupObject = (Group *)object;
            if ([groupObject.groupID isEqualToData:_group.groupID]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([keyPathCopy isEqualToString:@"state"]) {
                        [self updateName];
                    }
                });
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into group");
        }
    }
    else if ([object isKindOfClass:[UserSettings class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([keyPathCopy isEqualToString:@"pushSettingsList"]) {
                [self updateNotificationIcon];
            }
        });
    }
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

#pragma mark - Notification

- (void)avatarChanged:(NSNotification*)notification
{
    EntityManager *entityManager = [EntityManager new];
    [entityManager performBlockAndWait:^{
        Conversation *dbConversation = [[entityManager entityFetcher] getManagedObjectById:conversation.objectID];
        if (dbConversation && notification.object && [dbConversation.contact.identity isEqualToString:notification.object] ) {
            [self updateContactImageAndReset:true];
        }
    }];
}

@end
