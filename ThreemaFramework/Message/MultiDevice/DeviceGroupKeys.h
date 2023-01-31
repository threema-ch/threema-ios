//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

#ifndef DeviceGroupKeys_h
#define DeviceGroupKeys_h

@interface DeviceGroupKeys : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDgpk:(NSData*)dgpk dgrk:(NSData*)dgrk dgdik:(NSData*)dgdik dgsddk:(NSData*)dgsddk dgtsk:(NSData*)dgtsk deviceGroupIDFirstByteHex:(NSString *)deviceGroupIDFirstByteHex;

@property (nonatomic, readonly) NSData *dgpk;
@property (nonatomic, readonly) NSData *dgrk;
@property (nonatomic, readonly) NSData *dgdik;
@property (nonatomic, readonly) NSData *dgsddk;
@property (nonatomic, readonly) NSData *dgtsk;
@property (nonatomic, readonly) NSString *deviceGroupIDFirstByteHex;

@end

#endif /* DeviceGroupKeys_h */
