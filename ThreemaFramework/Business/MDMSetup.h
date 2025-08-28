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

extern NSString * _Nonnull const MDM_KEY_THREEMA_CONFIGURATION;
extern NSString * _Nonnull const MDM_KEY_THREEMA_OVERRIDE;
extern NSString * _Nonnull const MDM_KEY_THREEMA_PARAMS;

typedef enum : int {
    CallsPolicyTypeAllowAll,
    CallsPolicyTypeDisableAll,
    CallsPolicyTypeDisableVideo,
    CallsPolicyTypeUnknown
} CallsPolicyType;

@interface MDMSetup : NSObject {
    BOOL isSetup;
    /// true means it is Threema Work
    BOOL isLicenseRequired;
    dispatch_queue_t queue;
}

@property (readonly, assign) NSString *idBackup;
@property (readonly, assign) NSString *idBackupPassword;

- (MDMSetup*) initWithSetup:(BOOL)setup;

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

- (NSString *)webHosts;

- (BOOL)disableCreateGroup;

- (BOOL)disableSendProfilePicture;

- (BOOL)skipWizard;

- (BOOL)disableShareMedia;

- (BOOL)disableWorkDirectory;

- (BOOL)disableHideStaleContacts;

- (NSNumber*)safeEnable;

- (NSString*)safePassword;

- (NSString*)safeServerUrl NS_SWIFT_NAME(safeServerURL());

- (NSString*)safeServerUsername;

- (NSString*)safeServerPassword;

- (NSString *)safePasswordPattern;

- (NSString *)safePasswordMessage;

- (nullable NSNumber *)keepMessagesDays;

- (nullable NSString *)onPremConfigUrl;

- (BOOL)safeRestoreEnable;

- (NSString*)safeRestoreId NS_SWIFT_NAME(safeRestoreID());

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

- (void)restoreIDBackupOnCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (nullable NSString *)supportDescriptionString;

- (BOOL)existsMdmKey:(NSString*)mdmKey;

- (NSDictionary*)getCompanyMDM;

- (NSDictionary*)getThreemaMDM;

/// Apply Threema MDM parameters (workData) to company MDM
/// @param workData: Threema MDM parameters
/// @param sendForce: If YES send update work info any way
- (void)applyThreemaMdm:(nullable NSDictionary *)workData sendForce:(BOOL)sendForce;

/// Apply company MDM with cached Threema MDM parameters
/// @param sendForce: If YES send update work info any way
- (void)applyCompanyMDMWithCachedThreemaMDMSendForce:(BOOL)sendForce;

- (void)deleteThreemaMdm;

@end
