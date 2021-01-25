//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

@interface UserSettings : NSObject

enum SendProfilePicture {
    SendProfilePictureNone = 0,
    SendProfilePictureAll,
    SendProfilePictureContacts
};

enum AcceptPrivacyPolicyVariant {
    AcceptPrivacyPolicyVariantExplicitly = 0,
    AcceptPrivacyPolicyVariantImplicitly,
    AcceptPrivacyPolicyVariantUpdate
};

enum ThreemaVideoCallQualitySetting {
    ThreemaVideoCallQualitySettingAuto = 0,
    ThreemaVideoCallQualitySettingLowDataConsumption,
    ThreemaVideoCallQualitySettingMaximumQuality
};

@property (nonatomic, readwrite) BOOL sendReadReceipts;
@property (nonatomic, readwrite) BOOL syncContacts;
@property (nonatomic, strong) NSArray *syncExclusionList;
@property (nonatomic, strong) NSOrderedSet *blacklist;
@property (nonatomic, strong) NSOrderedSet *workIdentities;
@property (nonatomic, strong) NSOrderedSet *pushSettingsList;
@property (nonatomic, readwrite) BOOL sendTypingIndicator;
@property (nonatomic, readwrite) BOOL blockUnknown;
@property (nonatomic, readwrite) BOOL enablePoi;
@property (nonatomic, readwrite) BOOL hideStaleContacts;

@property (nonatomic, readwrite) BOOL inAppSounds;
@property (nonatomic, readwrite) BOOL inAppVibrate;
@property (nonatomic, readwrite) BOOL inAppPreview;
@property (nonatomic, strong) NSString *pushSound;
@property (nonatomic, strong) NSString *pushGroupSound;
@property (nonatomic, readwrite) BOOL pushDecrypt;
@property (nonatomic, readwrite) BOOL pushShowNickname;

@property (nonatomic, strong) NSString *imageSize;
@property (nonatomic, strong) NSString *videoQuality;
@property (nonatomic, readwrite) BOOL autoSaveMedia;

@property (nonatomic, readwrite) float chatFontSize;
@property (nonatomic, readwrite) BOOL useDynamicFontSize;
@property (nonatomic, readwrite) BOOL disableBigEmojis;
@property (nonatomic, readwrite) BOOL showReceivedTimestamps;
@property (nonatomic, readwrite) BOOL returnToSend;
@property (nonatomic, readwrite) BOOL darkTheme;
@property (nonatomic, readwrite) BOOL useSystemTheme;
@property (nonatomic, readwrite) BOOL showProfilePictures;

@property (nonatomic, strong) UIImage *wallpaper;

@property (nonatomic, readwrite) BOOL sortOrderFirstName;
@property (nonatomic, readwrite) BOOL displayOrderFirstName;

@property (nonatomic, readwrite) BOOL validationLogging;
@property (nonatomic, readwrite) BOOL enableIPv6;

@property (nonatomic, readwrite) BOOL companyDirectory;

@property (nonatomic, readwrite) BOOL askedForPushDecryption;

@property (nonatomic, readwrite) enum SendProfilePicture sendProfilePicture;
@property (nonatomic, strong) NSArray *profilePictureContactList;
@property (nonatomic, strong) NSArray *profilePictureRequestList;
@property (nonatomic, readwrite) BOOL showGalleryPreview;
@property (nonatomic, readwrite) BOOL disableProximityMonitoring;
@property (nonatomic, readwrite) BOOL enableThreemaCall;
@property (nonatomic, readwrite) BOOL alwaysRelayCalls;
@property (nonatomic, readwrite) BOOL enableCallKit;

@property (nonatomic, readwrite) float previewLimit;

@property (nonatomic, strong) NSDate *acceptedPrivacyPolicyDate;
@property (nonatomic, readwrite) enum AcceptPrivacyPolicyVariant acceptedPrivacyPolicyVariant;

@property (nonatomic, strong) NSString *voIPSound;

@property (nonatomic, readonly) NSInteger largeTitleDisplayMode;

@property (nonatomic, readwrite) BOOL pushGroupGenerated;

@property (nonatomic, readwrite) BOOL threemaWeb;

@property (nonatomic, readwrite) BOOL openPlusIconInChat;

@property (nonatomic, strong) NSData *safeConfig;
@property (nonatomic, readwrite) BOOL safeIntroShown;

@property (nonatomic, readwrite) BOOL workInfoShown;
@property (nonatomic, readwrite) BOOL videoCallInChatInfoShown;
@property (nonatomic, readwrite) BOOL videoCallInfoShown;
@property (nonatomic, readwrite) BOOL videoCallSpeakerInfoShown;

@property (nonatomic, strong) NSString *sentryAppDevice;

@property (nonatomic, readwrite) BOOL enableMasterDnd;
@property (nonatomic, strong) NSOrderedSet *masterDndWorkingDays;
@property (nonatomic, strong) NSString *masterDndStartTime;
@property (nonatomic, strong) NSString *masterDndEndTime;

@property (nonatomic, readwrite) BOOL enableVideoCall;
@property (nonatomic, readwrite) enum ThreemaVideoCallQualitySetting threemaVideoCallQualitySetting;

+ (UserSettings*)sharedUserSettings;

+ (void)resetSharedInstance;

- (void)setSortOrderFirstName:(BOOL)sortOrderFirstName displayOrderFirstName:(BOOL)displayOrderFirstName;
- (void)checkWallpaper;

@end
