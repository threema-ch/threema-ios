#import <Foundation/Foundation.h>

typedef enum : int {
    AppGroupTypeApp,
    AppGroupTypeShareExtension,
    AppGroupTypeNotificationExtension,
    AppGroupTypeNone,
} AppGroupType;

@interface AppGroup : NSObject

+ (void)setAppId:(NSString *)newAppId NS_SWIFT_NAME(setAppID(_:));

+ (void)setGroupId:(NSString *)newGroupId NS_SWIFT_NAME(setGroupID(_:));

+ (NSString *)groupId NS_SWIFT_NAME(groupID());

+ (void)setActive:(BOOL)active forType:(AppGroupType)type;

+ (AppGroupType)getActiveType;

+ (AppGroupType)getCurrentType;

+ (NSString *)getCurrentTypeString;

+ (void)setMeActive;

+ (void)setMeInactive;

+ (BOOL)amIActive;

+ (BOOL)areOthersActive;

+ (NSUserDefaults *)userDefaults;

+ (void)resetUserDefaults;

+ (void)notifyAppGroupSyncNeeded;

+ (nonnull NSString *)nameForType:(AppGroupType)type;

@end
