//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
#import "DeviceGroupKeys.h"

@implementation DeviceGroupKeys {
    NSData *dgpk;
    NSData *dgrk;
    NSData *dgdik;
    NSData *dgsddk;
    NSData *dgtsk;
    NSString *deviceGroupIDFirstByteHex;
}

@synthesize dgpk;
@synthesize dgrk;
@synthesize dgdik;
@synthesize dgsddk;
@synthesize dgtsk;
@synthesize deviceGroupIDFirstByteHex;

- (instancetype)initWithDgpk:(NSData*)dgpk dgrk:(NSData*)dgrk dgdik:(NSData*)dgdik dgsddk:(NSData*)dgsddk dgtsk:(NSData*)dgtsk deviceGroupIDFirstByteHex:(NSString *)deviceGroupIDFirstByteHex {
    if (self) {
        self->dgpk = dgpk;
        self->dgrk = dgrk;
        self->dgdik = dgdik;
        self->dgsddk = dgsddk;
        self->dgtsk = dgtsk;
        self->deviceGroupIDFirstByteHex = deviceGroupIDFirstByteHex;
    }
    return self;
}

- (NSData *)dgpk {
    return self->dgpk;
}

- (NSData *)dgrk {
    return self->dgrk;
}

- (NSData *)dgdik {
    return self->dgdik;
}

- (NSData *)dgsddk {
    return self->dgsddk;
}

- (NSData *)dgtsk {
    return self->dgtsk;
}

- (NSString *)deviceGroupIDFirstByteHex {
    return self->deviceGroupIDFirstByteHex;
}

@end
