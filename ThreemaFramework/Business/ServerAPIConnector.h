#import <Foundation/Foundation.h>

@protocol MyIdentityStoreProtocol;
@protocol LicenseStoreProtocol;

enum IdentityState {
    IdentityStateActive = 0,
    IdentityStateInactive = 1,
    IdentityStateInvalid = 2
};

@interface ServerAPIConnector : NSObject

- (void)createIdentityWithStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(id<MyIdentityStoreProtocol> store))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(createIdentity(with:onCompletion:onError:));

- (void)fetchIdentityInfo:(NSString*)identity onCompletion:(void(^)(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask))onCompletion onError:(void(^)(NSError *error))onError;
    
- (void)fetchBulkIdentityInfo:(NSArray*)identities onCompletion:(void(^)(NSArray *identities, NSArray *publicKeys, NSArray *featureMasks, NSArray *states, NSArray *types))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchPrivateIdentityInfo:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(NSString *serverGroup, NSString *email, NSString *mobileNo))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(fetchPrivateIdentityInfo(_:onCompletion:onError:));

- (void)fetchWorkIdentitiesInfo:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError;

- (void)updateMyIdentityStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError* error))onError
    NS_SWIFT_NAME(update(_:onCompletion:onError:));

- (void)linkEmailWithStore:(id<MyIdentityStoreProtocol>)identityStore email:(NSString*)email onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(linkEmail(with:email:onCompletion:onError:));

- (void)checkLinkEmailStatus:(id<MyIdentityStoreProtocol>)identityStore email:(NSString*)email onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(checkLinkEmailStatus(_:email:onCompletion:onError:));

- (void)linkMobileNoWithStore:(id<MyIdentityStoreProtocol>)identityStore mobileNo:(NSString*)mobileNo onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(linkMobileNo(with:mobileNo:onCompletion:onError:));

- (void)linkMobileNoWithStore:(id<MyIdentityStoreProtocol>)identityStore code:(NSString*)code onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(linkMobileNo(with:code:onCompletion:onError:));

- (void)linkMobileNoRequestCallWithStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(linkMobileNoRequestCall(with:onCompletion:onError:));

- (void)matchIdentitiesWithEmailHashes:(NSArray*)emailHashes mobileNoHashes:(NSArray*)mobileNoHashes includeInactive:(BOOL)includeInactive onCompletion:(void(^)(NSArray *identities, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError;

- (void)setFeatureMask:(NSNumber *)featureMask forStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(setFeatureMask(_:for:onCompletion:onError:));

- (void)getFeatureMasksForIdentities:(NSArray*)identities onCompletion:(void(^)(NSArray* featureMasks))onCompletion onError:(void(^)(NSError *error))onError;

- (void)checkRevocationPasswordForStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(BOOL revocationPasswordSet, NSDate *lastChanged))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(checkRevocationPassword(for:onCompletion:onError:));

- (void)setRevocationPassword:(NSString*)revocationPassword forStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(setRevocationPassword(_:for:onCompletion:onError:));

- (void)revokeID:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(revokeID(_:onCompletion:onError:));

- (void)checkStatusOfIdentities:(NSArray*)identities onCompletion:(void(^)(NSArray* states, NSArray *types, NSArray *featureMasks, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError;

- (void)revokeIdForStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(revokeId(with:onCompletion:onError:));

- (void)validateLicenseUsername:(NSString*)licenseUsername password:(NSString*)licensePassword appId:(NSString*)appId version:(NSString*)version deviceId:(NSString*)deviceId onCompletion:(void(^)(BOOL success, NSDictionary *info))onCompletion onError:(void(^)(NSError *error))onError;

- (void)updateWorkInfoForStore:(id<MyIdentityStoreProtocol>)identityStore licenseUsername:(NSString*)licenseUsername password:(NSString*)licensePassword force:(BOOL)force onCompletion:(void(^)(BOOL sent))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(updateWorkInfo(with:licenseUsername:password:force:onCompletion:onError:));

- (void)searchInDirectory:(NSString *)searchString categories:(NSArray *)categories page:(int)page forLicenseStore:(id<LicenseStoreProtocol> )licenseStore forMyIdentityStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(NSArray *contacts, NSDictionary *paging))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(search(inDirectory:categories:page:for:for:onCompletion:onError:));

- (void)obtainTurnServersWithStore:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(obtainTurnServers(with:onCompletion:onError:));

- (void)obtainSFUCredentials:(id<MyIdentityStoreProtocol>)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(obtainSFUCredentials(_:onCompletion:onError:));

- (void)obtainAuthTokenOnCompletion:(void(^)(NSString *authToken))onCompletion onError:(void(^)(NSError *error))onError;

@end
