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

#import "MDMSetup.h"
#import "LicenseStore.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import <ThreemaFramework/ThreemaFramework-Swift.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

NSString * const MDM_CONFIGURATION_KEY = @"com.apple.configuration.managed"; // Company MDM persists in user defaults
NSString * const MDM_FEEDBACK_KEY = @"com.apple.feedback.managed";
NSString * const MDM_THREEMA_CONFIGURATION_KEY = @"threema_mdm_configuration"; // Threema MDM persists in user defaults

NSString * const MDM_KEY_LICENSE_USERNAME = @"th_license_username"; // String
NSString * const MDM_KEY_LICENSE_PASSWORD = @"th_license_password"; // String
NSString * const MDM_KEY_NICKNAME = @"th_nickname"; // String max 32
NSString * const MDM_KEY_LINKED_EMAIL = @"th_linked_email"; // String
NSString * const MDM_KEY_LINKED_PHONE = @"th_linked_phone"; // String
NSString * const MDM_KEY_FIRST_NAME = @"th_firstname"; // String
NSString * const MDM_KEY_LAST_NAME = @"th_lastname"; // String
NSString * const MDM_KEY_CSI = @"th_csi"; // String
NSString * const MDM_KEY_JOB_TITLE = @"th_job_title"; // String
NSString * const MDM_KEY_DEPARTMENT = @"th_department"; // String
NSString * const MDM_KEY_CATEGORY = @"th_category"; // String
NSString * const MDM_KEY_CONTACT_SYNC = @"th_contact_sync"; // Bool
NSString * const MDM_KEY_READONLY_PROFILE = @"th_readonly_profile"; // Bool
NSString * const MDM_KEY_ID_BACKUP = @"th_id_backup"; // String
NSString * const MDM_KEY_ID_BACKUP_PASSWORD = @"th_id_backup_password"; // String
NSString * const MDM_KEY_BLOCK_UNKNOWN = @"th_block_unknown"; // Bool
NSString * const MDM_KEY_HIDE_INACTIVE_IDS = @"th_hide_inactive_ids"; // Bool
NSString * const MDM_KEY_DISABLE_SAVE_TO_GALLERY = @"th_disable_save_to_gallery"; // Bool
NSString * const MDM_KEY_DISABLE_ADD_CONTACT = @"th_disable_add_contact"; // Bool
NSString * const MDM_KEY_DISABLE_EXPORT = @"th_disable_export"; // Bool
NSString * const MDM_KEY_DISABLE_BACKUPS = @"th_disable_backups"; // Bool
NSString * const MDM_KEY_DISABLE_ID_EXPORT = @"th_disable_id_export"; // Bool
NSString * const MDM_KEY_DISABLE_SYSTEM_BACKUPS = @"th_disable_system_backups"; // Bool
NSString * const MDM_KEY_DISABLE_MESSAGE_PREVIEW = @"th_disable_message_preview"; // Bool
NSString * const MDM_KEY_DISABLE_SEND_PROFILE_PICTURE = @"th_disable_send_profile_picture"; // Bool
NSString * const MDM_KEY_DISABLE_CALLS = @"th_disable_calls"; // Bool
NSString * const MDM_KEY_DISABLE_VIDEO_CALLS = @"th_disable_video_calls"; // String
NSString * const MDM_KEY_DISABLE_GROUP_CALLS = @"th_disable_group_calls"; // Bool
NSString * const MDM_KEY_DISABLE_CREATE_GROUP = @"th_disable_create_group"; // Bool
NSString * const MDM_KEY_SKIP_WIZARD = @"th_skip_wizard"; // Bool
NSString * const MDM_KEY_DISABLE_WEB = @"th_disable_web"; // Bool
NSString * const MDM_KEY_DISABLE_MULTIDEVICE = @"th_disable_multidevice"; // Bool
NSString * const MDM_KEY_WEB_HOSTS = @"th_web_hosts"; // String
NSString * const MDM_KEY_DISABLE_SHARE_MEDIA = @"th_disable_share_media"; // Bool
NSString * const MDM_KEY_DISABLE_WORK_DIRECTORY = @"th_disable_work_directory"; // Bool

NSString * const MDM_KEY_SAFE_ENABLE = @"th_safe_enable"; // Bool
NSString * const MDM_KEY_SAFE_PASSWORD = @"th_safe_password"; // String min. 8, max. 4096
NSString * const MDM_KEY_SAFE_SERVER_URL = @"th_safe_server_url"; // String
NSString * const MDM_KEY_SAFE_SERVER_USERNAME = @"th_safe_server_username"; // String
NSString * const MDM_KEY_SAFE_SERVER_PASSWORD = @"th_safe_server_password"; // String
NSString * const MDM_KEY_SAFE_RESTORE_ENABLE = @"th_safe_restore_enable"; // Bool
NSString * const MDM_KEY_SAFE_RESTORE_ID = @"th_safe_restore_id"; // String 8
NSString * const MDM_KEY_KEEP_MESSAGE_DAYS = @"th_keep_messages_days"; // Int

NSString * const MDM_KEY_SAFE_PASSWORD_PATTERN = @"th_safe_password_pattern"; // String
NSString * const MDM_KEY_SAFE_PASSWORD_MESSAGE = @"th_safe_password_message"; // String

NSString * const MDM_KEY_ONPREM_SERVER = @"th_onprem_server"; // String

NSString * const MDM_KEY_THREEMA_CONFIGURATION = @"mdm";
NSString * const MDM_KEY_THREEMA_OVERRIDE = @"override";
NSString * const MDM_KEY_THREEMA_PARAMS = @"params";

static NSDictionary *_mdmCache;
static NSDictionary *_mdmCacheSetup;

@implementation MDMSetup

- (MDMSetup*)initWithSetup:(BOOL)setup {
    self = [super init];
    if (self) {
        isSetup = setup;
        isLicenseRequired = TargetManagerObjc.isBusinessApp;
        
        queue = dispatch_queue_create("ch.threema.MdmConfiguration", NULL);
    }
    return self;
}

- (MDMSetup*)initMockupWithIsBusinessApp:(BOOL)isBusinessApp setup:(BOOL)setup {
    self = [super init];
    if (self) {
        isSetup = setup;
        isLicenseRequired = isBusinessApp;
        
        queue = dispatch_queue_create("ch.threema.MdmConfiguration", NULL);
    }
    return self;
}

+ (void)clearMdmCache {
    _mdmCache = nil;
    _mdmCacheSetup = nil;
}

// MARK: MDM values

- (BOOL)disableBackups {
    NSNumber *disableBackups = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_BACKUPS];
    return [disableBackups isKindOfClass:[NSNumber class]] ? disableBackups.boolValue : NO;
}

- (BOOL)disableIdExport {
    NSNumber *disableIdExport = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_ID_EXPORT];
    return [disableIdExport isKindOfClass:[NSNumber class]] ? disableIdExport.boolValue : NO;
}

- (BOOL)disableSystemBackups {
    NSNumber *disableSystemBackups = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_SYSTEM_BACKUPS];
    return [disableSystemBackups isKindOfClass:[NSNumber class]] ? disableSystemBackups.boolValue : NO;
}

- (BOOL)readonlyProfile {
    NSNumber *readonlyProfile = [self getMdmConfigurationBoolForKey:MDM_KEY_READONLY_PROFILE];
    return [readonlyProfile isKindOfClass:[NSNumber class]] ? readonlyProfile.boolValue : NO;
}

- (BOOL)disableAddContact {
    NSNumber *disableAddContact = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_ADD_CONTACT];
    return [disableAddContact isKindOfClass:[NSNumber class]] ? disableAddContact.boolValue : NO;
}

- (BOOL)disableSaveToGallery {
    NSNumber *disableSaveToGallery = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_SAVE_TO_GALLERY];
    return [disableSaveToGallery isKindOfClass:[NSNumber class]] ? disableSaveToGallery.boolValue : NO;
}

- (BOOL)disableExport {
    NSNumber *disableExport = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_EXPORT];
    return [disableExport isKindOfClass:[NSNumber class]] ? disableExport.boolValue : NO;
}

- (BOOL)disableMessagePreview {
    NSNumber *disableMessagePreview = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_MESSAGE_PREVIEW];
    return [disableMessagePreview isKindOfClass:[NSNumber class]] ? disableMessagePreview.boolValue : NO;
}

- (BOOL)disableCalls {
    NSNumber *disableCalls = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_CALLS];
    return [disableCalls isKindOfClass:[NSNumber class]] ? disableCalls.boolValue : NO;
}

- (BOOL)disableVideoCalls {
    NSNumber *disableVideoCalls = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_VIDEO_CALLS];
    return [disableVideoCalls isKindOfClass:[NSNumber class]] ? disableVideoCalls.boolValue : NO;
}

- (BOOL)disableGroupCalls {
    NSNumber *disableGroupCalls = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_GROUP_CALLS];
    return [disableGroupCalls isKindOfClass:[NSNumber class]] ? disableGroupCalls.boolValue : NO;
}

- (BOOL)disableWeb {
    NSNumber *disableWeb = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_WEB];
    return [disableWeb isKindOfClass:[NSNumber class]] ? disableWeb.boolValue : NO;
}

/// If the MDM key for multi-device is set, use the value from the disableMultidevice key.
/// Otherwise, use the disableWeb key for multi-device.
- (BOOL)disableMultiDevice {
    if ([self existsMdmKey:MDM_KEY_DISABLE_MULTIDEVICE]) {
        NSNumber *disableMultiDevice = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_MULTIDEVICE];
        return [disableMultiDevice isKindOfClass:[NSNumber class]] ? disableMultiDevice.boolValue : NO;
    }
    
    return [self disableWeb];
}

- (NSString *)webHosts {
    NSString *webHosts = [self getMdmConfigurationValueForKey:MDM_KEY_WEB_HOSTS];
    return [webHosts isKindOfClass:[NSString class]] && webHosts.length > 0 ? webHosts : nil;
}

- (BOOL)disableCreateGroup {
    NSNumber *disableCreateGroup = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_CREATE_GROUP];
    return [disableCreateGroup isKindOfClass:[NSNumber class]] ? disableCreateGroup.boolValue : NO;
}

- (BOOL)disableSendProfilePicture {
    NSNumber *disableSendProfilePicture = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_SEND_PROFILE_PICTURE];
    return [disableSendProfilePicture isKindOfClass:[NSNumber class]] ? disableSendProfilePicture.boolValue : NO;
}

- (BOOL)skipWizard {
    NSNumber *skipWizard = [self getMdmConfigurationBoolForKey:MDM_KEY_SKIP_WIZARD];
    return [skipWizard isKindOfClass:[NSNumber class]] ? skipWizard.boolValue : NO;
}

- (BOOL)disableShareMedia {
    NSNumber *disableShareMedia = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_SHARE_MEDIA];
    return [disableShareMedia isKindOfClass:[NSNumber class]] ? disableShareMedia.boolValue : NO;
}

- (BOOL)disableWorkDirectory {
    NSNumber *disableWorkDirectory = [self getMdmConfigurationBoolForKey:MDM_KEY_DISABLE_WORK_DIRECTORY];
    return [disableWorkDirectory isKindOfClass:[NSNumber class]] ? disableWorkDirectory.boolValue : NO;
}

- (BOOL)disableHideStaleContacts {
    NSNumber *disableHideInactiveIds = [self getMdmConfigurationBoolForKey:MDM_KEY_HIDE_INACTIVE_IDS];
    return [disableHideInactiveIds isKindOfClass:[NSNumber class]] ? YES : NO;
}

- (NSNumber*)safeEnable {
    NSNumber *safeEnable = [self getMdmConfigurationBoolForKey:MDM_KEY_SAFE_ENABLE];
    return [safeEnable isKindOfClass:[NSNumber class]] ? safeEnable : nil;
}

- (NSString*)safePassword {
    NSString *safePassword = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_PASSWORD];
    return [safePassword isKindOfClass:[NSString class]] && safePassword.length > 0 ? safePassword : nil;
}

- (NSString*)safeServerUrl {
    NSString *safeServerUrl = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_SERVER_URL];
    return [safeServerUrl isKindOfClass:[NSString class]] && safeServerUrl.length > 0 ? safeServerUrl : nil;
}

- (NSString*)safeServerUsername {
    NSString *safeServerUsername = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_SERVER_USERNAME];
    return [safeServerUsername isKindOfClass:[NSString class]] && safeServerUsername.length > 0 ? safeServerUsername : nil;
}

- (NSString*)safeServerPassword {
    NSString *safeServerPassword = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_SERVER_PASSWORD];
    return [safeServerPassword isKindOfClass:[NSString class]] && safeServerPassword.length > 0 ? safeServerPassword : nil;
}

- (BOOL)safeRestoreEnable {
    NSNumber *safeRestoreEnable = [self getMdmConfigurationBoolForKey:MDM_KEY_SAFE_RESTORE_ENABLE];
    return [safeRestoreEnable isKindOfClass:[NSNumber class]] ? safeRestoreEnable.boolValue : YES;
}

- (NSString*)safeRestoreId {
    NSString *safeRestoreId = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_RESTORE_ID];
    return [safeRestoreId isKindOfClass:[NSString class]] && safeRestoreId.length > 0 ? safeRestoreId : nil;
}

- (NSString *)safePasswordPattern {
    NSString *safePasswordPattern = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_PASSWORD_PATTERN];
    return [safePasswordPattern isKindOfClass:[NSString class]] && safePasswordPattern.length > 0 ? safePasswordPattern : nil;
}

- (NSString *)safePasswordMessage {
    NSString *safePasswordMessage = [self getMdmConfigurationValueForKey:MDM_KEY_SAFE_PASSWORD_MESSAGE];
    return [safePasswordMessage isKindOfClass:[NSString class]] && safePasswordMessage.length > 0 ? safePasswordMessage : nil;
}

- (nullable NSNumber *)keepMessagesDays {
    NSNumber *keepMessagesDays = [self getMdmConfigurationValueForKey:MDM_KEY_KEEP_MESSAGE_DAYS];
    return [keepMessagesDays isKindOfClass:[NSNumber class]] ? keepMessagesDays : nil;
}

- (nullable NSString *)onPremConfigUrl {
    NSString *onPremConfigUrl = [self getMdmConfigurationValueForKey:MDM_KEY_ONPREM_SERVER];
    return [onPremConfigUrl isKindOfClass:[NSString class]] && onPremConfigUrl.length > 0 ? onPremConfigUrl : nil;
}

// MARK: Threema Safe status

- (BOOL)isSafeBackupDisable {
    return [[self safeSetupWork] isSafeBackupStatusSetWithSafeState:SafeSetupWork.backupDisable];
}

- (BOOL)isSafeBackupForce  {
    return [[self safeSetupWork] isSafeBackupStatusSetWithSafeState:SafeSetupWork.backupForce];
}

- (BOOL)isSafeBackupPasswordPreset {
    return [[self safeSetupWork] isSafeBackupStatusSetWithSafeState:SafeSetupWork.passwordPreset];
}

- (BOOL)isSafeBackupServerPreset {
    return [[self safeSetupWork] isSafeBackupStatusSetWithSafeState:SafeSetupWork.serverPreset];
}

- (BOOL)isSafeRestoreDisable {
    return [[self safeSetupWork] isSafeRestoreStatusSetWithSafeState:SafeSetupWork.restoreDisable];
}

- (BOOL)isSafeRestoreForce {
    return [[self safeSetupWork] isSafeRestoreStatusSetWithSafeState:SafeSetupWork.restoreForce];
}

- (BOOL)isSafeRestorePasswordPreset {
    return [[self safeSetupWork] isSafeRestoreStatusSetWithSafeState:SafeSetupWork.passwordPreset];
}

- (BOOL)isSafeRestoreServerPreset {
    return [[self safeSetupWork] isSafeRestoreStatusSetWithSafeState:SafeSetupWork.serverPreset];
}

- (SafeSetupWork*)safeSetupWork {
    return [[SafeSetupWork alloc] initWithMdmSetup:self];
}

// MARK: apply MDM to user settings, identity

- (void)loadRenewableValues {
    if (!isLicenseRequired) {
        return;
    }

    [self loadLicenseInfo];
    
    UserSettings *userSettings = [UserSettings sharedUserSettings];

    NSNumber *blockUnknown = [self getMdmConfigurationBoolForKey:MDM_KEY_BLOCK_UNKNOWN];
    if ([blockUnknown isKindOfClass:[NSNumber class]]) {
        userSettings.blockUnknown = blockUnknown.boolValue;
    }
    
    NSNumber *hideInactiveIds = [self getMdmConfigurationBoolForKey:MDM_KEY_HIDE_INACTIVE_IDS];
    if ([hideInactiveIds isKindOfClass:[NSNumber class]]) {
        userSettings.hideStaleContacts = hideInactiveIds.boolValue;
    }
    
    NSNumber *contactSync = [self getMdmConfigurationBoolForKey:MDM_KEY_CONTACT_SYNC];
    if ([contactSync isKindOfClass:[NSNumber class]]) {
        userSettings.syncContacts = contactSync.boolValue;
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_SAVE_TO_GALLERY]) {
        userSettings.autoSaveMedia = ![self disableSaveToGallery];
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_MESSAGE_PREVIEW]) {
        userSettings.pushDecrypt = ![self disableMessagePreview];
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_CALLS]) {
        if ([ThreemaEnvironment supportsCallKit]) {
            userSettings.enableThreemaCall = ![self disableCalls];
            if ([self disableCalls]) {
                userSettings.enableThreemaGroupCalls = false;
            }
        }
        else {
            userSettings.enableThreemaCall = false;
        }
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_GROUP_CALLS]) {
        // TODO: IOS-3878 OS Integration
        if ([ThreemaEnvironment supportsCallKit]) {
            userSettings.enableThreemaGroupCalls = ![self disableGroupCalls];
        }
        else {
            userSettings.enableThreemaGroupCalls = false;
        }
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_VIDEO_CALLS]) {
        userSettings.enableVideoCall= ![self disableVideoCalls];
    }
            
    if ([self existsMdmKey:MDM_KEY_DISABLE_SEND_PROFILE_PICTURE]) {
        if ([self disableSendProfilePicture]) {
            [userSettings setSendProfilePicture:SendProfilePictureNone];
        }
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_WORK_DIRECTORY]) {
        userSettings.companyDirectory = ![self disableWorkDirectory];
    }
    
    if ([self existsMdmKey:MDM_KEY_DISABLE_MULTIDEVICE]) {
        if ([self disableMultiDevice]) {
            [self runDisableMultiDeviceWithCompletionHandler:^{
                // do nothing
            }];
        }
    }
    else if ([self existsMdmKey:MDM_KEY_DISABLE_WEB] && [self disableWeb]) {
        [self runDisableMultiDeviceWithCompletionHandler:^{
            // do nothing
        }];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSettingStoreSynchronization object:nil];
}

- (void)loadLicenseInfo {
    if (!isLicenseRequired) {
        return;
    }
    
    NSString *licenseUsername = [self getMdmConfigurationValueForKey:MDM_KEY_LICENSE_USERNAME];
    if ([licenseUsername isKindOfClass:[NSString class]] && licenseUsername.length > 0) {
        [LicenseStore sharedLicenseStore].licenseUsername = licenseUsername;
    }
    
    NSString *licensePassword = [self getMdmConfigurationValueForKey:MDM_KEY_LICENSE_PASSWORD];
    if ([licensePassword isKindOfClass:[NSString class]] && licensePassword.length > 0) {
        [LicenseStore sharedLicenseStore].licensePassword = licensePassword;
    }
    
    NSString *onPremConfigUrl = [self onPremConfigUrl];
    if (onPremConfigUrl != nil && [[LicenseStore sharedLicenseStore] validCustomOnPremConfigUrlWithPredefinedUrl:onPremConfigUrl]) {
        [LicenseStore sharedLicenseStore].onPremConfigUrl = onPremConfigUrl;
    }
}

- (void)loadIDCreationValues {
    // We should set firstname, lastname, csi and category when mdm is empty
    // Do nothing for consumer
    if (!isLicenseRequired) {
        return;
    }
    
    MyIdentityStore *identityStore = [MyIdentityStore sharedMyIdentityStore];

    NSString *nickname = [self getMdmConfigurationValueForKey:MDM_KEY_NICKNAME];
    if ([nickname isKindOfClass:[NSString class]] && nickname.length > 0 && nickname.length < 32) {
        identityStore.pushFromName = nickname;
    }
    
    NSNumber *contactSync = [self getMdmConfigurationBoolForKey:MDM_KEY_CONTACT_SYNC];
    if ([contactSync isKindOfClass:[NSNumber class]]) {
        [UserSettings sharedUserSettings].syncContacts = contactSync.boolValue;
    }
    
    NSString *email = [self getMdmConfigurationValueForKey:MDM_KEY_LINKED_EMAIL];
    if ([email isKindOfClass:[NSString class]] && email.length > 0) {
        identityStore.createIDEmail = email;
    }
    
    NSString *phone = [self getMdmConfigurationValueForKey:MDM_KEY_LINKED_PHONE];
    if ([phone isKindOfClass:[NSString class]] && phone.length > 0) {
        identityStore.createIDPhone = phone;
    }
    
    // Set the firstname to nil if the key is not set or the value is empty
    // because the user can't edit this value
    if ([self existsMdmKey:MDM_KEY_FIRST_NAME]) {
        NSString *firstName = [self getMdmConfigurationValueForKey:MDM_KEY_FIRST_NAME];
        if ([firstName isKindOfClass:[NSString class]]) {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues firstname is %@", firstName);
            identityStore.firstName = firstName;
        } else {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues firstname is not a string");
            identityStore.firstName = nil;
        }
    } else {
        DDLogNotice(@"[MDMSetup] loadIDCreationValues firstname is missing in MDM");
        identityStore.firstName = nil;
    }
    
    // Set the lastname to nil if the key is not set or the value is empty
    // because the user can't edit this value
    if ([self existsMdmKey:MDM_KEY_LAST_NAME]) {
        NSString *lastName = [self getMdmConfigurationValueForKey:MDM_KEY_LAST_NAME];
        if ([lastName isKindOfClass:[NSString class]]) {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues lastName is %@", lastName);
            identityStore.lastName = lastName;
        } else {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues lastName is not a string");
            identityStore.lastName = nil;
        }
    } else {
        DDLogNotice(@"[MDMSetup] loadIDCreationValues lastName is missing in MDM");
        identityStore.lastName = nil;
    }
    
    // Set the csi to nil if the key is not set or the value is empty
    // because the user can't edit this value
    if ([self existsMdmKey:MDM_KEY_CSI]) {
        NSString *csi = [self getMdmConfigurationValueForKey:MDM_KEY_CSI];
        if ([csi isKindOfClass:[NSString class]]) {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues csi is %@", csi);
            identityStore.csi = csi;
        } else {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues csi is not a string");
            identityStore.csi = nil;
        }
    } else {
        DDLogNotice(@"[MDMSetup] loadIDCreationValues csi is missing in MDM");
        identityStore.csi = nil;
    }
    
    // Set the job title to nil if the key is not set or the value is empty
    // because the user can't edit this value
    if ([self existsMdmKey:MDM_KEY_JOB_TITLE]) {
        NSString *jobTitle = [self getMdmConfigurationValueForKey:MDM_KEY_JOB_TITLE];
        if ([jobTitle isKindOfClass:[NSString class]]) {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues job title is %@", jobTitle);
            identityStore.jobTitle = jobTitle;
        } else {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues job title is not a string");
            identityStore.jobTitle = nil;
        }
    } else {
        DDLogNotice(@"[MDMSetup] loadIDCreationValues job title is missing in MDM");
        identityStore.jobTitle = nil;
    }
    
    // Set the department to nil if the key is not set or the value is empty
    // because the user can't edit this value
    if ([self existsMdmKey:MDM_KEY_DEPARTMENT]) {
        NSString *department = [self getMdmConfigurationValueForKey:MDM_KEY_DEPARTMENT];
        if ([department isKindOfClass:[NSString class]]) {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues department is %@", department);
            identityStore.department = department;
        } else {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues department is not a string");
            identityStore.department = nil;
        }
    } else {
        DDLogNotice(@"[MDMSetup] loadIDCreationValues department is missing in MDM");
        identityStore.department = nil;
    }
    
    
    // Set the category to nil if the key is not set or the value is empty
    // because the user can't edit this value
    if ([self existsMdmKey:MDM_KEY_CATEGORY]) {
        NSString *category = [self getMdmConfigurationValueForKey:MDM_KEY_CATEGORY];
        if ([category isKindOfClass:[NSString class]]) {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues category is %@", category);
            identityStore.category = category;
        } else {
            DDLogNotice(@"[MDMSetup] loadIDCreationValues category is not a string");
            identityStore.category = nil;
        }
    } else {
        DDLogNotice(@"[MDMSetup] loadIDCreationValues category is missing in MDM");
        identityStore.category = nil;
    }
}

- (BOOL)hasIDBackup {
    if (!isLicenseRequired) {
        return NO;
    }
    
    _idBackup = [self getMdmConfigurationValueForKey:MDM_KEY_ID_BACKUP];
    if ([_idBackup isKindOfClass:[NSString class]] == NO || _idBackup.length < 1) {
        return NO;
    }
    
    _idBackupPassword = [self getMdmConfigurationValueForKey:MDM_KEY_ID_BACKUP_PASSWORD];
    
    return YES;
}

- (void)restoreIDBackupOnCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    if ([self hasIDBackup] == NO) {
        return;
    }
    
    MyIdentityStore *identityStore = [MyIdentityStore sharedMyIdentityStore];
    
    [identityStore restoreFromBackup:_idBackup withPassword:_idBackupPassword onCompletion:^{
        ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
        /* Obtain server group from server */
        [apiConnector updateMyIdentityStore:identityStore onCompletion:^{
            
            [identityStore storeInKeychain];
            
            [AppSetup setState:AppSetupStateIdentityAdded];
            
            [[LicenseStore sharedLicenseStore] performUpdateWorkInfo];
            
            onCompletion();
        } onError:^(NSError *error) {
            onError(error);
        }];
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (NSString *)supportDescriptionString {
    NSString *supportDescriptionString;
    
    if ([[self getThreemaMDM] valueForKey:MDM_KEY_THREEMA_PARAMS] != nil && [[[self getThreemaMDM] valueForKey:MDM_KEY_THREEMA_PARAMS] allKeys].count > 0) {
        supportDescriptionString = [@"" stringByAppendingString:@"m"];
    }
    
    if ([self getCompanyMDM] != nil && [[self getCompanyMDM] allKeys].count > 0) {
        if (supportDescriptionString != nil) {
            supportDescriptionString = [supportDescriptionString stringByAppendingString:@"e"];
        } else {
            supportDescriptionString = [@"" stringByAppendingString:@"e"];
        }
    }
    
    return supportDescriptionString;
}

- (BOOL)existsMdmKey:(NSString*)mdmKey {
    NSDictionary *mdm = [self getMdmConfiguration];
    return [[mdm allKeys] containsObject:mdmKey];
}

- (void)applyCompanyMDMWithCachedThreemaMDMSendForce:(BOOL)sendForce {
    if ([AppGroup getCurrentType] != AppGroupTypeApp) {
        return;
    }
        
    NSMutableDictionary *workData = [NSMutableDictionary new];
    NSDictionary *threemaMdm = [self getThreemaMDM];
    if (threemaMdm != nil) {
        [workData setObject:threemaMdm forKey:MDM_KEY_THREEMA_CONFIGURATION];
    }
    [self applyThreemaMdm:workData sendForce:sendForce];
}

- (void)applyThreemaMdm:(NSDictionary *)workData sendForce:(BOOL)sendForce {
    if (!isLicenseRequired) {
        return;
    }

    dispatch_sync(queue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *threemaMdm = nil;

        // Only update MDM settings if key exists in work data
        // This means MDM settings are only reset if the key is returned with no settings in it.
        if (workData != nil && [[workData allKeys] containsObject:MDM_KEY_THREEMA_CONFIGURATION]) {
            threemaMdm = [defaults dictionaryForKey:MDM_THREEMA_CONFIGURATION_KEY];

            NSDictionary *newThreemaMdm = workData[MDM_KEY_THREEMA_CONFIGURATION];
            NSMutableDictionary *currentThreemaMdm = [[NSMutableDictionary alloc] initWithDictionary:threemaMdm];

            if([currentThreemaMdm isEqualToDictionary:newThreemaMdm] == NO) {
                // remove missing Threema MDM parameters
                NSMutableArray *missingMdmKeys = [[NSMutableArray alloc] init];
                NSMutableDictionary *currentThreemaMdmParameters = [[NSMutableDictionary alloc] initWithDictionary:currentThreemaMdm[MDM_KEY_THREEMA_PARAMS]];
                [currentThreemaMdmParameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    if ([[newThreemaMdm[MDM_KEY_THREEMA_PARAMS] allKeys] containsObject:key] == NO) {
                        [missingMdmKeys addObject:key];
                    }
                }];
                [currentThreemaMdmParameters removeObjectsForKeys:missingMdmKeys];
                [currentThreemaMdm setObject:currentThreemaMdmParameters forKey:MDM_KEY_THREEMA_PARAMS];

                // apply new Threema MDM parameters
                BOOL override = ((NSNumber *)newThreemaMdm[MDM_KEY_THREEMA_OVERRIDE]).boolValue;
                NSDictionary *newThreemaMdmParameters = [self applyMdmParameters:currentThreemaMdm[MDM_KEY_THREEMA_PARAMS] source:newThreemaMdm[MDM_KEY_THREEMA_PARAMS] override:override];

                NSMutableDictionary *newThreemaMdmConfiguration = [[NSMutableDictionary alloc] initWithDictionary:threemaMdm];
                [newThreemaMdmConfiguration setObject:newThreemaMdmParameters forKey:MDM_KEY_THREEMA_PARAMS];
                [newThreemaMdmConfiguration setObject:[NSNumber numberWithBool:override] forKey:MDM_KEY_THREEMA_OVERRIDE];
                threemaMdm = newThreemaMdmConfiguration;
            }

            // store Threema MDM
            [defaults setObject:threemaMdm forKey:MDM_THREEMA_CONFIGURATION_KEY];
            [defaults synchronize];
        }

        [MDMSetup clearMdmCache];
    });

    [self loadIDCreationValues];
    [self loadRenewableValues];

    [[LicenseStore sharedLicenseStore] performUpdateWorkInfoForce:sendForce];

    [self sync];
    [self syncSettingCalls];
}

- (NSDictionary*)getCompanyMDM {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults dictionaryForKey:MDM_CONFIGURATION_KEY];
    
    // Fake company MDM parameters here
   // return @{MDM_KEY_SAFE_PASSWORD: @"pw123456", MDM_KEY_SAFE_SERVER_USERNAME: @"user"};
}

- (NSDictionary*)getThreemaMDM {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults dictionaryForKey:MDM_THREEMA_CONFIGURATION_KEY];
}

- (NSDictionary*)getMdmConfiguration {
    __block NSDictionary *mdm;
    dispatch_sync(queue, ^{
        if (isLicenseRequired) {
            if (!isSetup) {
                if (_mdmCache == nil) {
                    _mdmCache = [self getMDMParameters:[self getCompanyMDM] threemaMDM:[self getThreemaMDM]];
                    if ([_mdmCache valueForKey:MDM_KEY_SAFE_PASSWORD] != nil) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kSafeBackupPasswordCheck object:nil userInfo:nil];
                    }
                }
                mdm = _mdmCache;
            } else {
                if (_mdmCacheSetup == nil) {
                    _mdmCacheSetup = [self getMDMParameters:[self getCompanyMDM] threemaMDM:[self getThreemaMDM]];
                    if ([_mdmCache valueForKey:MDM_KEY_SAFE_PASSWORD] != nil) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:kSafeBackupPasswordCheck object:nil userInfo:nil];
                    }
                }
                mdm = _mdmCacheSetup;
            }
        } else {
            mdm = [[NSDictionary alloc] init];
        }
    });
    return mdm;
}

- (NSDictionary*)getMDMParameters:(NSDictionary*)companyMdm threemaMDM:(NSDictionary*)threemaMdm {
    if (companyMdm != nil) {
        if (threemaMdm != nil) {
            // Merge company and Threema MDM
            BOOL override = ((NSNumber *)threemaMdm[MDM_KEY_THREEMA_OVERRIDE]).boolValue;
            NSDictionary *newMdm = [self applyMdmParameters:companyMdm source:threemaMdm[MDM_KEY_THREEMA_PARAMS] override:override];
            DDLogNotice(@"\n[MDMSetup] Company MDM");
            [self printMDMIntoDebugLog:companyMdm];
            
            DDLogNotice(@"\n[MDMSetup] Threema MDM");
            [self printMDMIntoDebugLog:threemaMdm];
            
            DDLogNotice(@"\n[MDMSetup] Merged Company and Threema MDM");
            [self printMDMIntoDebugLog:newMdm];
            return newMdm;
        } else {
            // use Company MDM
            DDLogNotice(@"\n[MDMSetup] Company MDM");
            [self printMDMIntoDebugLog:companyMdm];
            return companyMdm;
        }
    } else if (threemaMdm != nil && [[threemaMdm allKeys] containsObject:MDM_KEY_THREEMA_PARAMS]) {
        // use Threema MDM
        NSDictionary *destinationMdm = [[NSDictionary alloc] init];
        BOOL override = ((NSNumber *)threemaMdm[MDM_KEY_THREEMA_OVERRIDE]).boolValue;
        NSDictionary *newMdm = [self applyMdmParameters:destinationMdm source:threemaMdm[MDM_KEY_THREEMA_PARAMS] override:override];
        
        DDLogNotice(@"[MDMSetup] Threema MDM");
        [self printMDMIntoDebugLog:newMdm];
        
        return newMdm;
    }
    
     // Print empty mdm
    DDLogNotice(@"[MDMSetup] Company and Threema MDM is empty");
    return [[NSDictionary alloc] init];
}

- (NSDictionary*)applyMdmParameters:(NSDictionary*)destination source:(NSDictionary*)source override:(BOOL)override {
    NSMutableDictionary *mdmParameters = [[NSMutableDictionary alloc] initWithDictionary:destination];
    
    // Apply parameter if is override and renewable or missing
    [[source allKeys] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self shouldDiscardInThreemaMDM:key]) {
            return;
        }
        if (override == YES && [self isRenewable:key]) {
            if ([[mdmParameters allKeys] containsObject:key]) {
                [mdmParameters setValue:source[key] forKey:key];
            } else {
                [mdmParameters addEntriesFromDictionary:@{key: source[key]}];
            }
        }
        if (isSetup == YES && [[mdmParameters allKeys] containsObject:key] == NO) {
            [mdmParameters addEntriesFromDictionary:@{key: source[key]}];
        }
        else if  (isSetup == YES && override == YES && [[mdmParameters allKeys] containsObject:key] == YES) {
            [mdmParameters setValue:source[key] forKey:key];
        }
    }];
    
    return mdmParameters;
}

- (void)deleteThreemaMdm {
    dispatch_sync(queue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:MDM_THREEMA_CONFIGURATION_KEY];
        [defaults synchronize];
        
        [MDMSetup clearMdmCache];
    });
}

- (BOOL)isRenewable:(NSString *)mdmKey {
    NSArray *renewableKeys = @[MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD, MDM_KEY_NICKNAME, MDM_KEY_FIRST_NAME, MDM_KEY_LAST_NAME, MDM_KEY_CSI, MDM_KEY_JOB_TITLE, MDM_KEY_DEPARTMENT, MDM_KEY_CATEGORY, MDM_KEY_READONLY_PROFILE, MDM_KEY_BLOCK_UNKNOWN, MDM_KEY_HIDE_INACTIVE_IDS, MDM_KEY_DISABLE_SAVE_TO_GALLERY, MDM_KEY_DISABLE_ADD_CONTACT, MDM_KEY_DISABLE_EXPORT, MDM_KEY_DISABLE_BACKUPS, MDM_KEY_DISABLE_ID_EXPORT, MDM_KEY_DISABLE_SYSTEM_BACKUPS, MDM_KEY_DISABLE_MESSAGE_PREVIEW, MDM_KEY_DISABLE_SEND_PROFILE_PICTURE, MDM_KEY_DISABLE_CALLS, MDM_KEY_DISABLE_GROUP_CALLS, MDM_KEY_DISABLE_CREATE_GROUP, MDM_KEY_DISABLE_WEB, MDM_KEY_DISABLE_MULTIDEVICE, MDM_KEY_WEB_HOSTS, MDM_KEY_SAFE_ENABLE, MDM_KEY_SAFE_PASSWORD, MDM_KEY_SAFE_SERVER_URL, MDM_KEY_SAFE_SERVER_USERNAME, MDM_KEY_SAFE_SERVER_PASSWORD, MDM_KEY_SAFE_PASSWORD_PATTERN, MDM_KEY_SAFE_PASSWORD_MESSAGE, MDM_KEY_DISABLE_SHARE_MEDIA, MDM_KEY_DISABLE_WORK_DIRECTORY, MDM_KEY_CONTACT_SYNC, MDM_KEY_DISABLE_VIDEO_CALLS, MDM_KEY_ONPREM_SERVER, MDM_KEY_KEEP_MESSAGE_DAYS];
    return [renewableKeys containsObject:mdmKey];
}

- (BOOL)shouldDiscardInThreemaMDM:(NSString *)mdmKey{
    NSArray *notAvailableInThreemaMDM = @[MDM_KEY_ID_BACKUP, MDM_KEY_ID_BACKUP_PASSWORD, MDM_KEY_SAFE_PASSWORD, MDM_KEY_LICENSE_USERNAME, MDM_KEY_LICENSE_PASSWORD];
    return [notAvailableInThreemaMDM containsObject:mdmKey];
}

- (NSNumber*)getMdmConfigurationBoolForKey:(NSString*)key {
    // Some MDMs cannot send real booleans, so we support "true"/"1" and "false"/"0" as strings also
    id mdmVal = [self getMdmConfigurationValueForKey:key];
    if ([mdmVal isKindOfClass:[NSNumber class]]) {
        return mdmVal;
    } else if ([mdmVal isKindOfClass:[NSString class]]) {
        if ([mdmVal caseInsensitiveCompare:@"true"] == NSOrderedSame || [mdmVal isEqualToString:@"1"]) {
            return [NSNumber numberWithBool:YES];
        } else if ([mdmVal caseInsensitiveCompare:@"false"] == NSOrderedSame || [mdmVal isEqualToString:@"0"]) {
            return [NSNumber numberWithBool:NO];
        }
    }
    return nil;
}

- (id)getMdmConfigurationValueForKey:(NSString*)key {
    NSDictionary *mdm = [self getMdmConfiguration];
    return mdm[key];
}

- (void)printMDMIntoDebugLog:(NSDictionary *)mdm {
    if ([[mdm allKeys] containsObject:MDM_KEY_THREEMA_PARAMS]) {
        BOOL override = ((NSNumber *)mdm[MDM_KEY_THREEMA_OVERRIDE]).boolValue;
        DDLogNotice(@"[MDMSetup] %@: %@", MDM_KEY_THREEMA_OVERRIDE, override ? @"true" : @"false");
        
        for(NSString *key in mdm[MDM_KEY_THREEMA_PARAMS]) {
            [self checkIsPasswordAndLog:key value:[mdm[MDM_KEY_THREEMA_PARAMS] objectForKey:key]];
        }
    } else {
        for(NSString *key in mdm) {
            [self checkIsPasswordAndLog:key value:[mdm objectForKey:key]];
        }
    }
}

- (void)checkIsPasswordAndLog:(NSString *)key value:(NSString *)value {
    if (![key containsString:@"pass"] || [key isEqualToString:MDM_KEY_SAFE_PASSWORD_PATTERN] || [key isEqualToString:MDM_KEY_SAFE_PASSWORD_MESSAGE] || value == nil) {
        DDLogNotice(@"[MDMSetup] %@: %@", key, value);
    } else {
        DDLogNotice(@"[MDMSetup] %@: ***", key);
    }
}

@end
