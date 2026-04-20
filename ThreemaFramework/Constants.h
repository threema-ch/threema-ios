#import <Contacts/Contacts.h>

#ifndef Threema_Constants_h
#define Threema_Constants_h

#pragma mark - iOS version macros

#define SYSTEM_VERSION_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define THREEMA_FRAMEWORK_IDENTIFIER @"ch.threema.ThreemaFramework"

#define SHARE_FILE_PREFIX @"share"

#define THREEMA_ID_SHARE_LINK @"https://threema.id/"

#define MEDIA_EXTENSION_AUDIO @"m4a"
#define MEDIA_EXTENSION_IMAGE @"jpg"
#define MEDIA_EXTENSION_VIDEO @"mp4"

#pragma mark - notifications

#define kNotificationShowConversation @"ThreemaShowConversation"
#define kNotificationDeletedConversation @"ThreemaDeletedConversation"
#define kNotificationOpenedConversation @"ThreemaConversationOpened"

#define kNotificationShowContact @"ThreemaShowContact"
#define kNotificationDeletedContact @"ThreemaDeletedContact"
#define kNotificationBlockedContact @"ThreemaBlockedContact"

#define kNotificationShowGroup @"ThreemaShowGroup"
#define kNotificationShowDistributionList @"ThreemaShowDistributionList"
#define kNotificationShowSafeSetup @"ThreemaShowSafeSetup"
#define kShowNotificationSettings @"ThreemaShowNotificationSettings"

#define kNotificationMessagesCountChanged @"ThreemaUnreadMessagesCountChanged"

#define kNotificationDestroyedIdentity @"ThreemaDestroyedIdentity"
#define kNotificationShowProfile @"ThreemaShowProfile"

#define kNotificationLicenseMissing @"ThreemaLicenseMissing"
#define kNotificationLicenseCheckSuccess @"ThreemaLicenseCeckSuccess"

#define kNotificationWallpaperChanged @"ThreemaWallpaperChanged"
#define kNotificationColorThemeChanged @"ThreemaColorThemeChanged"
#define kNotificationShowProfilePictureChanged @"ShowProfilePictureChanged"
#define kNotificationIncomingProfileSynchronization @"IncomingProfileSynchronization"
#define kNotificationIncomingSettingsSynchronization @"IncomingSettingsSynchronization"
#define kNotificationSettingStoreSynchronization @"NotificationSettingStoreSynchronization"
#define kNotificationNavigationBarColorShouldChange @"NavigationBarColorShouldChange"
#define kNotificationNavigationItemPromptShouldChange @"NavigationItemPromptShouldChange"
#define kNotificationMultiDeviceWizardDidUpdate @"MultiDeviceWizardDidUpdate"

#define kNotificationUpdateDraftForCell @"ThreemaUpdateDraftForCell"

#define kPushNotificationDeviceToken @"PushNotificationDeviceToken"
#define kVoIPPushNotificationDeviceToken @"VoIPPushNotificationDeviceToken"
#define kPushNotificationEncryptionKey @"PushNotificationEncryptionKey"

#define kNotificationServerMessage @"ThreemaServerMessage"
#define kNotificationErrorConnectionFailed @"ThreemaErrorConnectionFailed"
#define kNotificationErrorPublicKeyMismatch @"ThreemaErrorPublicKeyMismatch"
#define kNotificationErrorRogueDevice @"ThreemaErrorRogueDevice"

#define kNotificationAddressbookSyncronized @"AddressbookSyncronized"
#define kNotificationChangedHidePrivateChat @"ChangedHidePrivateChat"
#define kNotificationChangedPushSetting @"ChangedPushSetting"

#define kAppClosedByUserBackgroundTask @"ThreemaAppClosedByUserBackgroundTask"
#define kAppVoIPBackgroundTask @"ThreemaVoIPBackgroundTask"
#define kAppVoIPIncomCallBackgroundTask @"ThreemaVoIPIncomCallBackgroundTask"
#define kAppWCBackgroundTask @"ThreemaWCBackgroundTask"
#define kAppSendingBackgroundTask @"ThreemaSendingBackgroundTask"
#define kAppAckBackgroundTask @"ThreemaAckBackgroundTask"
#define kAppPushReplyBackgroundTask @"ThreemaPushReplyBackgroundTask"
#define kAppCoreDataProcessMessageBackgroundTask @"ThreemaCoreDataProcessMessageTask"
#define kSafeBackgroundTask @"ThreemaSafeBackgroundTask"

#define kMediaPreviewPauseVideo @"MediaPreviewPauseVideo"

#define kAppClosedByUserBackgroundTaskTime 5
#define kAppPushBackgroundTaskTime 40
#define kAppWCBackgroundTaskTime 90
#define kAppPushReplyBackgroundTaskTime 30
#define kAppVoIPBackgroundTaskTime 5
#define kAppAckBackgroundTaskTime 2
#define kAppSendingBackgroundTaskTime 170
#define kAppVoIPIncomingCallBackgroundTaskTime 80
#define kAppCoreDataProcessMessageBackgroundTaskTime 10

static NSString * const kNotificationProfilePictureChanged = @"ProfilePictureChanged";
static NSString * const kNotificationProfileNicknameChanged = @"ProfileNicknameChanged";

static NSString * const kNotificationChatMessageAck = @"ChatMessageAck";
static NSString * const kNotificationMediatorMessageAck = @"MediatorMessageAck";

#pragma mark - notification info keys

#define kKeyContact @"contact"
#define kKeyContactIdentity @"contactIdentity"
#define kKeyGroup @"group"
#define kKeyDistributionList @"distributionList"
#define kKeyConversation @"conversation"
#define kKeyForceCompose @"forceCompose"
#define kKeyText @"text"
#define kKeyImage @"image"
#define kKeyMessage @"message"
#define kKeyUnread @"unread"
#define kKeyTitle @"title"

// Also update Constants.cnContactKeys
#define kCNContactKeys @[CNContactFamilyNameKey, CNContactGivenNameKey, CNContactMiddleNameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactImageDataKey, CNContactImageDataAvailableKey, CNContactThumbnailImageDataKey, [CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName]]

#pragma mark - ThreemaWeb

#define kWebPageSize 50

#pragma mark - ThreemaSafe

static NSString * const kSafeBackupTrigger = @"ThreemaSafeBackupTrigger";
static NSString * const kSafeBackupUIRefresh = @"ThreemaSafeBackupUIRefresh";
static NSString * const kSafeBackupPasswordCheck = @"ThreemaSafeBackupPasswordCheck";
static NSString * const kRevocationPasswordUIRefresh = @"ThreemaRevocationPasswordUIRefresh";
static NSString * const kLinkedPhoneUIRefresh = @"ThreemaLinkedPhoneUIRefresh";
static NSString * const kLinkedEmailUIRefresh = @"ThreemaLinkedEmailUIRefresh";

#define kSafeSetupUI @"ThreemaSafeSetupUI"

#pragma mark - Threema Calls
static NSString * const kThreemaVideoCallsQualitySettingChanged = @"ThreemaVideoCallsQualitySettingChanged";


#pragma mark - UserDefault Keys
#define kAppSetupStateKey @"AppSetupState"

#pragma mark - Push notification keys

typedef NSString *ThreemaPushNotificationDictionary NS_STRING_ENUM;

extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryKey;

extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryCommandKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryFromKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryNicknameKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryMessageIDKey;
extern ThreemaPushNotificationDictionary const ThreemaPushNotificationDictionaryVOIPKey;

typedef NSString *ThreemaPushNotificationDictionaryBool NS_STRING_ENUM NS_SWIFT_NAME(ThreemaPushNotificationDictionary.Bool);
extern ThreemaPushNotificationDictionaryBool const ThreemaPushNotificationDictionaryBoolTrue;
extern ThreemaPushNotificationDictionaryBool const ThreemaPushNotificationDictionaryBoolFalse;

typedef NSString *ThreemaPushNotificationDictionaryCommand NS_STRING_ENUM NS_SWIFT_NAME(ThreemaPushNotificationDictionary.Command);
extern ThreemaPushNotificationDictionaryCommand const ThreemaPushNotificationDictionaryCommandNewMessage;
extern ThreemaPushNotificationDictionaryCommand const ThreemaPushNotificationDictionaryCommandNewGroupMessage;

#pragma mark - Max lengths

static NSInteger const kMaxFirstOrLastNameLength = 256;
static NSInteger const kMaxGroupNameLength = 256;
static NSInteger const kMaxNicknameLength = 32;

#endif
