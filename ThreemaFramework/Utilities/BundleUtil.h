//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

NS_ASSUME_NONNULL_BEGIN

@interface BundleUtil : NSObject

+ (nullable NSBundle *)frameworkBundle;

/// In an extension this returns `nil` if the main app is fully terminated, but might return the main bundle if the app is just backgrounded
+ (nullable NSBundle *)mainBundle;

+ (nullable NSString *)threemaAppGroupIdentifier;

+ (nullable NSString *)threemaAppIdentifier;

+ (nullable NSString *)threemaVersionSuffix;

+ (BOOL)threemaWorkVersion;

+ (nullable id)objectForInfoDictionaryKey:(NSString *)key;

+ (nullable NSString *)pathForResource:(nullable NSString *)resource ofType:(nullable NSString *)type;

+ (nullable NSURL *)URLForResource:(nullable NSString *)resourceName withExtension:(nullable NSString *)extension;

+ (nullable UIImage *)imageNamed:(NSString *)imageName;

+ (NSString *)localizedStringForKey:(NSString *)key  __deprecated_msg("Only use in Obj-C. In Swift, use the macro #localize(key) instead.");

+ (nullable UIView *)loadXibNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
