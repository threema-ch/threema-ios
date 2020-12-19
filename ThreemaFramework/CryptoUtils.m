//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "CryptoUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import "NSString+Hex.h"

@implementation CryptoUtils

+ (NSString*)fingerprintForPublicKey:(NSData*)publicKey {
    /* The key fingerprint is a truncated SHA256 hash */
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(publicKey.bytes, (CC_LONG)publicKey.length, digest);
    
    NSData *truncDigest = [NSData dataWithBytes:digest length:16];
    return [NSString stringWithHexData:truncDigest];
}

+ (NSData*)hmacSha256ForData:(NSData*)data key:(NSData*)key {
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, data.bytes, data.length, hmac);
    return [NSData dataWithBytes:hmac length:sizeof(hmac)];
}

@end
