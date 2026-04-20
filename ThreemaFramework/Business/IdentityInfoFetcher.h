#import <Foundation/Foundation.h>

@interface IdentityInfoFetcher : NSObject

+ (IdentityInfoFetcher*)sharedIdentityInfoFetcher;

- (void)prefetchIdentityInfo:(NSSet*)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchIdentityInfoFor:(NSString*)identity onCompletion:(void(^)(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchWorkIdentitiesInfo:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError;

@end
