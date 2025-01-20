//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

#import "AppGroup.h"
#import "DatabaseManager.h"
#import "ValidationLogger.h"

#define KEY_APP_GROUP_TYPE_APP @"AppGroupTypeApp"
#define KEY_APP_GROUP_TYPE_NOTIFICATION_EXTENSION @"AppGroupTypeNotificationExtension"
#define KEY_APP_GROUP_TYPE_SHARE_EXTENSION @"AppGroupTypeShareExtension"

#define KEY_DID_MIGRATION_CHECK @"DefaultsKeyDidMigrationCheck"

#define THREEMA_NOTIFICATION_EXTENSION_SUFFIX @"NotificationExtension"
#define THREEMA_SHARE_EXTENSION_SUFFIX @"ShareExtension"

#define THREEMA_APP_GROUP_NOTIFICATION_SUFFIX @".SyncAppGroup"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

/*
    Tooling to determine if extension or app is running. 
    E.g. when the share extension is triggered from within the app there is no other way to know that.
 */

static NSString *appId;
static NSString *groupId;
static CFStringRef appSyncNotificationKey;

@implementation AppGroup

+ (void)setAppId:(NSString *)newAppId {
    NSAssert(appId == nil || [appId isEqualToString:newAppId], @"cannot change appId at runtime!");
    
    appId = newAppId;
    appSyncNotificationKey = CFBridgingRetain([NSString stringWithFormat:@"%@%@", appId, THREEMA_APP_GROUP_NOTIFICATION_SUFFIX]);

    [self registerAppGroupSyncObserver];
}

+ (void)setGroupId:(NSString *)newGroupId {
    NSAssert(groupId == nil || [groupId isEqualToString:newGroupId], @"cannot change groupId at runtime!");
    
    groupId = newGroupId;
}

+ (NSString *)groupId {
    NSAssert(groupId != nil, @"groupId not set");
    
    return groupId;
}

+ (void)setActive:(BOOL)active forType:(AppGroupType)type {
    NSAssert(appId != nil, @"appId not set, you need to set an id for the app or extension");

    // Log AppGroupType, because of connection problem (Notification Extension steals connection from App and contrary)
    NSString *appGroupTypeDesc;
    switch (type) {
        case AppGroupTypeApp:
            appGroupTypeDesc = @"App";
            break;
        case AppGroupTypeShareExtension:
            appGroupTypeDesc = @"ShareExtension";
            break;
        case AppGroupTypeNotificationExtension:
            appGroupTypeDesc = @"NotificationExtension";
            break;
        default:
            appGroupTypeDesc = @"Unknown";
            break;
    }
    DDLogWarn(@"Set AppGroupType %@ to active: %d", appGroupTypeDesc, active);

    NSUserDefaults *defaults = [self userDefaults];
    [defaults setBool:active forKey:[self keyForType:type]];
    [defaults synchronize];
}

+ (AppGroupType)getActiveType {
    NSUserDefaults *defaults = [self userDefaults];

    if ([defaults boolForKey:KEY_APP_GROUP_TYPE_NOTIFICATION_EXTENSION]) {
        return AppGroupTypeNotificationExtension;
    }
    else if ([defaults boolForKey:KEY_APP_GROUP_TYPE_SHARE_EXTENSION]) {
        return AppGroupTypeShareExtension;
    }
    else {
        return AppGroupTypeApp;
    }
}

+ (AppGroupType)getCurrentType {
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    if ([mainBundle.bundleIdentifier hasSuffix:THREEMA_NOTIFICATION_EXTENSION_SUFFIX]) {
        return AppGroupTypeNotificationExtension;
    }
    if ([mainBundle.bundleIdentifier hasSuffix:THREEMA_SHARE_EXTENSION_SUFFIX]) {
        return AppGroupTypeShareExtension;
    } else {
        return AppGroupTypeApp;
    }
}

+ (NSString *)getCurrentTypeString {
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    if ([mainBundle.bundleIdentifier hasSuffix:THREEMA_NOTIFICATION_EXTENSION_SUFFIX]) {
        return @"NotificationExtension";
    }
    if ([mainBundle.bundleIdentifier hasSuffix:THREEMA_SHARE_EXTENSION_SUFFIX]) {
        return @"AppGroupTypeShareExtension";
    } else {
        return @"AppGroupTypeApp";
    }
}

+ (BOOL)amIActive {
   return [AppGroup getCurrentType] == [AppGroup getActiveType];
}

+ (NSUserDefaults *)userDefaults {
    static NSUserDefaults *userDefaults;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName: [self groupId]];
        if ([userDefaults boolForKey:KEY_DID_MIGRATION_CHECK] == NO) {
            [self migrateDefaults: userDefaults];
        }
    });
    
    return userDefaults;
}

+ (void)migrateDefaults:(NSUserDefaults *)userDefaults {
    NSUserDefaults *oldDefaults = [NSUserDefaults standardUserDefaults];
    
    for (NSString *key in oldDefaults.dictionaryRepresentation.keyEnumerator) {
        id object = [oldDefaults objectForKey:key];
        
        [userDefaults setObject:object forKey:key];
    }
    
    [userDefaults setBool:YES forKey:KEY_DID_MIGRATION_CHECK];
    [userDefaults synchronize];
}

+ (void)resetUserDefaults {
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[AppGroup groupId]];
}

+ (NSString *)keyForType:(AppGroupType)type {
    switch (type) {
        case AppGroupTypeApp:
            return KEY_APP_GROUP_TYPE_APP;
            
        case AppGroupTypeNotificationExtension:
            return KEY_APP_GROUP_TYPE_NOTIFICATION_EXTENSION;
                        
        case AppGroupTypeShareExtension:
            return KEY_APP_GROUP_TYPE_SHARE_EXTENSION;
                        
        default:
            DDLogError(@"unknown AppGroupType %d", type);
            return KEY_APP_GROUP_TYPE_SHARE_EXTENSION;
    }
}

#pragma mark - inter app communication as seen in (https://developer.apple.com/videos/wwdc/2015/?id=224)

static void observerCallback() {
    // Call refresh of dirty objects with NO to not remove them from NSUserDefault.
    // Because of different processes of the Notification Extension (adding dirty objects)
    // and the App (refresh and remove dirty objects) it's not guaranty that en dirty object has refreshed.
    [[DatabaseManager dbManager] refreshDirtyObjects: NO];
};

+ (void)registerAppGroupSyncObserver {
    if ([AppGroup getCurrentType] != AppGroupTypeApp) {
        // Otherwise notification gets consumed by extension
        return;
    }
    
    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(nc,
                                    NULL,
                                    (CFNotificationCallback)observerCallback,
                                    appSyncNotificationKey,
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
}

+ (void)notifyAppGroupSyncNeeded {
    if ([AppGroup getCurrentType] == AppGroupTypeApp) {
        // Otherwise notification fires by app itself
        return;
    }

    CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(nc,
                                         appSyncNotificationKey,
                                         nil,
                                         nil,
                                         TRUE);
}

@end
