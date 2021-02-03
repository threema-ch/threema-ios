//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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


@class MyIdentityStore;
@class LicenseStore;

enum IdentityState {
    IdentityStateActive = 0,
    IdentityStateInactive = 1,
    IdentityStateInvalid = 2
};

@interface ServerAPIConnector : NSObject

- (void)createIdentityWithStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(MyIdentityStore *store))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchIdentityInfo:(NSString*)identity onCompletion:(void(^)(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask))onCompletion onError:(void(^)(NSError *error))onError;
    
- (void)fetchBulkIdentityInfo:(NSArray*)identities onCompletion:(void(^)(NSArray *identities, NSArray *publicKeys, NSArray *featureMasks, NSArray *states, NSArray *types))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchPrivateIdentityInfo:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSString *serverGroup, NSString *email, NSString *mobileNo))onCompletion onError:(void(^)(NSError *error))onError;

- (void)updateMyIdentityStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError* error))onError;

- (void)linkEmailWithStore:(MyIdentityStore*)identityStore email:(NSString*)email onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError;
- (void)checkLinkEmailStatus:(MyIdentityStore*)identityStore email:(NSString*)email onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError;

- (void)linkMobileNoWithStore:(MyIdentityStore*)identityStore mobileNo:(NSString*)mobileNo onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError;
- (void)linkMobileNoWithStore:(MyIdentityStore*)identityStore code:(NSString*)code onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError;

- (void)linkMobileNoRequestCallWithStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (void)matchIdentitiesWithEmailHashes:(NSArray*)emailHashes mobileNoHashes:(NSArray*)mobileNoHashes includeInactive:(BOOL)includeInactive onCompletion:(void(^)(NSArray *identities, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError;

- (void)setFeatureMask:(NSNumber *)featureMask forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;
- (void)getFeatureMasksForIdentities:(NSArray*)identities onCompletion:(void(^)(NSArray* featureMasks))onCompletion onError:(void(^)(NSError *error))onError;

- (void)checkRevocationPasswordForStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(BOOL revocationPasswordSet, NSDate *lastChanged))onCompletion onError:(void(^)(NSError *error))onError;
- (void)setRevocationPassword:(NSString*)revocationPassword forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;
- (void)checkStatusOfIdentities:(NSArray*)identities onCompletion:(void(^)(NSArray* states, NSArray *types, NSArray *featureMasks, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError;
- (void)revokeIdForStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (void)validateLicenseUsername:(NSString*)licenseUsername password:(NSString*)licensePassword appId:(NSString*)appId version:(NSString*)version deviceId:(NSString*)deviceId onCompletion:(void(^)(BOOL success, NSDictionary *info))onCompletion onError:(void(^)(NSError *error))onError;
- (void)updateWorkInfoForStore:(MyIdentityStore*)identityStore licenseUsername:(NSString*)licenseUsername password:(NSString*)licensePassword onCompletion:(void(^)(BOOL sent))onCompletion onError:(void(^)(NSError *error))onError;

- (void)searchInDirectory:(NSString *)searchString categories:(NSArray *)categories page:(int)page forLicenseStore:(LicenseStore *)licenseStore forMyIdentityStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSArray *contacts, NSDictionary *paging))onCompletion onError:(void(^)(NSError *error))onError;

- (void)obtainTurnServersWithStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError;

@end
