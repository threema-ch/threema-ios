//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2024 Threema GmbH
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

#import "NaClCrypto.h"
#import "crypto_box.h"
#import "crypto_scalarmult_curve25519.h"
#import "crypto_secretbox.h"
#import "crypto_stream.h"
#import "devurandom.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation NaClCrypto {
    NSCache *sharedSecretCache;
}

#if (kNaClCryptoPubKeySize != crypto_box_PUBLICKEYBYTES)
#error Bad public key size
#endif

#if (kNaClCryptoSecKeySize != crypto_box_SECRETKEYBYTES)
#error Bad secret key size
#endif

#if (kNaClCryptoNonceSize != crypto_box_NONCEBYTES)
#error Bad nonce size
#endif

#if (kNaClBoxOverhead != (crypto_box_ZEROBYTES - crypto_box_BOXZEROBYTES))
#error Bad box overhead size
#endif

#if (kNaClCryptoSymmKeySize != crypto_secretbox_KEYBYTES)
#error Bad symmetric key size
#endif

#if (kNaClCryptoSymmNonceSize != crypto_secretbox_NONCEBYTES)
#error Bad symmetric nonce size
#endif

#if (kNaClCryptoStreamKeySize != crypto_stream_KEYBYTES)
#error Bad stream key size
#endif

#if (kNaClCryptoStreamNonceSize != crypto_stream_NONCEBYTES)
#error Bad stream nonce size
#endif

+ (NaClCrypto*)sharedCrypto {
    static NaClCrypto *instance;
	
	@synchronized (self) {
		if (!instance)
			instance = [[NaClCrypto alloc] init];
	}
	
	return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        sharedSecretCache = [[NSCache alloc] init];
        [self selfTest];
    }
    
    return self;
}

- (void)generateKeyPairPublicKey:(NSData**)publicKey secretKey:(NSData**)secretKey withSeed:(NSData*)seed {
    
    if (seed.length != kNaClCryptoSecKeySize)
        @throw([NSException exceptionWithName:@"BadSeedSizeException" reason:@"Invalid seed size" userInfo:nil]);
    
    unsigned char *pk = malloc(kNaClCryptoPubKeySize);
    if (pk == NULL)
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    
    unsigned char *sk = malloc(kNaClCryptoSecKeySize);
    if (sk == NULL) {
        free(pk);
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    }
    
    /* mix seed with random data */
    randombytes(sk, kNaClCryptoSecKeySize);
    for (int i = 0; i < kNaClCryptoSecKeySize; i++)
        sk[i] ^= ((unsigned char*)seed.bytes)[i];
    
    /* sidestepping crypto_box_keypair to provide our own secret key */
    if (crypto_scalarmult_curve25519_base(pk, sk) != 0) {
        /* shouldn't happen */
        free(pk);
        free(sk);
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    *publicKey = [NSData dataWithBytesNoCopy:pk length:kNaClCryptoPubKeySize];
    *secretKey = [NSData dataWithBytesNoCopy:sk length:kNaClCryptoSecKeySize];
}

- (void)generateKeyPairPublicKey:(NSData**)publicKey secretKey:(NSData**)secretKey {
    unsigned char *pk = malloc(kNaClCryptoPubKeySize);
    if (pk == NULL)
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    
    unsigned char *sk = malloc(kNaClCryptoSecKeySize);
    if (sk == NULL) {
        free(pk);
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    }
    
    if (crypto_box_keypair(pk, sk) != 0) {
        /* shouldn't happen */
        free(pk);
        free(sk);
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    *publicKey = [NSData dataWithBytesNoCopy:pk length:kNaClCryptoPubKeySize];
    *secretKey = [NSData dataWithBytesNoCopy:sk length:kNaClCryptoSecKeySize];
}

- (NSData*)derivePublicKeyFromSecretKey:(NSData*)secretKey {
    if (secretKey.length != kNaClCryptoSecKeySize)
        @throw([NSException exceptionWithName:@"BadSecKeySizeException" reason:@"Invalid secret key size" userInfo:nil]);
    
    unsigned char *pk = malloc(kNaClCryptoPubKeySize);
    if (pk == NULL)
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    
    /* sidestepping crypto_box_keypair to provide our own secret key */
    if (crypto_scalarmult_curve25519_base(pk, secretKey.bytes) != 0) {
        /* shouldn't happen */
        free(pk);
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    return [NSData dataWithBytesNoCopy:pk length:kNaClCryptoPubKeySize];
}

- (NSData*)encryptData:(NSData*)plaintext withPublicKey:(NSData*)publicKey signKey:(NSData*)signKey nonce:(NSData*)nonce {
    
    /* input sanity checks */
    if (publicKey.length != kNaClCryptoPubKeySize)
        @throw([NSException exceptionWithName:@"BadPubKeySizeException" reason:@"Invalid public key size" userInfo:nil]);

    if (signKey.length != kNaClCryptoSecKeySize)
        @throw([NSException exceptionWithName:@"BadSecKeySizeException" reason:@"Invalid secret key size" userInfo:nil]);

    if (nonce.length != kNaClCryptoNonceSize)
        @throw([NSException exceptionWithName:@"BadNonceSizeException" reason:@"Invalid nonce size" userInfo:nil]);
    
    if (plaintext.length == 0)
        @throw([NSException exceptionWithName:@"EmptyMessageException" reason:@"Empty message" userInfo:nil]);
    
    /* must copy plaintext since we need to zero-pad it */
    NSUInteger mlen = plaintext.length + crypto_box_ZEROBYTES;
    char *ctbuf = malloc(mlen);
    if (ctbuf == NULL) {
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    }
    memset(ctbuf, 0, crypto_box_ZEROBYTES);
    memcpy(&ctbuf[crypto_box_ZEROBYTES], plaintext.bytes, plaintext.length);
    
    NSData *sharedSecret = [self sharedSecretForPublicKey:publicKey secretKey:signKey];
    
    if (crypto_box_afternm((unsigned char *)ctbuf, (unsigned char *)ctbuf, mlen, nonce.bytes, sharedSecret.bytes) != 0) {
        /* shouldn't happen */
        free(ctbuf);
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    NSData *ciphertext = [NSData dataWithBytes:&ctbuf[crypto_box_BOXZEROBYTES] length:(mlen - crypto_box_BOXZEROBYTES)];
    
    free(ctbuf);
    
    return ciphertext;
}

- (NSData*)decryptData:(NSData*)ciphertext withSecretKey:(NSData*)secretKey signKey:(NSData*)signKey nonce:(NSData*)nonce {
    
    /* input sanity checks */
    if (secretKey.length != kNaClCryptoSecKeySize)
        @throw([NSException exceptionWithName:@"BadSecKeySizeException" reason:@"Invalid secret key size" userInfo:nil]);
    
    if (signKey.length != kNaClCryptoPubKeySize)
        @throw([NSException exceptionWithName:@"BadPubKeySizeException" reason:@"Invalid public key size" userInfo:nil]);
    
    if (nonce.length != kNaClCryptoNonceSize)
        @throw([NSException exceptionWithName:@"BadNonceSizeException" reason:@"Invalid nonce size" userInfo:nil]);
    
    if (ciphertext.length <= crypto_box_BOXZEROBYTES)
        @throw([NSException exceptionWithName:@"TruncatedMessageException" reason:@"Truncated message" userInfo:nil]);
    
    /* must copy ciphertext since we need to zero-pad it */
    NSUInteger clen = ciphertext.length + crypto_box_BOXZEROBYTES;
    char *msgbuf = malloc(clen);
    if (msgbuf == NULL)
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    memset(msgbuf, 0, crypto_box_BOXZEROBYTES);
    memcpy(&msgbuf[crypto_box_BOXZEROBYTES], ciphertext.bytes, ciphertext.length);
    
    NSData *sharedSecret = [self sharedSecretForPublicKey:signKey secretKey:secretKey];
    
    if (crypto_box_open_afternm((unsigned char *)msgbuf, (unsigned char *)msgbuf, clen, nonce.bytes, sharedSecret.bytes) != 0) {
        /* probably bad signature */
        free(msgbuf);
        return nil;
    }
    
    NSData *plaintext = [NSData dataWithBytes:&msgbuf[crypto_box_ZEROBYTES] length:(clen - crypto_box_ZEROBYTES)];
    
    free(msgbuf);
    
    return plaintext;
}

- (NSData*)streamXorData:(NSData*)data secretKey:(NSData*)secretKey nonce:(NSData*)nonce {
    
    if (secretKey.length != kNaClCryptoStreamKeySize)
        @throw([NSException exceptionWithName:@"BadStreamKeySizeException" reason:@"Invalid stream key size" userInfo:nil]);
    
    if (nonce.length != kNaClCryptoStreamNonceSize)
        @throw([NSException exceptionWithName:@"BadStreamNonceSizeException" reason:@"Invalid stream nonce size" userInfo:nil]);
    
    void *outData = malloc(data.length);
    if (outData == nil)
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    
    if (crypto_stream_xor(outData, data.bytes, data.length, nonce.bytes, secretKey.bytes) != 0) {
        free(outData);
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    return [NSData dataWithBytesNoCopy:outData length:data.length];
}

- (NSData*)symmetricEncryptData:(NSData*)plaintext withKey:(NSData*)key nonce:(NSData*)nonce {
    
    if (key.length != kNaClCryptoSymmKeySize)
        @throw([NSException exceptionWithName:@"BadSymmetricKeySizeException" reason:@"Invalid symmetric key size" userInfo:nil]);
    
    if (nonce.length != kNaClCryptoSymmNonceSize)
        @throw([NSException exceptionWithName:@"BadSymmetricNonceSizeException" reason:@"Invalid symmetric nonce size" userInfo:nil]);
    
    NSUInteger mlen = plaintext.length + crypto_secretbox_ZEROBYTES;
    char *ctbuf = malloc(mlen);
    if (ctbuf == NULL) {
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    }
    memset(ctbuf, 0, crypto_secretbox_ZEROBYTES);
    memcpy(&ctbuf[crypto_secretbox_ZEROBYTES], plaintext.bytes, plaintext.length);

    if (crypto_secretbox((unsigned char *)ctbuf, (unsigned char *)ctbuf, mlen, nonce.bytes, key.bytes) != 0) {
        /* shouldn't happen */
        free(ctbuf);
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    NSData *ciphertext = [NSData dataWithBytes:&ctbuf[crypto_secretbox_BOXZEROBYTES] length:(mlen - crypto_secretbox_BOXZEROBYTES)];
    
    free(ctbuf);
    
    return ciphertext;
}

- (NSData*)symmetricDecryptData:(NSData*)ciphertext withKey:(NSData*)key nonce:(NSData*)nonce {
    
    if (key.length != kNaClCryptoSymmKeySize)
        @throw([NSException exceptionWithName:@"BadSymmetricKeySizeException" reason:@"Invalid symmetric key size" userInfo:nil]);
    
    if (nonce.length != kNaClCryptoSymmNonceSize)
        @throw([NSException exceptionWithName:@"BadSymmetricNonceSizeException" reason:@"Invalid symmetric nonce size" userInfo:nil]);
    
    NSUInteger clen = ciphertext.length + crypto_secretbox_BOXZEROBYTES;
    char *msgbuf = malloc(clen);
    if (msgbuf == NULL)
        @throw([NSException exceptionWithName:@"MemoryAllocationException" reason:@"Cannot allocate memory" userInfo:nil]);
    memset(msgbuf, 0, crypto_secretbox_BOXZEROBYTES);
    memcpy(&msgbuf[crypto_secretbox_BOXZEROBYTES], ciphertext.bytes, ciphertext.length);
    
    if (crypto_secretbox_open((unsigned char *)msgbuf, (unsigned char *)msgbuf, clen, nonce.bytes, key.bytes) != 0) {
        /* probably bad signature */
        free(msgbuf);
        return nil;
    }
    
    NSData *plaintext = [NSData dataWithBytes:&msgbuf[crypto_secretbox_ZEROBYTES] length:(clen - crypto_secretbox_ZEROBYTES)];
    
    free(msgbuf);
    
    return plaintext;
}

- (NSData*)sharedSecretForPublicKey:(NSData*)publicKey secretKey:(NSData*)secretKey {
    /* Check cache first */
    NSMutableData *cacheKey = [NSMutableData dataWithData:publicKey];
    [cacheKey appendData:secretKey];
    NSData *sharedSecretData = [sharedSecretCache objectForKey:cacheKey];
    if (sharedSecretData != nil) {
        return sharedSecretData;
    }
    
    unsigned char sharedSecret[crypto_box_BEFORENMBYTES];
    
    if (crypto_box_beforenm(sharedSecret, publicKey.bytes, secretKey.bytes) != 0) {
        /* shouldn't happen */
        @throw([NSException exceptionWithName:@"CryptoException" reason:@"Crypto error" userInfo:nil]);
    }
    
    sharedSecretData = [NSData dataWithBytes:sharedSecret length:crypto_box_BEFORENMBYTES];
    [sharedSecretCache setObject:sharedSecretData forKey:cacheKey];
    
    return sharedSecretData;
}

- (void)selfTest {
    /* test vectors from tests/box.* in nacl distribution */
    unsigned char _alicepk[] = {
        0x85,0x20,0xf0,0x09,0x89,0x30,0xa7,0x54
        ,0x74,0x8b,0x7d,0xdc,0xb4,0x3e,0xf7,0x5a
        ,0x0d,0xbf,0x3a,0x0d,0x26,0x38,0x1a,0xf4
        ,0xeb,0xa4,0xa9,0x8e,0xaa,0x9b,0x4e,0x6a
    };
    NSData *alicepk = [NSData dataWithBytes:_alicepk length:sizeof(_alicepk)];
    
    unsigned char _alicesk[] = {
        0x77,0x07,0x6d,0x0a,0x73,0x18,0xa5,0x7d
        ,0x3c,0x16,0xc1,0x72,0x51,0xb2,0x66,0x45
        ,0xdf,0x4c,0x2f,0x87,0xeb,0xc0,0x99,0x2a
        ,0xb1,0x77,0xfb,0xa5,0x1d,0xb9,0x2c,0x2a
    };
    NSData *alicesk = [NSData dataWithBytes:_alicesk length:sizeof(_alicesk)];
    
    unsigned char _bobpk[] = {
        0xde,0x9e,0xdb,0x7d,0x7b,0x7d,0xc1,0xb4
        ,0xd3,0x5b,0x61,0xc2,0xec,0xe4,0x35,0x37
        ,0x3f,0x83,0x43,0xc8,0x5b,0x78,0x67,0x4d
        ,0xad,0xfc,0x7e,0x14,0x6f,0x88,0x2b,0x4f
    };
    NSData *bobpk = [NSData dataWithBytes:_bobpk length:sizeof(_bobpk)];
    
    unsigned char _bobsk[] = {
        0x5d,0xab,0x08,0x7e,0x62,0x4a,0x8a,0x4b
        ,0x79,0xe1,0x7f,0x8b,0x83,0x80,0x0e,0xe6
        ,0x6f,0x3b,0xb1,0x29,0x26,0x18,0xb6,0xfd
        ,0x1c,0x2f,0x8b,0x27,0xff,0x88,0xe0,0xeb
    };
    NSData *bobsk = [NSData dataWithBytes:_bobsk length:sizeof(_bobsk)];
    
    unsigned char _nonce[] = {
        0x69,0x69,0x6e,0xe9,0x55,0xb6,0x2b,0x73
        ,0xcd,0x62,0xbd,0xa8,0x75,0xfc,0x73,0xd6
        ,0x82,0x19,0xe0,0x03,0x6b,0x7a,0x0b,0x37
    };
    NSData *nonce = [NSData dataWithBytes:_nonce length:sizeof(_nonce)];
    
    unsigned char _m[] = {
        0xbe,0x07,0x5f,0xc5,0x3c,0x81,0xf2,0xd5
        ,0xcf,0x14,0x13,0x16,0xeb,0xeb,0x0c,0x7b
        ,0x52,0x28,0xc5,0x2a,0x4c,0x62,0xcb,0xd4
        ,0x4b,0x66,0x84,0x9b,0x64,0x24,0x4f,0xfc
        ,0xe5,0xec,0xba,0xaf,0x33,0xbd,0x75,0x1a
        ,0x1a,0xc7,0x28,0xd4,0x5e,0x6c,0x61,0x29
        ,0x6c,0xdc,0x3c,0x01,0x23,0x35,0x61,0xf4
        ,0x1d,0xb6,0x6c,0xce,0x31,0x4a,0xdb,0x31
        ,0x0e,0x3b,0xe8,0x25,0x0c,0x46,0xf0,0x6d
        ,0xce,0xea,0x3a,0x7f,0xa1,0x34,0x80,0x57
        ,0xe2,0xf6,0x55,0x6a,0xd6,0xb1,0x31,0x8a
        ,0x02,0x4a,0x83,0x8f,0x21,0xaf,0x1f,0xde
        ,0x04,0x89,0x77,0xeb,0x48,0xf5,0x9f,0xfd
        ,0x49,0x24,0xca,0x1c,0x60,0x90,0x2e,0x52
        ,0xf0,0xa0,0x89,0xbc,0x76,0x89,0x70,0x40
        ,0xe0,0x82,0xf9,0x37,0x76,0x38,0x48,0x64
        ,0x5e,0x07,0x05
    };
    NSData *m = [NSData dataWithBytes:_m length:sizeof(_m)];
    
    unsigned char _c_expected[] = {
        0xf3,0xff,0xc7,0x70,0x3f,0x94,0x00,0xe5
        ,0x2a,0x7d,0xfb,0x4b,0x3d,0x33,0x05,0xd9
        ,0x8e,0x99,0x3b,0x9f,0x48,0x68,0x12,0x73
        ,0xc2,0x96,0x50,0xba,0x32,0xfc,0x76,0xce
        ,0x48,0x33,0x2e,0xa7,0x16,0x4d,0x96,0xa4
        ,0x47,0x6f,0xb8,0xc5,0x31,0xa1,0x18,0x6a
        ,0xc0,0xdf,0xc1,0x7c,0x98,0xdc,0xe8,0x7b
        ,0x4d,0xa7,0xf0,0x11,0xec,0x48,0xc9,0x72
        ,0x71,0xd2,0xc2,0x0f,0x9b,0x92,0x8f,0xe2
        ,0x27,0x0d,0x6f,0xb8,0x63,0xd5,0x17,0x38
        ,0xb4,0x8e,0xee,0xe3,0x14,0xa7,0xcc,0x8a
        ,0xb9,0x32,0x16,0x45,0x48,0xe5,0x26,0xae
        ,0x90,0x22,0x43,0x68,0x51,0x7a,0xcf,0xea
        ,0xbd,0x6b,0xb3,0x73,0x2b,0xc0,0xe9,0xda
        ,0x99,0x83,0x2b,0x61,0xca,0x01,0xb6,0xde
        ,0x56,0x24,0x4a,0x9e,0x88,0xd5,0xf9,0xb3
        ,0x79,0x73,0xf6,0x22,0xa4,0x3d,0x14,0xa6
        ,0x59,0x9b,0x1f,0x65,0x4c,0xb4,0x5a,0x74
        ,0xe3,0x55,0xa5
    };
    NSData *c_expected = [NSData dataWithBytes:_c_expected length:sizeof(_c_expected)];
    
    /* encrypt data and compare with expected result */
    NSData *c = [self encryptData:m withPublicKey:bobpk signKey:alicesk nonce:nonce];
    if (![c_expected isEqualToData:c]) {
        @throw([NSException exceptionWithName:@"CryptoSelfTestFailedException" reason:@"Crypto self-test failed" userInfo:nil]);
    }
    
    /* decrypt data and compare with plaintext */
    NSData *p_d = [self decryptData:c withSecretKey:bobsk signKey:alicepk nonce:nonce];
    if (![p_d isEqualToData:m]) {
        @throw([NSException exceptionWithName:@"CryptoSelfTestFailedException" reason:@"Crypto self-test failed" userInfo:nil]);
    }
    
    DDLogInfo(@"Crypto self-test passed");
}

- (void)longTest {
    int i;
    
    for (i = 0; i < 1000; i++) {
        int msglen = i + 1;
        
        NSData *pk1, *sk1, *pk2, *sk2;
        [self generateKeyPairPublicKey:&pk1 secretKey:&sk1];
        [self generateKeyPairPublicKey:&pk2 secretKey:&sk2];
        
        NSData *msg = [self randomBytes:msglen];
        NSData *nonce = [self randomBytes:kNaClCryptoNonceSize];
        
        NSData *c = [self encryptData:msg withPublicKey:pk2 signKey:sk1 nonce:nonce];
        NSData *newmsg = [self decryptData:c withSecretKey:sk2 signKey:pk1 nonce:nonce];
        
        if (![newmsg isEqualToData:msg]) {
            @throw([NSException exceptionWithName:@"CryptoSelfTestFailedException" reason:@"Crypto self-test failed" userInfo:nil]);
        }
    }
}

- (NSData*)randomBytes:(int)len {
    unsigned char *random = malloc(len);
    if (random == NULL) {
        @throw([NSException exceptionWithName:@"AllocMemoryForRandomBytesFailed" reason:@"Cannot allocate memory for random bytes" userInfo:nil]);
    }
    randombytes(random, len);
    return [NSData dataWithBytesNoCopy:random length:len];
}

- (NSData*)zeroBytes:(int)len {
    unsigned char *zero = malloc(len);
    if (zero == NULL) {
        @throw([NSException exceptionWithName:@"AllocMemoryForZeroBytesFailed" reason:@"Cannot allocate memory for zero bytes" userInfo:nil]);
    }
    memset(zero, 0, len);
    return [NSData dataWithBytesNoCopy:zero length:len];
}

- (double)benchmark {
    /* run 1000 encryption operations on a 1024 byte message
       and return the number of encryption operations per second */
    
    DDLogInfo(@"Generating key...");
    int i;
    NSData *pk, *sk;
    [self generateKeyPairPublicKey:&pk secretKey:&sk];
    
    DDLogInfo(@"Preparing message...");
    unsigned char _msg[1024];
    for (i = 0; i < 1024; i++)
        _msg[i] = (i % 256);
    NSData *msg = [NSData dataWithBytes:_msg length:1024];
    
    unsigned char _nonce[kNaClCryptoNonceSize];
    for (i = 0; i < kNaClCryptoNonceSize; i++)
        _nonce[i] = (i % 256);
    NSData *nonce = [NSData dataWithBytes:_nonce length:kNaClCryptoNonceSize];

    DDLogInfo(@"Benchmarking...");
    NSDate *start = [NSDate date];
    for (i = 0; i < 1000; i++) {
        [self encryptData:msg withPublicKey:pk signKey:sk nonce:nonce];
    }
    DDLogInfo(@"Benchmark done.");
    return (1000 / ([start timeIntervalSinceNow] * -1.0));
}

@end
