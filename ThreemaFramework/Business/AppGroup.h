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

#import <Foundation/Foundation.h>

typedef enum : int {
    AppGroupTypeApp,
    AppGroupTypeShareExtension,
    AppGroupTypeNotificationExtension
} AppGroupType;

@interface AppGroup : NSObject

+ (void)setAppId:(NSString *)newAppId NS_SWIFT_NAME(setAppID(_:));

+ (void)setGroupId:(NSString *)newGroupId NS_SWIFT_NAME(setGroupID(_:));

+ (NSString *)groupId NS_SWIFT_NAME(groupID());

+ (void)setActive:(BOOL)active forType:(AppGroupType)type;

+ (AppGroupType)getActiveType;

+ (AppGroupType)getCurrentType;

+ (NSString *)getCurrentTypeString;

+ (BOOL)amIActive;

+ (NSUserDefaults *)userDefaults;

+ (void)resetUserDefaults;

+ (void)notifyAppGroupSyncNeeded;

+ (nonnull NSString *)nameForType:(AppGroupType)type;

@end
