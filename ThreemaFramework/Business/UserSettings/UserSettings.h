#import <Foundation/Foundation.h>

enum SendProfilePicture {
    SendProfilePictureNone = 0,
    SendProfilePictureAll,
    SendProfilePictureContacts
};

enum ThreemaVideoCallQualitySetting {
    ThreemaVideoCallQualitySettingAuto = 0,
    ThreemaVideoCallQualitySettingLowDataConsumption,
    ThreemaVideoCallQualitySettingMaximumQuality
};

typedef NS_ENUM(NSInteger, WallpaperType) {
    WallpaperTypeEmpty = 0,
    WallpaperTypeThreema = 1,
    WallpaperTypeCustom = 2
};

typedef NS_ENUM(NSInteger, UserInterfacePreference) {
    UserInterfacePreferenceSystem = 0,
    UserInterfacePreferenceLight = 1,
    UserInterfacePreferenceDark = 2
};


extern NSString * const kFeatureDistributionListsEnabled;
extern NSString * const kPreferenceInterfaceStyleKey;

@protocol UserSettingsProtocol <NSObject>

// Appearance
@property (nonatomic, readwrite) BOOL displayOrderFirstName;
@property (nonatomic, readwrite) BOOL hideStaleContacts;
@property (nonatomic, readwrite) float previewLimit;
@property (nonatomic, readwrite) BOOL showGalleryPreview;
@property (nonatomic, readwrite) BOOL showProfilePictures;
@property (nonatomic, readwrite) NSInteger interfaceStyle;

@property (nonatomic, readwrite) NSInteger appMigratedToVersion;
@property (nonatomic, readwrite) enum SendProfilePicture sendProfilePicture;
@property (nonatomic, strong) NSArray *profilePictureContactList;
@property (nonatomic, readwrite) BOOL syncContacts;
@property (nonatomic, readwrite) BOOL blockUnknown;
@property (nonatomic, readwrite) BOOL enablePoi;
@property (nonatomic, readwrite) BOOL sendReadReceipts;
@property (nonatomic, readwrite) BOOL sendTypingIndicator;
@property (nonatomic, readwrite) BOOL enableThreemaCall;
@property (nonatomic, readwrite) BOOL alwaysRelayCalls;
@property (nonatomic, readwrite) BOOL includeCallsInRecents;
@property (nonatomic, readwrite) BOOL enableVideoCall;
@property (nonatomic, readwrite) enum ThreemaVideoCallQualitySetting threemaVideoCallQualitySetting;
@property (nonatomic, readwrite) BOOL enableThreemaGroupCalls;
@property (nonatomic, strong) NSOrderedSet *blacklist;
@property (nonatomic, strong) NSArray *syncExclusionList;
@property (nonatomic, readwrite) enum WallpaperType wallpaperType;
@property (nonatomic, strong) NSData *wallpaper;
@property (nonatomic, readwrite) BOOL autoSaveMedia;
@property (nonatomic, readwrite) BOOL allowOutgoingDonations;

@property (nonatomic, readwrite) BOOL inAppSounds;
@property (nonatomic, readwrite) BOOL inAppVibrate;
@property (nonatomic, readwrite) BOOL inAppPreview;

@property (nonatomic, readwrite) BOOL sortOrderFirstName;
@property (nonatomic, strong) NSString *imageSize;
@property (nonatomic, strong) NSString *videoQuality;
@property (nonatomic, strong) NSString *voIPSound;
@property (nonatomic, strong) NSString *pushSound;
@property (nonatomic, strong) NSString *pushGroupSound;
@property (nonatomic, readwrite) NSNumber *notificationType;
@property (nonatomic, readwrite) BOOL pushDecrypt;
@property (nonatomic, strong) NSArray *pushSettings;
@property (nonatomic, readwrite) BOOL hidePrivateChats;
@property (nonatomic, readwrite) BOOL voiceMessagesShowTimeRemaining;

@property (nonatomic, readwrite) BOOL enableMasterDnd;
@property (nonatomic, strong) NSOrderedSet *masterDndWorkingDays;
@property (nonatomic, strong) NSString *masterDndStartTime;
@property (nonatomic, strong) NSString *masterDndEndTime;

@property (nonatomic, readwrite) BOOL sendMessageFeedback;
@property (nonatomic, readwrite) BOOL disableBigEmojis;

@property (nonatomic, readwrite) BOOL enableMultiDevice;
@property (nonatomic, readwrite) BOOL allowSeveralLinkedDevices;
@property (nonatomic, strong) NSOrderedSet *workIdentities;
@property (nonatomic, strong) NSArray *profilePictureRequestList;

@property (nonatomic, readwrite) BOOL enableIPv6;
@property (nonatomic, readwrite) BOOL validationLogging;
@property (nonatomic, strong) NSString *sentryAppDevice;

@property (nonatomic, readwrite) BOOL groupCallsDebugMessages;

@property (nonatomic, readwrite) NSInteger keepMessagesDays;

@property (nonatomic, readwrite) NSData *safeConfig;
@property (nonatomic, readwrite) BOOL safeIntroShown;

@property (nonatomic, readwrite) BOOL ipcCommunicationEnabled;
@property (nonatomic, readwrite) NSData *ipcSecretPrefix;

@property (nonatomic, readwrite) BOOL companyDirectory;

@end

@interface UserSettings : NSObject <UserSettingsProtocol>

typedef NS_ENUM(NSInteger, AcceptPrivacyPolicyVariant) {
    AcceptPrivacyPolicyVariantExplicitly = 0,
    AcceptPrivacyPolicyVariantImplicitly,
    AcceptPrivacyPolicyVariantUpdate
};

@property (nonatomic, readwrite) NSInteger interfaceStyle;
@property (nonatomic, readwrite) BOOL showProfilePictures;

@property (nonatomic, readwrite) BOOL displayOrderFirstName;

@property (nonatomic, readwrite) BOOL askedForPushDecryption;

@property (nonatomic, readwrite) BOOL showGalleryPreview;

@property (nonatomic, readwrite) float previewLimit;

@property (nonatomic, strong) NSDate *acceptedPrivacyPolicyDate;
@property (nonatomic, readwrite) enum AcceptPrivacyPolicyVariant acceptedPrivacyPolicyVariant;

@property (nonatomic, readonly) NSInteger largeTitleDisplayMode;

@property (nonatomic, readwrite) BOOL threemaWeb;

@property (nonatomic, readwrite) BOOL openPlusIconInChat;

@property (nonatomic, readwrite) NSData *evaluatedPolicyDomainStateApp;
@property (nonatomic, readwrite) NSData *evaluatedPolicyDomainStateShareExtension;

@property (nonatomic, readwrite) BOOL workInfoShown;
@property (nonatomic, readwrite) BOOL desktopInfoBannerShown;
@property (nonatomic, readwrite) BOOL resetTipKitOnNextLaunch;
@property (nonatomic, readwrite) BOOL jbDetectionDismissed;
@property (nonatomic, readwrite) BOOL partialReactionSupportAlertShown;

@property (nonatomic, readwrite) BOOL distributionListsEnabled;

+ (UserSettings*)sharedUserSettings;
- (instancetype) __unavailable init;

+ (void)resetSharedInstance;

- (void)setSortOrderFirstName:(BOOL)sortOrderFirstName displayOrderFirstName:(BOOL)displayOrderFirstName;
- (CGFloat)threemaAudioMessagePlaySpeedCurrentValue;
- (CGFloat)threemaAudioMessagePlaySpeedSwitchToNextValue;

@end
