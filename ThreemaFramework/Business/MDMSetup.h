//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2025 Threema GmbH
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
#import "ThreemaFramework.h"

extern NSString * _Nonnull const MDM_CONFIGURATION_KEY;
extern NSString * _Nonnull const MDM_FEEDBACK_KEY;
extern NSString * _Nonnull const MDM_THREEMA_CONFIGURATION_KEY;

extern NSString * _Nonnull const MDM_KEY_LICENSE_USERNAME;
extern NSString * _Nonnull const MDM_KEY_LICENSE_PASSWORD;
extern NSString * _Nonnull const MDM_KEY_NICKNAME;
extern NSString * _Nonnull const MDM_KEY_LINKED_EMAIL;
extern NSString * _Nonnull const MDM_KEY_LINKED_PHONE;
extern NSString * _Nonnull const MDM_KEY_FIRST_NAME;
extern NSString * _Nonnull const MDM_KEY_LAST_NAME;
extern NSString * _Nonnull const MDM_KEY_CSI;
extern NSString * _Nonnull const MDM_KEY_JOB_TITLE;
extern NSString * _Nonnull const MDM_KEY_DEPARTMENT;
extern NSString * _Nonnull const MDM_KEY_CATEGORY;
extern NSString * _Nonnull const MDM_KEY_CONTACT_SYNC;
extern NSString * _Nonnull const MDM_KEY_READONLY_PROFILE;
extern NSString * _Nonnull const MDM_KEY_ID_BACKUP;
extern NSString * _Nonnull const MDM_KEY_ID_BACKUP_PASSWORD;
extern NSString * _Nonnull const MDM_KEY_BLOCK_UNKNOWN;
extern NSString * _Nonnull const MDM_KEY_HIDE_INACTIVE_IDS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_SAVE_TO_GALLERY;
extern NSString * _Nonnull const MDM_KEY_DISABLE_ADD_CONTACT;
extern NSString * _Nonnull const MDM_KEY_DISABLE_EXPORT;
extern NSString * _Nonnull const MDM_KEY_DISABLE_BACKUPS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_ID_EXPORT;
extern NSString * _Nonnull const MDM_KEY_DISABLE_SYSTEM_BACKUPS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_MESSAGE_PREVIEW;
extern NSString * _Nonnull const MDM_KEY_DISABLE_SEND_PROFILE_PICTURE;
extern NSString * _Nonnull const MDM_KEY_DISABLE_CALLS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_VIDEO_CALLS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_GROUP_CALLS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_CREATE_GROUP;
extern NSString * _Nonnull const MDM_KEY_SKIP_WIZARD;
extern NSString * _Nonnull const MDM_KEY_DISABLE_WEB;
extern NSString * _Nonnull const MDM_KEY_DISABLE_MULTIDEVICE;
extern NSString * _Nonnull const MDM_KEY_WEB_HOSTS;
extern NSString * _Nonnull const MDM_KEY_DISABLE_SHARE_MEDIA;
extern NSString * _Nonnull const MDM_KEY_DISABLE_WORK_DIRECTORY;
extern NSString * _Nonnull const MDM_KEY_KEEP_MESSAGE_DAYS;

extern NSString * _Nonnull const MDM_KEY_SAFE_ENABLE;
extern NSString * _Nonnull const MDM_KEY_SAFE_PASSWORD;
extern NSString * _Nonnull const MDM_KEY_SAFE_SERVER_URL;
extern NSString * _Nonnull const MDM_KEY_SAFE_SERVER_USERNAME;
extern NSString * _Nonnull const MDM_KEY_SAFE_SERVER_PASSWORD;
extern NSString * _Nonnull const MDM_KEY_SAFE_RESTORE_ENABLE;
extern NSString * _Nonnull const MDM_KEY_SAFE_RESTORE_ID;

extern NSString * _Nonnull const MDM_KEY_SAFE_PASSWORD_PATTERN;
extern NSString * _Nonnull const MDM_KEY_SAFE_PASSWORD_MESSAGE;

extern NSString * _Nonnull const MDM_KEY_ONPREM_SERVER;
extern NSString * _Nonnull const MDM_KEY_ENABLE_REMOTE_SECRET;

extern NSString * _Nonnull const MDM_KEY_THREEMA_CONFIGURATION;
extern NSString * _Nonnull const MDM_KEY_THREEMA_OVERRIDE;
extern NSString * _Nonnull const MDM_KEY_THREEMA_PARAMS;

typedef enum : int {
    CallsPolicyTypeAllowAll,
    CallsPolicyTypeDisableAll,
    CallsPolicyTypeDisableVideo,
    CallsPolicyTypeUnknown
} CallsPolicyType;

@interface MDMSetup : NSObject

@property (readonly, nullable) NSObject *businessInjector;

@property (readonly, assign) NSString *idBackup;
@property (readonly, assign) NSString *idBackupPassword;

- (MDMSetup*)init;
- (MDMSetup*)initWithAppSetupStateRawValue:(NSInteger)appSetupStateRawValue;

+ (void)clearMdmCache;

- (BOOL)disableBackups;

- (BOOL)disableIdExport NS_SWIFT_NAME(disableIDExport());

- (BOOL)disableSystemBackups;

- (BOOL)readonlyProfile;

- (BOOL)disableAddContact;

- (BOOL)disableSaveToGallery;

- (BOOL)disableExport;

- (BOOL)disableMessagePreview;

- (BOOL)disableCalls;

- (BOOL)disableVideoCalls;

- (BOOL)disableGroupCalls;

- (BOOL)disableWeb;

- (BOOL)disableMultiDevice;

- (nullable NSString *)webHosts;

- (BOOL)disableCreateGroup;

- (BOOL)disableSendProfilePicture;

- (BOOL)skipWizard;

- (BOOL)disableShareMedia;

- (BOOL)disableWorkDirectory;

- (BOOL)disableHideStaleContacts;

- (BOOL)enableRemoteSecret;

- (nullable NSNumber *)safeEnable;

- (nullable NSString *)safePassword;

- (nullable NSString *)safeServerUrl NS_SWIFT_NAME(safeServerURL());

- (nullable NSString *)safeServerUsername;

- (nullable NSString *)safeServerPassword;

- (nullable NSString *)safePasswordPattern;

- (nullable NSString *)safePasswordMessage;

- (nullable NSString *)nickname;

- (nullable NSString *)linkEmail;

- (nullable NSString *)linkPhoneNumber;

- (BOOL)contactSync;

- (nullable NSNumber *)keepMessagesDays;

- (nullable NSString *)onPremConfigUrl;

- (BOOL)safeRestoreEnable;

- (nullable NSString *)safeRestoreId NS_SWIFT_NAME(safeRestoreID());

- (BOOL)isSafeBackupDisable;

- (BOOL)isSafeBackupForce;

- (BOOL)isSafeBackupPasswordPreset;

- (BOOL)isSafeBackupServerPreset;

- (BOOL)isSafeRestoreDisable;

- (BOOL)isSafeRestoreForce;

- (BOOL)isSafeRestorePasswordPreset;

- (BOOL)isSafeRestoreServerPreset;

- (void)loadRenewableValues;

- (void)loadLicenseInfo;

- (void)loadIDCreationValues;

- (BOOL)hasIDBackup;

- (void)restoreIDBackupOnCompletion:(void(^_Nonnull)(void))onCompletion onError:(void(^_Nonnull)(NSError *error))onError;

- (nullable NSString *)supportDescriptionString;

- (BOOL)existsMdmKey:(nonnull NSString*)mdmKey;

- (nullable NSDictionary *)getCompanyMDM;

- (nullable NSDictionary *)getThreemaMDM;

/// Apply Threema MDM parameters (workData) to company MDM
/// @param workData: Threema MDM parameters
/// @param sendForce: If YES send update work info any way
- (void)applyThreemaMdm:(nullable NSDictionary *)workData sendForce:(BOOL)sendForce;

/// Apply company MDM with cached Threema MDM parameters
/// @param sendForce: If YES send update work info any way
- (void)applyCompanyMDMWithCachedThreemaMDMSendForce:(BOOL)sendForce NS_SWIFT_NAME(applyCompanyMDMWithCachedThreemaMDM(sendForce:));

- (void)deleteThreemaMdm;

@end
