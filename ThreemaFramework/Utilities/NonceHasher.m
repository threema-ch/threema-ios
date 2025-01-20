//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

#import "NonceHasher.h"
#import "CryptoUtils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

@implementation NonceHasher

+ (NSData *)hashedNonce:(NSData *)nonce myIdentityStore:(id<MyIdentityStoreProtocol>)myIdentityStore {
    /* Hash nonce with HMAC-SHA256 using the identity as the key if available.
       This serves to make it impossible to correlate the nonce DBs of users to determine whether they have been communicating. */
    NSData *identity = [[myIdentityStore identity] dataUsingEncoding:NSASCIIStringEncoding];
    if (identity == nil) {
        // This should never be called
        DDLogError(@"Nonces should only be processed if my identity exists");
        NSAssert(false, @"Nonces should only be processed if my identity exists");
        return nil;
    } else {
        return [CryptoUtils hmacSha256ForData:nonce key:identity];
    }
}

@end
