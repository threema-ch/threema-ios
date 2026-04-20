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
- (nullable NSData*)safeSymmetricDecryptData:(NSData*)ciphertext withKey:(NSData*)key nonce:(NSData*)nonce;
- (NSData*)symmetricDecryptData:(NSData*)ciphertext withKey:(NSData*)key nonce:(NSData*)nonce;

- (NSData*)streamXorData:(NSData*)data secretKey:(NSData*)secretKey nonce:(NSData*)nonce;

- (NSData*)sharedSecretForPublicKey:(NSData*)publicKey secretKey:(NSData*)secretKey;

- (NSData*)randomBytes:(int)len;
- (NSData*)zeroBytes:(int)len;

- (void)selfTest;
- (void)longTest;
- (double)benchmark;


@end
