//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

@interface NSData (ConvertUInt64)

/**
 Converts NSData/bytes to UInt64 little endian.
 */
- (UInt64)convertUInt64
    __deprecated_msg("Only use from Objective-C. Use `littleEndian()` or `paddedLittleEndian()` instead");

/**
 Converts UInt64 to NSData/bytes little endian.
*/
+ (NSData *)convertBytes:(UInt64)value
    __deprecated_msg("Only use from Objective-C. Use `littleEndianData` instead");

@end
