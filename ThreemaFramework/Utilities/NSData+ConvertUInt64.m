//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

@implementation NSData (ConvertUInt64)

- (UInt64)convertUInt64 {
    const uint8_t *bytes = self.bytes;
    
    UInt64 result = (UInt64)bytes[0] << 0
     | (UInt64)bytes[1] << 8
     | (UInt64)bytes[2] << 16
     | (UInt64)bytes[3] << 24
     | (UInt64)bytes[4] << 32
     | (UInt64)bytes[5] << 40
     | (UInt64)bytes[6] << 48
     | (UInt64)bytes[7] << 56;
    
    return result;
}

+ (NSData *)convertBytes:(UInt64)value {
    UInt64 result = 0;
    UInt8 *bytes = (UInt8 *) &result;
    
    bytes[0] = value >> 0 & 0xff;
    bytes[1] = value >> 8 & 0xff;
    bytes[2] = value >> 16 & 0xff;
    bytes[3] = value >> 24 & 0xff;
    bytes[4] = value >> 32 & 0xff;
    bytes[5] = value >> 40 & 0xff;
    bytes[6] = value >> 48 & 0xff;
    bytes[7] = value >> 56 & 0xff;

    return [[NSData alloc] initWithBytes:bytes length:8];
}

@end
