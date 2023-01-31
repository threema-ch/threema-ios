//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#define kNaClCryptoPubKeySize 32
#define kNaClCryptoSecKeySize 32
#define kNaClCryptoNonceSize 24
#define kNaClBoxOverhead 16
#define kNaClCryptoSymmKeySize 32
#define kNaClCryptoSymmNonceSize 24
#define kNaClCryptoStreamKeySize 32
#define kNaClCryptoStreamNonceSize 24

@interface NaClCrypto : NSObject

+ (NaClCrypto*)sharedCrypto;

- (void)generateKeyPairPublicKey:(NSData**)publicKey secretKey:(NSData**)secretKey withSeed:(NSData*)seed;
- (void)generateKeyPairPublicKey:(NSData**)publicKey secretKey:(NSData**)secretKey;
- (NSData*)derivePublicKeyFromSecretKey:(NSData*)secretKey;
- (NSData*)encryptData:(NSData*)plaintext withPublicKey:(NSData*)publicKey signKey:(NSData*)signKey nonce:(NSData*)nonce;
- (NSData*)decryptData:(NSData*)ciphertext withSecretKey:(NSData*)secretKey signKey:(NSData*)signKey nonce:(NSData*)nonce;

- (NSData*)symmetricEncryptData:(NSData*)plaintext withKey:(NSData*)key nonce:(NSData*)nonce;
- (NSData*)symmetricDecryptData:(NSData*)ciphertext withKey:(NSData*)key nonce:(NSData*)nonce;

- (NSData*)streamXorData:(NSData*)data secretKey:(NSData*)secretKey nonce:(NSData*)nonce;

- (NSData*)sharedSecretForPublicKey:(NSData*)publicKey secretKey:(NSData*)secretKey;

- (NSData*)randomBytes:(int)len;
- (NSData*)zeroBytes:(int)len;

- (void)selfTest;
- (void)longTest;
- (double)benchmark;


@end
