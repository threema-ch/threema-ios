#import "CryptoUtils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import "NSString+Hex.h"

@implementation CryptoUtils

+ (NSData*)hmacSha256ForData:(NSData*)data key:(NSData*)key {
    unsigned char hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, key.length, data.bytes, data.length, hmac);
    return [NSData dataWithBytes:hmac length:sizeof(hmac)];
}

@end
