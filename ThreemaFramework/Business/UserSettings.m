//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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

#import "UserSettings.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "DatabaseManager.h"
#import "ServerConnector.h"
#import "MyIdentityStore.h"
#import "ValidationLogger.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "EntityFetcher.h"
#import "NSString+Hex.h"

typedef NS_ENUM(NSInteger, ThreemaAudioMessagePlaySpeed) {
    ThreemaAudioMessagePlaySpeedHalf = 0,
    ThreemaAudioMessagePlaySpeedSingle,
    ThreemaAudioMessagePlaySpeedOneAndQuarter,
    ThreemaAudioMessagePlaySpeedOneAndHalf,
    ThreemaAudioMessagePlaySpeedDouble
};

@implementation UserSettings {
    NSUserDefaults *defaults;
    enum ThreemaAudioMessagePlaySpeed threemaAudioMessagePlaySpeed;
}

@synthesize appMigratedToVersion;

@synthesize sendReadReceipts;
@synthesize syncContacts;
@synthesize syncExclusionList;
@synthesize blacklist;
@synthesize workIdentities;
@synthesize pushSettings;
@synthesize sendTypingIndicator;
@synthesize blockUnknown;
@synthesize enablePoi;
@synthesize allowOutgoingDonations;
@synthesize hideStaleContacts;

@synthesize inAppSounds;
@synthesize inAppVibrate;
@synthesize inAppPreview;
@synthesize pushSound;
@synthesize pushGroupSound;
@synthesize notificationType;
@synthesize pushDecrypt;

@synthesize imageSize;
@synthesize videoQuality;
@synthesize autoSaveMedia;

@synthesize disableBigEmojis;
@synthesize sendMessageFeedback;
@synthesize wallpaper;
@synthesize darkTheme;
@synthesize useSystemTheme;
@synthesize showProfilePictures;

@synthesize sortOrderFirstName;
@synthesize displayOrderFirstName;

@synthesize validationLogging;
@synthesize enableIPv6;

@synthesize companyDirectory;

@synthesize askedForPushDecryption;

@synthesize sendProfilePicture;
@synthesize profilePictureContactList;
@synthesize profilePictureRequestList;

@synthesize showGalleryPreview;

@synthesize enableThreemaCall;
@synthesize alwaysRelayCalls;
@synthesize includeCallsInRecents;
@synthesize enableThreemaGroupCalls;

@synthesize previewLimit;

@synthesize acceptedPrivacyPolicyDate;
@synthesize acceptedPrivacyPolicyVariant;

@synthesize voIPSound;

@synthesize threemaWeb;

@synthesize openPlusIconInChat;

@synthesize enableMultiDevice;
@synthesize deviceID;
@synthesize allowSeveralLinkedDevices;

@synthesize safeConfig;
@synthesize safeIntroShown;

@synthesize workInfoShown;
@synthesize desktopInfoBannerShown;

@synthesize sentryAppDevice;

@synthesize enableMasterDnd;
@synthesize masterDndWorkingDays;
@synthesize masterDndStartTime;
@synthesize masterDndEndTime;

@synthesize enableVideoCall;
@synthesize threemaVideoCallQualitySetting;

@synthesize evaluatedPolicyDomainStateApp;
@synthesize evaluatedPolicyDomainStateShareExtension;

@synthesize hidePrivateChats;
@synthesize voiceMessagesShowTimeRemaining;

@synthesize groupCallsDebugMessages;

@synthesize keepMessagesDays;
@synthesize partialReactionSupportAlertShown;

@synthesize resetTipKitOnNextLaunch;
@synthesize jbDetectionDismissed;
@synthesize contactList2;
@synthesize ipcCommunicationEnabled;
@synthesize ipcSecretPrefix;
@synthesize newNavigationEnabled;

/// Deprecated Keys, please add keys if they are removed:
/// - `featureFlagEnableNoMIMETypeFileMessagesFilter`
/// - `PushShowNickname`
/// - `NewChatViewActive`
/// - `GroupCallsDeveloper`
/// - `NewProfileActive`
/// - `NewSettingsActive`
/// - `UnknownGroupAlertList`
/// - `VideoCallInChatInfoShown`
/// - `VideoCallInfoShown`
/// - `VideoCallSpeakerInfoShown`
/// - `EnableFSv1_2ForTesting`
/// - `useProfilePictureGenerator`
/// - `BlockCommunication`
/// - `SendEmojiReactions`
/// - `DisableProximityMonitoring`

static UserSettings *instance;

+ (UserSettings*)sharedUserSettings {
	
	@synchronized (self) {
		if (!instance)
			instance = [[UserSettings alloc] init];
	}
	
	return instance;
}

+ (void)resetSharedInstance {
    [instance initFromUserDefaults];
}

- (id)init
{
    self = [super init];
    if (self) {
        defaults = [AppGroup userDefaults];
        
        /* Push group sound migration */
        if ([defaults stringForKey:@"PushGroupSound"] == nil) {
            [self setPushGroupSound:[defaults stringForKey:@"PushSound"]];
        }
        
        if ([defaults stringForKey:@"VoIPSound"] == nil) {
            [self setVoIPSound:@"threema_best"];
        }
        
        BOOL defaultDarkTheme = NO;
        BOOL defaultUseSystemTheme = true;
        BOOL defaultWorkInfoShown = false;
        if (TargetManagerObjc.isBusinessApp) {
            defaultDarkTheme = YES;
            defaultUseSystemTheme = false;
            defaultWorkInfoShown = true;
        }
        
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @0, @"AppMigratedToVersion",
                                        [NSNumber numberWithBool:YES], @"SendReadReceipts",
                                        [NSNumber numberWithBool:NO],  @"SyncContacts",
                                        [NSArray array], @"SyncExclusionList",
                                        [NSArray array], @"Blacklist",
                                        [NSArray array], @"WorkIdentities",
                                        [NSArray array], @"PushSettings",
                                        [NSNumber numberWithBool:YES], @"SendTypingIndicator",
                                        [NSNumber numberWithBool:YES], @"InAppSounds",
                                        [NSNumber numberWithBool:YES], @"InAppVibrate",
                                        [NSNumber numberWithBool:YES], @"InAppPreview",
                                        [NSNumber numberWithBool:NO],  @"BlockUnknown",
                                        [NSNumber numberWithBool:YES],  @"EnablePOI",
                                        [NSNumber numberWithBool:NO],  @"HideStaleContacts",
                                        @"large", @"ImageSize",
                                        @"high", @"VideoQuality",
                                        [NSNumber numberWithBool:NO],  @"AutoSaveMedia",
                                        [NSNumber numberWithBool:NO], @"DisableBigEmojis",
                                        [NSNumber numberWithBool:YES], @"SendMessageFeedback",
                                        [NSNumber numberWithBool:defaultDarkTheme], @"DarkTheme",
                                        [NSNumber numberWithBool:defaultUseSystemTheme], @"UseSystemTheme",
                                        [NSNumber numberWithBool:YES], @"ShowProfilePictures",
                                        [NSNumber numberWithBool:NO], @"SortOrderFirstName",
                                        [NSNumber numberWithBool:YES], @"DisplayOrderFirstName",
                                        @"default", @"PushSound",
                                        @"default", @"PushGroupSound",
                                        [NSNumber numberWithBool:YES], @"PushDecrypt",
                                        [NSNumber numberWithInt:1], @"NotificationType",
                                        [NSNumber numberWithBool:NO], @"ValidationLogging",
                                        [NSNumber numberWithBool:YES], @"EnableIPv6",
                                        [NSNumber numberWithBool:NO], @"CompanyDirectory",
                                        [NSNumber numberWithBool:NO], @"AskedForPushDecryption",
                                        [NSNumber numberWithInt:SendProfilePictureAll], @"SendProfilePicture",
                                        [NSArray array], @"ProfilePictureContactList",
                                        [NSArray array], @"ProfilePictureRequestList",
                                        [NSNumber numberWithBool:YES], @"ShowGalleryPreview",
                                        [NSNumber numberWithBool:YES], @"EnableThreemaCall",
                                        [NSNumber numberWithBool:YES], @"EnableThreemaGroupCalls",
                                        [NSNumber numberWithBool:NO], @"AlwaysRelayCalls",
                                        /// This setting was renamed but we needed to keep the key
                                        [NSNumber numberWithBool:YES], @"EnableCallKit",
                                        [NSNumber numberWithFloat:50.0], @"PreviewLimit",
                                        [NSNumber numberWithBool:YES], @"ThreemaWeb",
                                        [NSNumber numberWithBool:NO], @"OpenPlusIconInChat",
                                        [NSNumber numberWithBool:NO], @"EnableMultiDevice",
                                        [NSNumber numberWithBool:NO], @"AllowSeveralLinkedDevices",
                                        [NSData data], @"DeviceID",
                                        [NSData data], @"SafeConfig",
                                        [NSNumber numberWithBool:NO], @"SafeIntroShown",
                                        [NSNumber numberWithBool:defaultWorkInfoShown], @"WorkInfoShown",
                                        [NSNumber numberWithBool:NO], @"DesktopInfoBannerShown",
                                        [NSNumber numberWithBool:NO], @"EnableMasterDnd",
                                        [NSArray array], @"MasterDNDWorkingDays",
                                        @"08:00", @"MasterDNDStartTime",
                                        @"17:00", @"MasterDNDEndTime",
                                        [NSNumber numberWithBool:YES], @"EnableVideoCall",
                                        [NSNumber numberWithInt:ThreemaVideoCallQualitySettingAuto], @"ThreemaVideoCallQualitySetting",
                                        @"", @"SentryAppDevice",
                                        [NSNumber numberWithInt:ThreemaAudioMessagePlaySpeedSingle], @"ThreemaAudioMessagePlaySpeed",
                                        [NSNumber numberWithBool:NO], @"HidePrivateChats",
                                        [NSNumber numberWithBool:NO], @"VoiceMessagesShowTimeRemaining",
                                        [NSNumber numberWithBool:NO], @"GroupCallsDebugMessages",
                                        @-1, @"KeepMessagesDays",
                                        [NSNumber numberWithBool:NO], @"PartialReactionSupportAlertShown",
                                        [NSNumber numberWithBool:NO], @"ResetTipKitOnNextLaunch",
                                        [NSNumber numberWithBool:NO], @"JBDetectionDismissed",
                                        [NSNumber numberWithBool:NO], @"ContactList2",
                                        [NSNumber numberWithBool:NO], @"NewNavigationEnabled",
                                        [NSData data], @"IPCSecretPrefix",

                                     nil];
                                     //Keys `EvaluatedPolicyDomainStateApp` and `EvaluatedPolicyDomainStateShareExtension` are intentionally not set, since we need them to be `nil` the first time.
        
        [defaults registerDefaults:appDefaults];
        
        [self initFromUserDefaults];
    }
    return self;
}

- (void)initFromUserDefaults {
    appMigratedToVersion = [defaults integerForKey:@"AppMigratedToVersion"];
    sendReadReceipts = [defaults boolForKey:@"SendReadReceipts"];
    syncContacts = [defaults boolForKey:@"SyncContacts"];
    syncExclusionList = [defaults arrayForKey:@"SyncExclusionList"];
    blacklist = [NSOrderedSet orderedSetWithArray:[defaults arrayForKey:@"Blacklist"]];
    allowOutgoingDonations = [defaults boolForKey:@"AllowOutgoingDonations"];
    workIdentities = [NSOrderedSet orderedSetWithArray:[defaults arrayForKey:@"WorkIdentities"]];
    pushSettings = [defaults arrayForKey:@"PushSettings"];
    sendTypingIndicator = [defaults boolForKey:@"SendTypingIndicator"];
    blockUnknown = [defaults boolForKey:@"BlockUnknown"];
    enablePoi = [defaults boolForKey:@"EnablePOI"];
    hideStaleContacts = [defaults boolForKey:@"HideStaleContacts"];

    inAppSounds = [defaults boolForKey:@"InAppSounds"];
    inAppVibrate = [defaults boolForKey:@"InAppVibrate"];
    inAppPreview = [defaults boolForKey:@"InAppPreview"];
    pushSound = [defaults stringForKey:@"PushSound"];
    pushGroupSound = [defaults stringForKey:@"PushGroupSound"];
    pushDecrypt = [defaults boolForKey:@"PushDecrypt"];
    notificationType = [defaults objectForKey: @"NotificationType"];

    imageSize = [defaults stringForKey:@"ImageSize"];
    videoQuality = [defaults stringForKey:@"VideoQuality"];
    autoSaveMedia = [defaults boolForKey:@"AutoSaveMedia"];

    disableBigEmojis = [defaults boolForKey:@"DisableBigEmojis"];
    sendMessageFeedback = [defaults boolForKey:@"SendMessageFeedback"];
    if (ProcessInfoHelper.isRunningForScreenshots) {
        if (ProcessInfoHelper.predefinedThemeLight) {
            darkTheme = false;
            useSystemTheme = false;
        }
        else if (ProcessInfoHelper.predefinedThemeDark) {
            darkTheme = true;
            useSystemTheme = false;
        }
        else {
            darkTheme = false;
            useSystemTheme = true;
        }
    }
    else {
        darkTheme = [defaults boolForKey:@"DarkTheme"];
        useSystemTheme = [defaults boolForKey:@"UseSystemTheme"];
    }
    showProfilePictures = [defaults boolForKey:@"ShowProfilePictures"];

    NSString *wallpaperPath = [self wallpaperPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:wallpaperPath]) {
        wallpaper = [NSData dataWithContentsOfFile:wallpaperPath];
    }

    sortOrderFirstName = [defaults boolForKey:@"SortOrderFirstName"];
    displayOrderFirstName = [defaults boolForKey:@"DisplayOrderFirstName"];

    validationLogging = [defaults boolForKey:@"ValidationLogging"];
    enableIPv6 = [defaults boolForKey:@"EnableIPv6"];
    companyDirectory = [defaults boolForKey:@"CompanyDirectory"];

    askedForPushDecryption = [defaults boolForKey:@"AskedForPushDecryption"];

    sendProfilePicture = [[defaults objectForKey:@"SendProfilePicture"] intValue];

    profilePictureContactList = [defaults arrayForKey:@"ProfilePictureContactList"];
    profilePictureRequestList = [defaults arrayForKey:@"ProfilePictureRequestList"];

    showGalleryPreview = [defaults boolForKey:@"ShowGalleryPreview"];

    enableThreemaCall = [defaults boolForKey:@"EnableThreemaCall"];
    enableThreemaGroupCalls = [defaults boolForKey:@"EnableThreemaGroupCalls"];
    alwaysRelayCalls = [defaults boolForKey:@"AlwaysRelayCalls"];

    /// This setting was renamed but we needed to keep the key
    includeCallsInRecents = [defaults boolForKey:@"EnableCallKit"];

    previewLimit = [defaults floatForKey:@"PreviewLimit"];

    acceptedPrivacyPolicyDate = [defaults objectForKey:@"AcceptedPrivacyPolicyDate"];
    acceptedPrivacyPolicyVariant = [[defaults objectForKey:@"AcceptedPrivacyPolicyVariant"] intValue];

    voIPSound = [defaults stringForKey:@"VoIPSound"];

    threemaWeb = [defaults boolForKey:@"ThreemaWeb"];

    openPlusIconInChat = [defaults boolForKey:@"OpenPlusIconInChat"];

    enableMultiDevice = [defaults boolForKey:@"EnableMultiDevice"];
    deviceID = [defaults dataForKey:@"DeviceID"];
    allowSeveralLinkedDevices = [defaults boolForKey:@"AllowSeveralLinkedDevices"];

    groupCallsDebugMessages = [defaults boolForKey:@"GroupCallsDebugMessages"];
    keepMessagesDays = [defaults integerForKey:@"KeepMessagesDays"];

    safeConfig = [defaults dataForKey:@"SafeConfig"];
    safeIntroShown = [defaults boolForKey:@"SafeIntroShown"];
    evaluatedPolicyDomainStateApp = [defaults dataForKey:@"EvaluatedPolicyDomainStateApp"];
    evaluatedPolicyDomainStateShareExtension = [defaults dataForKey:@"EvaluatedPolicyDomainStateShareExtension"];

    workInfoShown = [defaults boolForKey:@"WorkInfoShown"];
    desktopInfoBannerShown = [defaults boolForKey:@"DesktopInfoBannerShown"];

    NSString *tmpSentryAppDevice = [defaults stringForKey:@"SentryAppDevice"];
    if (tmpSentryAppDevice != nil) {
        if ([tmpSentryAppDevice isEqualToString:@""]) {
            sentryAppDevice = nil;
        } else {
            sentryAppDevice = [defaults stringForKey:@"SentryAppDevice"];
        }
    } else {
        sentryAppDevice = nil;
    }
    enableMasterDnd = [defaults boolForKey:@"EnableMasterDnd"];
    masterDndWorkingDays = [NSOrderedSet orderedSetWithArray:[defaults arrayForKey:@"MasterDNDWorkingDays"]];
    masterDndStartTime = [defaults objectForKey:@"MasterDNDStartTime"];
    masterDndEndTime = [defaults objectForKey:@"MasterDNDEndTime"];

    enableVideoCall = [defaults boolForKey:@"EnableVideoCall"];
    threemaVideoCallQualitySetting = [[defaults objectForKey:@"ThreemaVideoCallQualitySetting"] intValue];

    threemaAudioMessagePlaySpeed = [[defaults objectForKey:@"ThreemaAudioMessagePlaySpeed"] intValue];

    hidePrivateChats = [defaults boolForKey:@"HidePrivateChats"];
    voiceMessagesShowTimeRemaining = [defaults boolForKey:@"VoiceMessagesShowTimeRemaining"];
    resetTipKitOnNextLaunch = [defaults boolForKey:@"ResetTipKitOnNextLaunch"];
    partialReactionSupportAlertShown = [defaults boolForKey:@"PartialReactionSupportAlertShown"];
    
    jbDetectionDismissed = [defaults boolForKey:@"JBDetectionDismissed"];
    contactList2 = [defaults boolForKey:@"ContactList2"];
    newNavigationEnabled = [defaults boolForKey:@"NewNavigationEnabled"];

    if ([ThreemaEnvironment env] == EnvironmentTypeXcode) {
        ipcCommunicationEnabled = [defaults boolForKey:@"IPCCommunicationEnabled"];
    }
    else {
        ipcCommunicationEnabled = false;
    }

    ipcSecretPrefix = [defaults objectForKey:@"IPCSecretPrefix"];
}

- (void)setAppMigratedToVersion:(NSInteger)newAppMigratedToVersion {
    appMigratedToVersion = newAppMigratedToVersion;
    [defaults setInteger:appMigratedToVersion forKey:@"AppMigratedToVersion"];
    [defaults synchronize];
}

- (void)setSendReadReceipts:(BOOL)newSendReadReceipts {
    sendReadReceipts = newSendReadReceipts;
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Read receipts bug: set flag to %@", newSendReadReceipts ? @"true" : @"false"]];

    [defaults setBool:sendReadReceipts forKey:@"SendReadReceipts"];
    [defaults synchronize];
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Read receipts bug: It's now set to %@", [defaults boolForKey:@"SendReadReceipts"] ? @"true" : @"false"]];
}

- (void)setSyncContacts:(BOOL)newSyncContacts {
    syncContacts = newSyncContacts;
    [defaults setBool:syncContacts forKey:@"SyncContacts"];
    [defaults synchronize];
}

- (void)setSyncExclusionList:(NSArray *)newSyncExclusionList {
    syncExclusionList = newSyncExclusionList;
    [defaults setObject:syncExclusionList forKey:@"SyncExclusionList"];
    [defaults synchronize];
}

- (void)setBlacklist:(NSOrderedSet *)newBlacklist {
    blacklist = newBlacklist;
    [defaults setObject:blacklist.array forKey:@"Blacklist"];
    [defaults synchronize];
}

- (void)setWorkIdentities:(NSOrderedSet *)newWorkIdentities {
    workIdentities = newWorkIdentities;
    [defaults setObject:workIdentities.array forKey:@"WorkIdentities"];
    [defaults synchronize];
}

- (void)setPushSettings:(NSArray *)newPushSettings {
    pushSettings = newPushSettings;
    [defaults setObject:pushSettings forKey:@"PushSettings"];
    [defaults synchronize];
}

- (void)setSendTypingIndicator:(BOOL)newSendTypingIndicator {
    sendTypingIndicator = newSendTypingIndicator;
    [defaults setBool:sendTypingIndicator forKey:@"SendTypingIndicator"];
    [defaults synchronize];
}

- (void)setBlockUnknown:(BOOL)newBlockUnknown {
    blockUnknown = newBlockUnknown;
    [defaults setBool:blockUnknown forKey:@"BlockUnknown"];
    [defaults synchronize];
}

- (void)setEnablePoi:(BOOL)newEnablePoi {
    enablePoi = newEnablePoi;
    [defaults setBool:enablePoi forKey:@"EnablePOI"];
    [defaults synchronize];
}

- (void)setAllowOutgoingDonations:(BOOL)newAllowOutgoingDonations {
    allowOutgoingDonations = newAllowOutgoingDonations;
    [defaults setBool:allowOutgoingDonations forKey:@"AllowOutgoingDonations"];
    [defaults synchronize];
}

- (void)setNotificationType:(NSNumber *)newNotificationType {
    notificationType = newNotificationType;
    [defaults setObject:notificationType forKey:@"NotificationType"];
    [defaults synchronize];
}

- (void)setHideStaleContacts:(BOOL)newHideStaleContacts {
    hideStaleContacts = newHideStaleContacts;
    [defaults setBool:hideStaleContacts forKey:@"HideStaleContacts"];
    [defaults synchronize];
}

- (void)setInAppSounds:(BOOL)newInAppSounds {
    inAppSounds = newInAppSounds;
    [defaults setBool:inAppSounds forKey:@"InAppSounds"];
    [defaults synchronize];
}

- (void)setInAppVibrate:(BOOL)newInAppVibrate {
    inAppVibrate = newInAppVibrate;
    [defaults setBool:inAppVibrate forKey:@"InAppVibrate"];
    [defaults synchronize];
}

- (void)setInAppPreview:(BOOL)newInAppPreview {
    inAppPreview = newInAppPreview;
    [defaults setBool:inAppPreview forKey:@"InAppPreview"];
    [defaults synchronize];
}

- (void)setPushSound:(NSString *)newPushSound {
    pushSound = newPushSound;
    [defaults setObject:pushSound forKey:@"PushSound"];
    [defaults synchronize];
}

- (void)setPushGroupSound:(NSString *)newPushGroupSound {
    pushGroupSound = newPushGroupSound;
    [defaults setObject:pushGroupSound forKey:@"PushGroupSound"];
    [defaults synchronize];
}

- (void)setPushDecrypt:(BOOL)newPushDecrypt {
    pushDecrypt = newPushDecrypt;
    [defaults setBool:pushDecrypt forKey:@"PushDecrypt"];
    [defaults synchronize];
}

- (void)setImageSize:(NSString *)newImageSize {
    imageSize = newImageSize;
    [defaults setObject:imageSize forKey:@"ImageSize"];
    [defaults synchronize];
}

- (void)setVideoQuality:(NSString *)newVideoQuality {
    videoQuality = newVideoQuality;
    [defaults setObject:videoQuality forKey:@"VideoQuality"];
    [defaults synchronize];
}

- (void)setAutoSaveMedia:(BOOL)newAutoSaveMedia {
    autoSaveMedia = newAutoSaveMedia;
    [defaults setBool:autoSaveMedia forKey:@"AutoSaveMedia"];
    [defaults synchronize];
}

- (void)setDarkTheme:(BOOL)newDarkTheme {
    darkTheme = newDarkTheme;
    [defaults setBool:darkTheme forKey:@"DarkTheme"];
    [defaults synchronize];
}

- (void)setUseSystemTheme:(BOOL)newUseSystemTheme {
    useSystemTheme = newUseSystemTheme;
    [defaults setBool:useSystemTheme forKey:@"UseSystemTheme"];
    [defaults synchronize];
}

- (void)setShowProfilePictures:(BOOL)newShowProfilePictures {
    showProfilePictures = newShowProfilePictures;
    [defaults setBool:showProfilePictures forKey:@"ShowProfilePictures"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowProfilePictureChanged object:nil];
}

- (void)setWallpaper:(NSData *)_wallpaper {
    wallpaper = _wallpaper;
    
    if (wallpaper != nil) {
        [wallpaper writeToFile:[self wallpaperPath] atomically:NO];
        [[ValidationLogger sharedValidationLogger] logString:@"Wallpaper: Set wallpaper"];
    }
    else {
        [[NSFileManager defaultManager] removeItemAtPath:[self wallpaperPath] error:nil];
        [[ValidationLogger sharedValidationLogger] logString:@"Wallpaper: Removed wallpaper"];
    }
   
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationWallpaperChanged object:nil];
}

- (void)setSortOrderFirstName:(BOOL)newSortOrderFirstName displayOrderFirstName:(BOOL)newDisplayOrderFirstName {
    if (sortOrderFirstName == newSortOrderFirstName && displayOrderFirstName == newDisplayOrderFirstName)
        return;
    
    sortOrderFirstName = newSortOrderFirstName;
    displayOrderFirstName = newDisplayOrderFirstName;
    [defaults setBool:sortOrderFirstName forKey:@"SortOrderFirstName"];
    [defaults setBool:displayOrderFirstName forKey:@"DisplayOrderFirstName"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaContactsOrderChanged" object:nil];
}

- (void)setSortOrderFirstName:(BOOL)newSortOrderFirstName {
    if (sortOrderFirstName == newSortOrderFirstName)
        return;
    
    sortOrderFirstName = newSortOrderFirstName;
    [defaults setBool:sortOrderFirstName forKey:@"SortOrderFirstName"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaContactsOrderChanged" object:nil];
}

- (void)setDisplayOrderFirstName:(BOOL)newDisplayOrderFirstName {
    if (displayOrderFirstName == newDisplayOrderFirstName)
        return;
    
    displayOrderFirstName = newDisplayOrderFirstName;
    [defaults setBool:displayOrderFirstName forKey:@"DisplayOrderFirstName"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaContactsOrderChanged" object:nil];
}

- (NSString*)wallpaperPath {
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    return [documentsDir stringByAppendingPathComponent:@"wallpaper"];
}

- (void)setValidationLogging:(BOOL)newValidationLogging {
    validationLogging = newValidationLogging;
    [defaults setBool:validationLogging forKey:@"ValidationLogging"];
    [defaults synchronize];
}

- (void)setEnableIPv6:(BOOL)newEnableIPv6 {
    enableIPv6 = newEnableIPv6;
    [defaults setBool:enableIPv6 forKey:@"EnableIPv6"];
    [defaults synchronize];
}

- (void)setCompanyDirectory:(BOOL)newCompanyDirectory {
    companyDirectory = newCompanyDirectory;
    [defaults setBool:companyDirectory forKey:@"CompanyDirectory"];
    [defaults synchronize];
}

- (void)setDisableBigEmojis:(BOOL)newDisableBigEmojis {
    disableBigEmojis = newDisableBigEmojis;
    [defaults setBool:disableBigEmojis forKey:@"DisableBigEmojis"];
    [defaults synchronize];
}

- (void)setSendMessageFeedback:(BOOL)newSendMessageFeedback {
    sendMessageFeedback = newSendMessageFeedback;
    [defaults setBool:sendMessageFeedback forKey:@"SendMessageFeedback"];
    [defaults synchronize];
}

- (void)setAskedForPushDecryption:(BOOL)newAskedForPushDecryption {
    askedForPushDecryption = newAskedForPushDecryption;
    [defaults setBool:askedForPushDecryption forKey:@"AskedForPushDecryption"];
    [defaults synchronize];
}

- (void)setSendProfilePicture:(enum SendProfilePicture)newSendProfilePicture {
    sendProfilePicture = newSendProfilePicture;
    [defaults setObject:[NSNumber numberWithInt:newSendProfilePicture] forKey:@"SendProfilePicture"];
    [defaults synchronize];
}

- (void)setProfilePictureContactList:(NSArray *)newProfilePictureContactList {
    profilePictureContactList = newProfilePictureContactList;
    [defaults setObject:profilePictureContactList forKey:@"ProfilePictureContactList"];
    [defaults synchronize];
}

- (void)setProfilePictureRequestList:(NSArray *)newProfilePictureRequestList {
    profilePictureRequestList = newProfilePictureRequestList;
    [defaults setObject:profilePictureRequestList forKey:@"ProfilePictureRequestList"];
    [defaults synchronize];
}

- (void)setShowGalleryPreview:(BOOL)newShowGalleryPreview {
    showGalleryPreview = newShowGalleryPreview;
    [defaults setBool:showGalleryPreview forKey:@"ShowGalleryPreview"];
    [defaults synchronize];
}
    
- (void)setEnableThreemaCall:(BOOL)newEnableThreemaCall {
    enableThreemaCall = newEnableThreemaCall;
    [defaults setBool:enableThreemaCall forKey:@"EnableThreemaCall"];
    [defaults synchronize];
}

- (void)setEnableThreemaGroupCalls:(BOOL)newEnableThreemaGroupCalls {
    enableThreemaGroupCalls = newEnableThreemaGroupCalls;
    [defaults setBool:enableThreemaGroupCalls forKey:@"EnableThreemaGroupCalls"];
    [defaults synchronize];
}

- (void)setAlwaysRelayCalls:(BOOL)newAlwaysRelayCalls {
    alwaysRelayCalls = newAlwaysRelayCalls;
    [defaults setBool:alwaysRelayCalls forKey:@"AlwaysRelayCalls"];
    [defaults synchronize];
}
    
- (void)setIncludeCallsInRecents:(BOOL)newIncludeCallsInRecents {
    includeCallsInRecents = newIncludeCallsInRecents;
    /// This setting was renamed but we needed to keep the key
    [defaults setBool:includeCallsInRecents forKey:@"EnableCallKit"];
    [defaults synchronize];
}

- (void)setPreviewLimit:(float)newPreviewLimit {
    previewLimit = newPreviewLimit;
    [defaults setFloat:previewLimit forKey:@"PreviewLimit"];
    [defaults synchronize];
}

- (void)setAcceptedPrivacyPolicyDate:(NSDate *)newAcceptedPrivacyPolicyDate {
    acceptedPrivacyPolicyDate = newAcceptedPrivacyPolicyDate;
    [defaults setObject:acceptedPrivacyPolicyDate forKey:@"AcceptedPrivacyPolicyDate"];
    [defaults synchronize];
}

- (void)setAcceptedPrivacyPolicyVariant:(enum AcceptPrivacyPolicyVariant)newAcceptedPrivacyPolicyVariant {
    acceptedPrivacyPolicyVariant = newAcceptedPrivacyPolicyVariant;
    [defaults setObject:[NSNumber numberWithInt:acceptedPrivacyPolicyVariant] forKey:@"AcceptedPrivacyPolicyVariant"];
    [defaults synchronize];
}

- (void)setVoIPSound:(NSString *)newVoIPSound {
    voIPSound = newVoIPSound;
    [defaults setObject:voIPSound forKey:@"VoIPSound"];
    [defaults synchronize];
}

- (NSInteger)largeTitleDisplayMode {
    return UINavigationItemLargeTitleDisplayModeAlways;
}

- (void)setThreemaWeb:(BOOL)newThreemaWeb {
    threemaWeb = newThreemaWeb;
    [defaults setBool:threemaWeb forKey:@"ThreemaWeb"];
    [defaults synchronize];
}

- (void)setOpenPlusIconInChat:(BOOL)newOpenPlusIconInChat {
    openPlusIconInChat = newOpenPlusIconInChat;
    [defaults setBool:openPlusIconInChat forKey:@"OpenPlusIconInChat"];
    [defaults synchronize];
}

- (void)setEnableMultiDevice:(BOOL)newEnableMultiDevice {
    enableMultiDevice = newEnableMultiDevice;
    [defaults setBool:enableMultiDevice forKey:@"EnableMultiDevice"];
    [defaults synchronize];
}

- (void)setDeviceID:(NSData *)newDeviceID {
    deviceID = newDeviceID;
    [defaults setObject:deviceID forKey:@"DeviceID"];
    [defaults synchronize];
}

- (void)setAllowSeveralLinkedDevices:(BOOL)newAllowSeveralLinkedDevices {
    allowSeveralLinkedDevices = newAllowSeveralLinkedDevices;
    [defaults setBool:allowSeveralLinkedDevices forKey:@"AllowSeveralLinkedDevices"];
    [defaults synchronize];
}

- (void)setGroupCallsDebugMessages:(BOOL)newGroupCallsDebugMessages {
    groupCallsDebugMessages = newGroupCallsDebugMessages;
    [defaults setBool:groupCallsDebugMessages forKey:@"GroupCallsDebugMessages"];
    [defaults synchronize];
}

- (void)setKeepMessagesDays:(NSInteger)newKeepMessagesDays {
    keepMessagesDays = newKeepMessagesDays;
    [defaults setInteger:keepMessagesDays forKey:@"KeepMessagesDays"];
    [defaults synchronize];
}

- (void)setSafeConfig:(NSData *)newSafeConfig {
    safeConfig = newSafeConfig;
    [defaults setObject:safeConfig forKey:@"SafeConfig"];
    [defaults synchronize];
}

- (void)setSafeIntroShown:(BOOL)newSafeIntroShown {
    safeIntroShown = newSafeIntroShown;
    [defaults setBool:safeIntroShown forKey:@"SafeIntroShown"];
    [defaults synchronize];
}

- (void)setEvaluatedPolicyDomainStateApp:(NSData *)newEvaluatedPolicyDomainState {
    evaluatedPolicyDomainStateApp = newEvaluatedPolicyDomainState;
    [defaults setObject:newEvaluatedPolicyDomainState forKey:@"EvaluatedPolicyDomainStateApp"];
    [defaults synchronize];
}

- (void)setEvaluatedPolicyDomainStateShareExtension:(NSData *)newEvaluatedPolicyDomainState {
    evaluatedPolicyDomainStateShareExtension = newEvaluatedPolicyDomainState;
    [defaults setObject:newEvaluatedPolicyDomainState forKey:@"EvaluatedPolicyDomainStateShareExtension"];
    [defaults synchronize];
}

- (void)setDesktopInfoBannerShown:(BOOL)newDesktopInfoBannerShown {
    desktopInfoBannerShown = newDesktopInfoBannerShown;
    [defaults setBool:desktopInfoBannerShown forKey:@"DesktopInfoBannerShown"];
    [defaults synchronize];
}

- (void)setWorkInfoShown:(BOOL)newWorkInfoShown {
    workInfoShown = newWorkInfoShown;
    [defaults setBool:workInfoShown forKey:@"WorkInfoShown"];
    [defaults synchronize];
}

- (void)setSentryAppDevice:(NSString *)newSentryAppDevice {
    sentryAppDevice = newSentryAppDevice;
    [defaults setObject:sentryAppDevice forKey:@"SentryAppDevice"];
    [defaults synchronize];
}

- (void)setEnableMasterDnd:(BOOL)newEnableMasterDnd {
    enableMasterDnd = newEnableMasterDnd;
    [defaults setBool:enableMasterDnd forKey:@"EnableMasterDnd"];
    [defaults synchronize];
}

- (void)setMasterDndWorkingDays:(NSOrderedSet *)newMasterDndWorkingDays {
    masterDndWorkingDays = newMasterDndWorkingDays;
    [defaults setObject:masterDndWorkingDays.array forKey:@"MasterDNDWorkingDays"];
    [defaults synchronize];
}

- (void)setMasterDndStartTime:(NSString *)newMasterDndStartTime {
    masterDndStartTime = newMasterDndStartTime;
    [defaults setObject:masterDndStartTime forKey:@"MasterDNDStartTime"];
    [defaults synchronize];
}

- (void)setMasterDndEndTime:(NSString *)newMasterDndEndTime {
    masterDndEndTime = newMasterDndEndTime;
    [defaults setObject:masterDndEndTime forKey:@"MasterDNDEndTime"];
    [defaults synchronize];
}

- (void)setEnableVideoCall:(BOOL)newEnableVideoCall {
    enableVideoCall = newEnableVideoCall;
    [defaults setBool:enableVideoCall forKey:@"EnableVideoCall"];
    [defaults synchronize];
}

- (void)setThreemaVideoCallQualitySetting:(enum ThreemaVideoCallQualitySetting)newThreemaVideoCallQualitySetting {
    threemaVideoCallQualitySetting = newThreemaVideoCallQualitySetting;
    [defaults setObject:[NSNumber numberWithInt:threemaVideoCallQualitySetting] forKey:@"ThreemaVideoCallQualitySetting"];
    [defaults synchronize];
}

/// Change the playback speed to the next value (0.5, 1, 1.5, 2)
/// @return The value of the new speed
- (CGFloat)threemaAudioMessagePlaySpeedSwitchToNextValue {
    if (threemaAudioMessagePlaySpeed == ThreemaAudioMessagePlaySpeedDouble) {
        threemaAudioMessagePlaySpeed = ThreemaAudioMessagePlaySpeedHalf;
    } else {
        threemaAudioMessagePlaySpeed = threemaAudioMessagePlaySpeed + 1;
    }

    
    [self setThreemaAudioMessagePlaySpeed:threemaAudioMessagePlaySpeed];
    return [self threemaAudioMessagePlaySpeedCurrentValue];
}

/// Return the current playback speed
- (CGFloat)threemaAudioMessagePlaySpeedCurrentValue {
    switch (threemaAudioMessagePlaySpeed) {
        case ThreemaAudioMessagePlaySpeedHalf:
            return 0.5;
        case ThreemaAudioMessagePlaySpeedSingle:
            return 1.0;
        case ThreemaAudioMessagePlaySpeedOneAndHalf:
            return 1.5;
        case ThreemaAudioMessagePlaySpeedOneAndQuarter:
            return 1.25;
        case ThreemaAudioMessagePlaySpeedDouble:
            return 2.0;
        default:
            return 1.0;
    }
}


/// Set the new playback speed and save it to the defaults (private function)
/// @param newThreemaAudioMessagePlaySpeed The new playback speed
- (void)setThreemaAudioMessagePlaySpeed:(enum ThreemaAudioMessagePlaySpeed)newThreemaAudioMessagePlaySpeed {
    threemaAudioMessagePlaySpeed = newThreemaAudioMessagePlaySpeed;
    [defaults setObject:[NSNumber numberWithInteger:threemaAudioMessagePlaySpeed] forKey:@"ThreemaAudioMessagePlaySpeed"];
    [defaults synchronize];
}

- (void)setHidePrivateChats:(BOOL)newHidePrivateChats {
    hidePrivateChats = newHidePrivateChats;
    [defaults setBool:hidePrivateChats forKey:@"HidePrivateChats"];
    [defaults synchronize];
}

- (void)setVoiceMessagesShowTimeRemaining:(BOOL)newVoiceMessagesShowTimeRemaining {
    voiceMessagesShowTimeRemaining = newVoiceMessagesShowTimeRemaining;
    [defaults setBool:voiceMessagesShowTimeRemaining forKey:@"VoiceMessagesShowTimeRemaining"];
    [defaults synchronize];
}

- (void)setResetTipKitOnNextLaunch:(BOOL)newResetTipKitOnNextLaunch {
    resetTipKitOnNextLaunch = newResetTipKitOnNextLaunch;
    [defaults setBool:resetTipKitOnNextLaunch forKey:@"ResetTipKitOnNextLaunch"];
    [defaults synchronize];
}
- (void)setPartialReactionSupportAlertShown:(BOOL)newPartialReactionSupportAlertShown {
    partialReactionSupportAlertShown = newPartialReactionSupportAlertShown;
    [defaults setBool:partialReactionSupportAlertShown forKey:@"PartialReactionSupportAlertShown"];
    [defaults synchronize];
}

- (void)setJbDetectionDismissed:(BOOL)newJBDetectionDismissed {
    jbDetectionDismissed = newJBDetectionDismissed;
    [defaults setBool:jbDetectionDismissed forKey:@"JBDetectionDismissed"];
    [defaults synchronize];
}

- (void)setContactList2:(BOOL)newContactList2 {
    contactList2 = newContactList2;
    [defaults setBool:contactList2 forKey:@"ContactList2"];
    [defaults synchronize];
}
- (void)setNewNavigationEnabled:(BOOL)newNewNavigationEnabled {
    newNavigationEnabled = newNewNavigationEnabled;
    [defaults setBool:newNavigationEnabled forKey:@"NewNavigationEnabled"];
    [defaults synchronize];
}

- (void)setIpcCommunicationEnabled:(BOOL)newIpcCommunicationEnabled {
    ipcCommunicationEnabled = newIpcCommunicationEnabled;
    [defaults setBool:ipcCommunicationEnabled forKey:@"IPCCommunicationEnabled"];
    [defaults synchronize];
}

- (void)setIpcSecretPrefix:(NSData *)newIpcSecretPrefix {
    ipcSecretPrefix = newIpcSecretPrefix;
    [defaults setObject:ipcSecretPrefix forKey:@"IPCSecretPrefix"];
    [defaults synchronize];
}

@end
