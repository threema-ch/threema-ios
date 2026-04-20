#import "NonceHasher.h"
#import "CryptoUtils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

@implementation NonceHasher

+ (NSData *)hashedNonce:(NSData *)nonce myIdentity:(nullable NSString *)myIdentity {
    /* Hash nonce with HMAC-SHA256 using the identity as the key if available.
       This serves to make it impossible to correlate the nonce DBs of users to determine whether they have been communicating. */
    NSData *identity = [myIdentity dataUsingEncoding:NSASCIIStringEncoding];
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
