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

#import "UserSettings.h"
#import "AppGroup.h"
#import "LicenseStore.h"
#import "DatabaseManager.h"
#import "ServerConnector.h"
#import "MyIdentityStore.h"
#import "AvatarMaker.h"
#import "ValidationLogger.h"
#import "PushSetting.h"
#import "EntityManager.h"
#import "EntityFetcher.h"
#import "NSString+Hex.h"
#import "Conversation.h"
#import "Contact.h"

typedef NS_ENUM(NSInteger, ThreemaAudioMessagePlaySpeed) {
    ThreemaAudioMessagePlaySpeedHalf = 0,
    ThreemaAudioMessagePlaySpeedSingle,
    ThreemaAudioMessagePlaySpeedOneAndHalf,
    ThreemaAudioMessagePlaySpeedDouble
};

@implementation UserSettings {
    NSUserDefaults *defaults;
    enum ThreemaAudioMessagePlaySpeed threemaAudioMessagePlaySpeed;
}

@synthesize sendReadReceipts;
@synthesize syncContacts;
@synthesize syncExclusionList;
@synthesize blacklist;
@synthesize workIdentities;
@synthesize pushSettingsList;
@synthesize sendTypingIndicator;
@synthesize blockUnknown;
@synthesize enablePoi;
@synthesize hideStaleContacts;

@synthesize inAppSounds;
@synthesize inAppVibrate;
@synthesize inAppPreview;
@synthesize pushSound;
@synthesize pushGroupGenerated;
@synthesize pushGroupSound;
@synthesize pushDecrypt;
@synthesize pushShowNickname;

@synthesize imageSize;
@synthesize videoQuality;
@synthesize autoSaveMedia;

@synthesize chatFontSize;
@synthesize useDynamicFontSize;
@synthesize disableBigEmojis;
@synthesize wallpaper;
@synthesize showReceivedTimestamps;
@synthesize returnToSend;
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
@synthesize disableProximityMonitoring;

@synthesize enableThreemaCall;
@synthesize alwaysRelayCalls;
@synthesize enableCallKit;

@synthesize previewLimit;

@synthesize acceptedPrivacyPolicyDate;
@synthesize acceptedPrivacyPolicyVariant;

@synthesize voIPSound;

@synthesize threemaWeb;

@synthesize openPlusIconInChat;

@synthesize safeConfig;
@synthesize safeIntroShown;

@synthesize workInfoShown;
@synthesize videoCallInChatInfoShown;
@synthesize videoCallInfoShown;
@synthesize videoCallSpeakerInfoShown;

@synthesize sentryAppDevice;

@synthesize enableMasterDnd;
@synthesize masterDndWorkingDays;
@synthesize masterDndStartTime;
@synthesize masterDndEndTime;

@synthesize enableVideoCall;
@synthesize threemaVideoCallQualitySetting;

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
        
        NSMutableOrderedSet *tmpNoPushIdentities = [NSMutableOrderedSet orderedSetWithArray:[defaults arrayForKey:@"NoPushIdentities"]];
        if (tmpNoPushIdentities.array.count > 0) {
            [self pushSettingsMigration:tmpNoPushIdentities];
        }
        
        BOOL defaultDarkTheme = NO;
        BOOL defaultUseSystemTheme = true;
        BOOL defaultWorkInfoShown = false;
        if ([LicenseStore requiresLicenseKey]) {
            defaultDarkTheme = YES;
            defaultUseSystemTheme = false;
            defaultWorkInfoShown = true;
        }
        
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES], @"SendReadReceipts",
                                        [NSNumber numberWithBool:NO],  @"SyncContacts",
                                        [NSArray array], @"SyncExclusionList",
                                        [NSArray array], @"Blacklist",
                                        [NSArray array], @"WorkIdentities",
                                        [NSArray array], @"PushSettingsList",
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
                                        [NSNumber numberWithFloat:16.0f], @"ChatFontSize",
                                        [NSNumber numberWithBool:YES], @"UseDynamicFontSize",
                                        [NSNumber numberWithBool:NO], @"DisableBigEmojis",
                                        [NSNumber numberWithBool:YES], @"ShowReceivedTimestamps",
                                        [NSNumber numberWithBool:NO], @"ReturnToSend",
                                        [NSNumber numberWithBool:defaultDarkTheme], @"DarkTheme",
                                        [NSNumber numberWithBool:defaultUseSystemTheme], @"UseSystemTheme",
                                        [NSNumber numberWithBool:YES], @"ShowProfilePictures",
                                        [NSNumber numberWithBool:NO], @"SortOrderFirstName",
                                        [NSNumber numberWithBool:YES], @"DisplayOrderFirstName",
                                        @"default", @"PushSound",
                                        [NSNumber numberWithBool:NO], @"PushGroupGenerated",
                                        @"default", @"PushGroupSound",
                                        [NSNumber numberWithBool:NO], @"PushDecrypt",
                                        [NSNumber numberWithBool:NO], @"PushShowNickname",
                                        [NSNumber numberWithBool:NO], @"ValidationLogging",
                                        [NSNumber numberWithBool:YES], @"EnableIPv6",
                                        [NSNumber numberWithBool:NO], @"CompanyDirectory",
                                        [NSNumber numberWithBool:NO], @"AskedForPushDecryption",
                                        [NSNumber numberWithInt:SendProfilePictureAll], @"SendProfilePicture",
                                        [NSArray array], @"ProfilePictureContactList",
                                        [NSArray array], @"ProfilePictureRequestList",
                                        [NSNumber numberWithBool:YES], @"ShowGalleryPreview",
                                        [NSNumber numberWithBool:NO], @"DisableProximityMonitoring",
                                        [NSNumber numberWithBool:YES], @"EnableThreemaCall",
                                        [NSNumber numberWithBool:NO], @"AlwaysRelayCalls",
                                        [NSNumber numberWithBool:YES], @"EnableCallKit",
                                        [NSNumber numberWithFloat:50.0], @"PreviewLimit",
                                        [NSNumber numberWithBool:YES], @"ThreemaWeb",
                                        [NSNumber numberWithBool:NO], @"OpenPlusIconInChat",
                                        [NSData data], @"SafeConfig",
                                        [NSNumber numberWithBool:NO], @"SafeIntroShown",
                                        [NSNumber numberWithBool:defaultWorkInfoShown], @"WorkInfoShown",
                                        [NSNumber numberWithBool:NO], @"VideoCallInChatInfoShown",
                                        [NSNumber numberWithBool:NO], @"VideoCallInfoShown",
                                        [NSNumber numberWithBool:NO], @"VideoCallSpeakerInfoShown",
                                        [NSNumber numberWithBool:NO], @"EnableMasterDnd",
                                        [NSArray array], @"MasterDNDWorkingDays",
                                        @"08:00", @"MasterDNDStartTime",
                                        @"17:00", @"MasterDNDEndTime",
                                        [NSNumber numberWithBool:YES], @"EnableVideoCall",
                                        [NSNumber numberWithInt:ThreemaVideoCallQualitySettingAuto], @"ThreemaVideoCallQualitySetting",
                                        @"", @"SentryAppDevice",
                                        [NSNumber numberWithInt:ThreemaAudioMessagePlaySpeedSingle], @"ThreemaAudioMessagePlaySpeed",
                                     nil];
        [defaults registerDefaults:appDefaults];
        
        
        [self initFromUserDefaults];
    }
    return self;
}

- (void)initFromUserDefaults {
    sendReadReceipts = [defaults boolForKey:@"SendReadReceipts"];
    syncContacts = [defaults boolForKey:@"SyncContacts"];
    syncExclusionList = [defaults arrayForKey:@"SyncExclusionList"];
    blacklist = [NSOrderedSet orderedSetWithArray:[defaults arrayForKey:@"Blacklist"]];
    workIdentities = [NSOrderedSet orderedSetWithArray:[defaults arrayForKey:@"WorkIdentities"]];
    pushSettingsList = [NSOrderedSet orderedSetWithArray:[defaults arrayForKey:@"PushSettingsList"]];
    sendTypingIndicator = [defaults boolForKey:@"SendTypingIndicator"];
    blockUnknown = [defaults boolForKey:@"BlockUnknown"];
    enablePoi = [defaults boolForKey:@"EnablePOI"];
    hideStaleContacts = [defaults boolForKey:@"HideStaleContacts"];
    
    inAppSounds = [defaults boolForKey:@"InAppSounds"];
    inAppVibrate = [defaults boolForKey:@"InAppVibrate"];
    inAppPreview = [defaults boolForKey:@"InAppPreview"];
    pushSound = [defaults stringForKey:@"PushSound"];
    pushGroupGenerated = [defaults boolForKey:@"PushGroupGenerated"];
    pushGroupSound = [defaults stringForKey:@"PushGroupSound"];
    pushDecrypt = [defaults boolForKey:@"PushDecrypt"];
    pushShowNickname = [defaults boolForKey:@"PushShowNickname"];
    
    imageSize = [defaults stringForKey:@"ImageSize"];
    videoQuality = [defaults stringForKey:@"VideoQuality"];
    autoSaveMedia = [defaults boolForKey:@"AutoSaveMedia"];
    
    chatFontSize = [defaults floatForKey:@"ChatFontSize"];
    useDynamicFontSize = [defaults boolForKey:@"UseDynamicFontSize"];
    disableBigEmojis = [defaults boolForKey:@"DisableBigEmojis"];
    showReceivedTimestamps = [defaults boolForKey:@"ShowReceivedTimestamps"];
    returnToSend = [defaults boolForKey:@"ReturnToSend"];
    darkTheme = [defaults boolForKey:@"DarkTheme"];
    useSystemTheme = [defaults boolForKey:@"UseSystemTheme"];
    showProfilePictures = [defaults boolForKey:@"ShowProfilePictures"];

    NSString *wallpaperPath = [self wallpaperPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:wallpaperPath]) {
        wallpaper = [UIImage imageWithContentsOfFile:wallpaperPath];
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
    disableProximityMonitoring = [defaults boolForKey:@"DisableProximityMonitoring"];
    
    enableThreemaCall = [defaults boolForKey:@"EnableThreemaCall"];
    alwaysRelayCalls = [defaults boolForKey:@"AlwaysRelayCalls"];
    enableCallKit = [defaults boolForKey:@"EnableCallKit"];
    
    previewLimit = [defaults floatForKey:@"PreviewLimit"];
    
    acceptedPrivacyPolicyDate = [defaults objectForKey:@"AcceptedPrivacyPolicyDate"];
    acceptedPrivacyPolicyVariant = [[defaults objectForKey:@"AcceptedPrivacyPolicyVariant"] intValue];
    
    voIPSound = [defaults stringForKey:@"VoIPSound"];
    
    threemaWeb = [defaults boolForKey:@"ThreemaWeb"];
    
    openPlusIconInChat = [defaults boolForKey:@"OpenPlusIconInChat"];
    
    safeConfig = [defaults dataForKey:@"SafeConfig"];
    safeIntroShown = [defaults boolForKey:@"SafeIntroShown"];
    
    workInfoShown = [defaults boolForKey:@"WorkInfoShown"];
    videoCallInChatInfoShown = [defaults boolForKey:@"VideoCallInChatInfoShown"];
    videoCallInfoShown = [defaults boolForKey:@"VideoCallInfoShown"];
    videoCallSpeakerInfoShown = [defaults boolForKey:@"VideoCallSpeakerInfoShown"];
    
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
}

- (void)pushSettingsMigration:(NSOrderedSet *)tmpNoPushIdentities {
    NSMutableOrderedSet *pushSettings = [NSMutableOrderedSet new];
    for (NSString *identity in tmpNoPushIdentities.array) {
        PushSetting *tmpPushSetting = [PushSetting new];
        tmpPushSetting.identity = identity;
        tmpPushSetting.type = kPushSettingTypeOff;
        tmpPushSetting.periodOffTime = 0;
        tmpPushSetting.periodOffTillDate = nil;
        tmpPushSetting.silent = false;
        tmpPushSetting.mentions = false;
        [pushSettings addObject:tmpPushSetting.buildDict];
    }
    [self setPushSettingsList:pushSettings];
    [defaults removeObjectForKey:@"NoPushIdentities"];
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

- (void)setPushSettingsList:(NSOrderedSet *)newPushSettingsList {
    pushSettingsList = newPushSettingsList;
    [defaults setObject:pushSettingsList.array forKey:@"PushSettingsList"];
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

- (void)setPushGroupGenerated:(BOOL)newPushGroupGenerated {
    pushGroupGenerated = newPushGroupGenerated;
    [defaults setBool:newPushGroupGenerated forKey:@"PushGroupGenerated"];
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

- (void)setPushShowNickname:(BOOL)newPushShowNickname {
    pushShowNickname = newPushShowNickname;
    [defaults setBool:pushShowNickname forKey:@"PushShowNickname"];
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

- (void)setChatFontSize:(float)newChatFontSize {
    chatFontSize = newChatFontSize;
    [defaults setFloat:chatFontSize forKey:@"ChatFontSize"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFontSizeChanged object:nil];
}

- (float)chatFontSize {
    if (useDynamicFontSize) {
        UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
        CGFloat size = fontDescriptor.pointSize;
        return size;
    } else {
        return chatFontSize;
    }
}

- (void)setUseDynamicFontSize:(BOOL)newUseDynamicFontSize {
    useDynamicFontSize = newUseDynamicFontSize;
    [defaults setBool:useDynamicFontSize forKey:@"UseDynamicFontSize"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFontSizeChanged object:nil];
}

- (void)setShowReceivedTimestamps:(BOOL)newShowReceivedTimestamps {
    showReceivedTimestamps = newShowReceivedTimestamps;
    [defaults setBool:showReceivedTimestamps forKey:@"ShowReceivedTimestamps"];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowTimestampSettingsChanged object:nil];
}

- (void)setReturnToSend:(BOOL)newReturnToSend {
    returnToSend = newReturnToSend;
    [defaults setBool:returnToSend forKey:@"ReturnToSend"];
    [defaults synchronize];
}

- (void)setDarkTheme:(BOOL)newDarkTheme {
    darkTheme = newDarkTheme;
    [defaults setBool:darkTheme forKey:@"DarkTheme"];
    [defaults synchronize];
    
    [StyleKit resetThemedCache];

    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationColorThemeChanged object:nil];
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
    [[AvatarMaker sharedAvatarMaker] clearCacheForProfilePicture];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowProfilePictureChanged object:nil];
}

- (void)setWallpaper:(UIImage *)_wallpaper {
    wallpaper = _wallpaper;
    
    if (_wallpaper != nil) {
        NSData *wallpaperData = UIImagePNGRepresentation(wallpaper);
        [wallpaperData writeToFile:[self wallpaperPath] atomically:NO];
        [[ValidationLogger sharedValidationLogger] logString:@"Wallpaper: Set wallpaper"];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:[self wallpaperPath] error:nil];
        [[ValidationLogger sharedValidationLogger] logString:@"Wallpaper: Removed wallpaper"];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationWallpaperChanged object:nil];
}

- (void)checkWallpaper {
    if (wallpaper == nil) {
        NSString *wallpaperPath = [self wallpaperPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:wallpaperPath]) {
            wallpaper = [UIImage imageWithContentsOfFile:wallpaperPath];
        }
    }
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFontSizeChanged object:nil];
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

- (void)setDisableProximityMonitoring:(BOOL)newDisableProximityMonitoring {
    disableProximityMonitoring = newDisableProximityMonitoring;
    [defaults setBool:disableProximityMonitoring forKey:@"DisableProximityMonitoring"];
    [defaults synchronize];
}
    
- (void)setEnableThreemaCall:(BOOL)newEnableThreemaCall {
    enableThreemaCall = newEnableThreemaCall;
    [defaults setBool:enableThreemaCall forKey:@"EnableThreemaCall"];
    [defaults synchronize];
}

- (void)setAlwaysRelayCalls:(BOOL)newAlwaysRelayCalls {
    alwaysRelayCalls = newAlwaysRelayCalls;
    [defaults setBool:alwaysRelayCalls forKey:@"AlwaysRelayCalls"];
    [defaults synchronize];
}
    
- (void)setEnableCallKit:(BOOL)newEnableCallKit {
    enableCallKit = newEnableCallKit;
    [defaults setBool:enableCallKit forKey:@"EnableCallKit"];
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

- (void)setWorkInfoShown:(BOOL)newWorkInfoShown {
    workInfoShown = newWorkInfoShown;
    [defaults setBool:workInfoShown forKey:@"WorkInfoShown"];
    [defaults synchronize];
}

- (void)setVideoCallInChatInfoShown:(BOOL)newVideoCallInChatInfoShown {
    videoCallInChatInfoShown = newVideoCallInChatInfoShown;
    [defaults setBool:videoCallInChatInfoShown forKey:@"VideoCallInChatInfoShown"];
    [defaults synchronize];
}

- (void)setVideoCallInfoShown:(BOOL)newVideoCallInfoShown {
    videoCallInfoShown = newVideoCallInfoShown;
    [defaults setBool:videoCallInfoShown forKey:@"VideoCallInfoShown"];
    [defaults synchronize];
}

- (void)setVideoCallSpeakerInfoShown:(BOOL)newVideoCallSpeakerInfoShown {
    videoCallSpeakerInfoShown = newVideoCallSpeakerInfoShown;
    [defaults setBool:videoCallSpeakerInfoShown forKey:@"VideoCallSpeakerInfoShown"];
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

@end
