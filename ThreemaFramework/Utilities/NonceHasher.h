#import <Foundation/Foundation.h>
#import "MyIdentityStore.h"

NS_ASSUME_NONNULL_BEGIN

@interface NonceHasher : NSObject

/// Hash nonce
/// - Parameters:
///   - nonce: Nonce to hash
///   - myIdentity: Information about our identity
/// - Returns: Hashed nonce if `myIdentityStore` has an `identity`, `nil` otherwise
+ (nullable NSData *)hashedNonce:(NSData *)nonce myIdentity:(nullable NSString *)myIdentity;
@end

NS_ASSUME_NONNULL_END
