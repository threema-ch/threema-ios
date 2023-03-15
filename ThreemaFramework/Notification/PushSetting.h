//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

#import <Foundation/Foundation.h>
#import "BaseMessage.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PushSettingType) {
    /// Notifications are on (i.e. DND is off)
    kPushSettingTypeOn = 0,
    /// Notifications are disabled indefinitely (i.e. DND is on)
    kPushSettingTypeOff,
    /// Notifications are disabled for a certain period
    kPushSettingTypeOffPeriod
};

/// Set of possible off-periods
///
/// Identical on all platforms supported by Threema.
typedef NS_ENUM(NSInteger, PeriodOffTime) {
    kPeriodOffTime1Hour = 0,
    kPeriodOffTime2Hours = 1,
    kPeriodOffTime3Hours = 2,
    kPeriodOffTime4Hours = 3,
    kPeriodOffTime8Hours = 4,
    kPeriodOffTime1Day = 5,
    kPeriodOffTime1Week = 6
    // Also add new cases to `allCases` in `PushSetting+PeriodOffTime.swift`
};

/// Read, update and save notification settings for conversations and contacts
///
/// Use one of the four `pushSettingFor*` initializers to get the setting for the corresponding object. If it is not stored so far it will return an
/// object with the default values. Use `save` to permanently store a modified setting.
///
/// Each instance of this class is independent. If you have multiple instances with the same ID the last one that is saved will be preserved.
/// If one instance is updated the others don't get notified.
@interface PushSetting : NSObject

/// Identity these settings apply to
///
/// This should normally not be accessed directly. It is the Threema ID for a single contact, hex encoded group ID for groups.
@property (nonatomic, strong, readonly, nullable) NSString *identity;

/// "State" of this setting
///
/// If it is `kPushSettingTypeOffPeriod`, but `periodOffTillDate` is `nil` or in the past it will automatically reset to `kPushSettingTypeOn` on
/// reading.
///
/// When setting this to `kPushSettingTypeOffPeriod` always set `periodOffTime` before reading this value. (Otherwise it will reset to
/// `kPushSettingTypeOn`.)
@property (nonatomic) PushSettingType type;


/// Period of off-time
///
/// When set automatically sets `periodOffTillDate` to the date in the future with this period.
@property (nonatomic) PeriodOffTime periodOffTime;

/// When does the current off-period end?
@property (nonatomic, strong, readonly, nullable) NSDate *periodOffTillDate;


/// Should a notification sound be played?
@property (nonatomic) BOOL silent;

/// Should notifications always be shown for mentions?
@property (nonatomic) BOOL mentions;


/// Localized description of current state to show in UI
@property (nonatomic, readonly) NSString *localizedDescription;

/// Longer localized description of current state to show in UI
@property (nonatomic, readonly) NSString *localizedLongDescription;


/// SF Symbol name for current push setting
@property (nonatomic, readonly) NSString *sfSymbolNameForPushSetting;

/// SF Symbol name for current push setting if setting is not set to the defaults
@property (nonatomic, readonly, nullable) NSString *sfSymbolNameForEditedPushSetting;

#pragma mark - Get push settings

/// Get setting for a conversation
///
/// @param conversation Conversation
/// @return Custom setting if stored, default setting otherwise
+ (PushSetting *)pushSettingForConversation:(Conversation *)conversation;

/// Get setting for a contact
///
/// @param contact Contact
/// @return Custom setting if stored, default setting otherwise
+ (PushSetting *)pushSettingForContact:(ContactEntity *)contact NS_SWIFT_NAME(init(for:));

/// Get setting for a Threema ID
///
/// @param threemaId String representation of a Threema ID
/// @return Custom setting if stored, default setting otherwise
+ (PushSetting *)pushSettingForThreemaId:(NSString *)threemaId NS_SWIFT_NAME(init(forThreemaID:));

/// Get setting for a group ID
///
/// @param groupId Group ID data
/// @return Custom setting if stored, default setting otherwise
+ (PushSetting *)pushSettingForGroupId:(NSData *)groupId;

#pragma mark - Deprecated methods

- (id)initWithDictionary:(NSDictionary * _Nullable)dict DEPRECATED_MSG_ATTRIBUTE("Use one of the pushSettingFor* initializers");

#pragma mark - Instance methods

/// Save setting
- (void)save;

/// Should we show a notification for this base message?
- (BOOL)canSendPushForBaseMessage:(nullable BaseMessage *)baseMessage;

/// Should a notification be shown according to this setting?
- (BOOL)canSendPush;

/// Icon to represent the current setting
- (nullable UIImage *)imageForPushSetting;

/// Icon to display if setting is not set to the defaults
- (UIImage * _Nullable)imageForEditedPushSettingWith:(UIImageConfiguration * _Nullable)config;

#pragma mark - Setup or migration

/// Add default push settings for elements of `conversations` without existing push setting
+ (void)addDefaultSettingForElementsWithoutSettingInConversations:(NSArray<Conversation *> *)conversations;

/// Add and update push settings for provided ids to disable notifications
+ (void)addPushSettingsForNoPushIdentities:(NSOrderedSet<NSString *> *)noPushIdentities;

@end

NS_ASSUME_NONNULL_END
