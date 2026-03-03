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
#import <ThreemaFramework/BoxFileMessage.h>
#import <ThreemaFramework/GroupFileMessage.h>

@interface FileMessageEncoder : NSObject

/**
 Encode or get abstract file message of file entity.

 @param fileMessageEntityObject Object of type `FileMessageEntity`
 @return `BoxFileMessage`
 */
+ (BoxFileMessage *)encodeFileMessageEntity:(nonnull NSObject *)fileMessageEntityObject NS_SWIFT_NAME(encodeFileMessageEntity(_:));

/**
 Encode or get abstract group file message of file entity.

 @param fileMessageEntityObject Object of type `FileMessageEntity`
 @return `GroupFileMessage`
 */
+ (GroupFileMessage *)encodeGroupFileMessageEntity:(nonnull NSObject *)fileMessageEntityObject;

/**
 @param fileMessageEntityObject Object of type `FileMessageEntity`
 @return `NSString`
 */
+ (NSString *)jsonStringForFileMessageEntity:(nonnull NSObject *)fileMessageEntityObject NS_SWIFT_NAME(jsonString(for:));

@end
