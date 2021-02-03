//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#ifndef Threema_Constants_h
#define Threema_Constants_h

#pragma mark - iOS version makros

#define SYSTEM_VERSION_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define SYSTEM_IS_IPAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

#define SYSTEM_IS_IPHONE_X (([[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPhone) && ((int)[[UIScreen mainScreen] nativeBounds].size.height) == 2436)

#define THREEMA_FRAMEWORK_IDENTIFIER @"ch.threema.ThreemaFramework"

#define SHARE_FILE_PREFIX @"share"

#define MEDIA_EXTENSION_AUDIO @"m4a"
#define MEDIA_EXTENSION_IMAGE @"jpg"
#define MEDIA_EXTENSION_VIDEO @"mp4"

#pragma mark - notifications

#define kNotificationShowConversation @"ThreemaShowConversation"
#define kNotificationDeletedConversation @"ThreemaDeletedConversation"

#define kNotificationShowContact @"ThreemaShowContact"
#define kNotificationDeletedContact @"ThreemaDeletedContact"
#define kNotificationAddedContact @"ThreemaAddedContact"
#define kNotificationBlockedContact @"ThreemaBlockedContact"

#define kNotificationShowGroup @"ThreemaShowGroup"
#define kNotificationUpdatedGroup @"ThreemaUpdatedGroup"

#define kNotificationCreatedIdentity @"ThreemaCreatedIdentity"
#define kNotificationDestroyedIdentity @"ThreemaDestroyedIdentity"
#define kNotificationIdentityAvatarChanged @"ThreemaIdentityAvatarChanged"

#define kNotificationLicenseMissing @"ThreemaLicenseMissing"

#define kNotificationWallpaperChanged @"ThreemaWallpaperChanged"
#define kNotificationFontSizeChanged @"ThreemaChatFontSizeChanged"
#define kNotificationShowTimestampSettingsChanged @"ThreemaShowTimestampSettingsChanged"
#define kNotificationColorThemeChanged @"ThreemaColorThemeChanged"
#define kNotificationShowProfilePictureChanged @"ShowProfilePictureChanged"
#define kNotificationCallInBackground @"ThreemaCallInBackground"
#define kNotificationCallInBackgroundTimeChanged @"ThreemaCallInBackgroundTimeChanged"

#define kNotificationUpdateDraftForCell @"ThreemaUpdateDraftForCell"

#define kPushNotificationDeviceToken @"PushNotificationDeviceToken"
#define kVoIPPushNotificationDeviceToken @"VoIPPushNotificationDeviceToken"
#define kPushNotificationEncryptionKey @"PushNotificationEncryptionKey"

#define kNotificationServerMessage @"ThreemaServerMessage"
#define kNotificationQueueSendComplete @"ThreemaQueueSendComplete"
#define kNotificationErrorConnectionFailed @"ThreemaErrorConnectionFaild"
#define kNotificationErrorUnknownGroup @"ThreemaErrorUnknownGroup"
#define kNotificationErrorPublicKeyMismatch @"ThreemaErrorPublicKeyMismatch"

#define kNotificationDBRefreshedDirtyObject @"ThreemaDBRefreshedDirtyObject"

#define kNotificationRefreshWorkContactTableView @"RefreshWorkContactTableView"
#define kNotificationAddressbookSyncronized @"AddressbookSyncronized"
#define kNotificationRefreshContactSortIndices @"RefreshContactSortIndices"

#define kVoIPCallStartRinging @"ThreemaVoIPCallStartRinging"
#define kVoIPCallStatusChanged @"ThreemaVoIPCallStatusChanged"
#define kVoIPCallIncomingCall @"ThreemaVoIPCallIncomingCall"
#define kVoIPCallStartDebugMode @"ThreemaVoIPCallStartDebugMode"

#define kAppClosedByUserBackgroundTask @"ThreemaAppClosedByUserBackgroundTask"
#define kAppVoIPBackgroundTask @"ThreemaVoIPBackgroundTask"
#define kAppVoIPIncomCallBackgroundTask @"ThreemaVoIPIncomCallBackgroundTask"
#define kAppWCBackgroundTask @"ThreemaWCBackgroundTask"
#define kAppPushBackgroundTask @"ThreemaPushBackgroundTask"
#define kAppSendingBackgroundTask @"ThreemaSendingBackgroundTask"
#define kAppAckBackgroundTask @"ThreemaAckBackgroundTask"
#define kAppPushReplyBackgroundTask @"ThreemaPushReplyBackgroundTask"
#define kAppCoreDataSaveBackgroundTask @"ThreemaCoreDataSaveBackgroundTask"
#define kAppCoreDataProcessMessageBackgroundTask @"ThreemaCoreDataProcessMessageTask"
#define kSafeBackgroundTask @"ThreemaSafeBackgroundTask"

#define kMediaPreviewPauseVideo @"MediaPreviewPauseVideo"

#define kAppClosedByUserBackgroundTaskTime 5
#define kAppPushBackgroundTaskTime 40
#define kAppWCBackgroundTaskTime 30
#define kAppPushReplyBackgroundTaskTime 30
#define kAppVoIPBackgroundTaskTime 5
#define kAppAckBackgroundTaskTime 2
#define kAppCoreDataSaveBackgroundTaskTime 15
#define kAppSendingBackgroundTaskTime 170
#define kAppVoIPIncomCallBackgroundTaskTime 80
#define kAppCoreDataProcessMessageBackgroundTaskTime 10

static NSString * const kNotificationProfilePictureChanged = @"ProfilePictureChanged";
static NSString * const kNotificationProfileNicknameChanged = @"ProfileNicknameChanged";


#pragma mark - notification info keys

#define kKeyContact @"contact"
#define kKeyGroup @"group"
#define kKeyConversation @"conversation"
#define kKeyForceCompose @"forceCompose"
#define kKeyText @"text"
#define kKeyImage @"image"
#define kKeyMessage @"message"

#define kKeyObjectID @"objectID"

#define kCNContactKeys @[CNContactFamilyNameKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactImageDataKey, CNContactImageDataAvailableKey, CNContactThumbnailImageDataKey, [CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName]]

#pragma mark - ThreemaWeb

#define kWebPageSize 50

#pragma mark - ThreemaSAFE

static NSString * const kSafeBackupTrigger = @"ThreemaSafeBackupTrigger";
static NSString * const kSafeBackupUIRefresh = @"ThreemaSafeBackupUIRefresh";
#define kSafeSetupUI @"ThreemaSafeSetupUI"

#pragma mark - Threema Calls
static NSString * const kThreemaVideoCallsQualitySettingChanged = @"ThreemaVideoCallsQualitySettingChanged";


#pragma mark - UserDefault Keys
#define kLastPushOverrideSendDate @"LastPushOverrideSendDate"

#pragma mark - Push notification keys

typedef NSString *ThreemaPushNotificationDictionary NS_STRING_ENUM;

extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryKey;

extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryCommandKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryFromKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryNicknameKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryMessageIdKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryVoipKey;

typedef NSString *ThreemaPushNotificationDictionaryBool NS_STRING_ENUM NS_SWIFT_NAME(ThreemaPushNotificationDictionary.Bool);
extern ThreemaPushNotificationDictionaryBool const ThreemaPushNotificationDictionaryBoolTrue;
extern ThreemaPushNotificationDictionaryBool const ThreemaPushNotificationDictionaryBoolFalse;

typedef NSString *ThreemaPushNotificationDictionaryCommand NS_STRING_ENUM NS_SWIFT_NAME(ThreemaPushNotificationDictionary.Command);
extern ThreemaPushNotificationDictionaryCommand const ThreemaPushNotificationDictionaryCommandNewMessage;
extern ThreemaPushNotificationDictionaryCommand const ThreemaPushNotificationDictionaryCommandNewGroupMessage;


#endif
