//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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
#import "NaClCrypto.h"
#import "PushPayloadDecryptor.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation PushPayloadDecryptor

+ (NSDictionary*)decryptPushPayload:(NSDictionary*)encryptedPayload {
    NSString *box_base64 = [encryptedPayload objectForKey:@"box"];
    NSString *nonce_base64 = [encryptedPayload objectForKey:@"nonce"];
    
    if (!box_base64 || !nonce_base64)
        return encryptedPayload;    // not really encrypted
    
    NSData *box = [[NSData alloc] initWithBase64EncodedString:box_base64 options:0];
    NSData *nonce = [[NSData alloc] initWithBase64EncodedString:nonce_base64 options:0];
    
    NSData *payloadJson = [[NaClCrypto sharedCrypto] symmetricDecryptData:box withKey:[self pushEncryptionKey] nonce:nonce];
    if (payloadJson == nil) {
        DDLogError(@"Cannot decrypt push payload: %@", encryptedPayload);
        return encryptedPayload;
    }
    
    NSError *error = nil;
    NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:payloadJson options:0 error:&error];
    if (payload == nil) {
        DDLogError(@"Error parsing decrypted JSON payload: %@, %@", error, [error userInfo]);
        return encryptedPayload;
    }
    
    return payload;
}

+ (NSData*)pushEncryptionKey {
    // Generate new push encryption key if necessary
    NSData *pushEncryptionKey = [[AppGroup userDefaults] objectForKey:kPushNotificationEncryptionKey];
    if (pushEncryptionKey == nil) {
        pushEncryptionKey = [[NaClCrypto sharedCrypto] randomBytes:kNaClCryptoSymmKeySize];
        [[AppGroup userDefaults] setObject:pushEncryptionKey forKey:kPushNotificationEncryptionKey];
    }
    return pushEncryptionKey;
}

@end
