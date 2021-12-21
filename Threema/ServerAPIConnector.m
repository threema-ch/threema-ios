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

#include <CommonCrypto/CommonDigest.h>

#import "ServerAPIConnector.h"
#import "ServerAPIRequest.h"
#import "NSString+Hex.h"
#import "NaClCrypto.h"
#import "Utils.h"
#import "ThreemaError.h"
#import "FeatureMask.h"
#import "UserSettings.h"

#import "MyIdentityStore.h"
#import "LicenseStore.h"
#import "AppGroup.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif


@implementation ServerAPIConnector

- (void)createIdentityWithStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(MyIdentityStore *store))onCompletion onError:(void(^)(NSError *error))onError {
    
    static NSString *apiPath = @"identity/create";
    
    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:@{
                              @"publicKey": [identityStore.publicKey base64EncodedStringWithOptions:0],
                              @"version": [Utils getClientVersion],
                              @"deviceId": [[[UIDevice currentDevice] identifierForVendor] UUIDString]
                              }];
    
    // add App Store receipt if available (but not for Work)
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    if (receiptUrl && [[NSFileManager defaultManager] fileExistsAtPath:receiptUrl.path] && ![LicenseStore requiresLicenseKey]) {
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
        if (receiptData) {
            request[@"appStoreReceipt"] = [receiptData base64EncodedStringWithOptions:0];
        }
    }
    
    // add Work license if available
    NSString *licenseUsername = [[LicenseStore sharedLicenseStore] licenseUsername];
    NSString *licensePassword = [[LicenseStore sharedLicenseStore] licensePassword];
    if (licenseUsername && licensePassword) {
        request[@"licenseUsername"] = licenseUsername;
        request[@"licensePassword"] = licensePassword;
    }
    
    [self sendSignedRequestPhase1:request toApiPath:apiPath onCompletion:^(NSDictionary *response) {
        NSData *nonce = [@"createIdentity response." dataUsingEncoding:NSASCIIStringEncoding];
        [self sendSignedRequestPhase2:request toApiPath:apiPath phase1Response:response withNonce:nonce forStore:identityStore onCompletion:^(NSDictionary *response) {
            identityStore.identity = response[@"identity"];
            identityStore.serverGroup = response[@"serverGroup"];
            [identityStore storeInKeychain];
            [FeatureMask updateFeatureMask];
            
            onCompletion(identityStore);
        } onError:onError];
    } onError:onError];
}

- (void)fetchIdentityInfo:(NSString*)identity onCompletion:(void(^)(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask))onCompletion onError:(void(^)(NSError *error))onError {
    
    NSString *apiPath = [NSString stringWithFormat:@"identity/%@", identity];
    
    [ServerAPIRequest loadJSONFromAPIPath:apiPath withCachePolicy:NSURLRequestReloadIgnoringLocalCacheData onCompletion:^(id jsonObject) {
        NSData *publicKey = [[NSData alloc] initWithBase64EncodedString:jsonObject[@"publicKey"] options:0];
        NSNumber *state = [NSNumber numberWithInt:[jsonObject[@"state"] intValue]];
        NSNumber *type = [NSNumber numberWithInt:[jsonObject[@"type"] intValue]];
        NSNumber *featureMask = [NSNumber numberWithInt:[jsonObject[@"featureMask"] intValue]];
        
        onCompletion(publicKey, state, type, featureMask);
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (void)fetchBulkIdentityInfo:(NSArray*)identities onCompletion:(void(^)(NSArray *identities, NSArray *publicKeys, NSArray *featureMasks, NSArray *states, NSArray *types))onCompletion onError:(void(^)(NSError *error))onError {
    
    NSDictionary *req = [NSDictionary dictionaryWithObjectsAndKeys:identities, @"identities", nil];
    
    [ServerAPIRequest postJSONToAPIPath:@"identity/fetch_bulk" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Bulk fetch of ID status success: %@", jsonObject);

        NSMutableArray *responseIdentities = [[NSMutableArray alloc] init];
        NSMutableArray *responsePublicKeys = [[NSMutableArray alloc] init];
        NSMutableArray *responseFeatureMasks = [[NSMutableArray alloc] init];
        NSMutableArray *responseStates = [[NSMutableArray alloc] init];
        NSMutableArray *responseTypes = [[NSMutableArray alloc] init];

        int index = 0;
        NSUInteger count = [jsonObject[@"identities"] count];
        while(index < count) {
            id item = jsonObject[@"identities"][index];
            
            [responseIdentities addObject:item[@"identity"]];
            [responsePublicKeys addObject:[[NSData alloc] initWithBase64EncodedString:item[@"publicKey"] options:0]];
            [responseFeatureMasks addObject:item[@"featureMask"]];
            [responseStates addObject:item[@"state"]];
            [responseTypes addObject:item[@"type"]];

            index++;
        }
        
        onCompletion(responseIdentities, responsePublicKeys, responseFeatureMasks, responseStates, responseTypes);
    } onError:^(NSError *error) {
        DDLogError(@"Bulk fetch of ID status failed: %@", error);
        onError(error);
    }];
}

- (void)fetchPrivateIdentityInfo:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSString *serverGroup, NSString *email, NSString *mobileNo))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    NSDictionary *request = @{
        @"identity": identityStore.identity
    };

    [self sendSignedRequest:request toApiPath:@"identity/fetch_priv" forStore:identityStore onCompletion:^(id jsonObject) {
        onCompletion(jsonObject[@"serverGroup"], jsonObject[@"email"], jsonObject[@"mobileNo"]);
    } onError:onError];
}

- (void)fetchWorkIdentitiesInfo:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identities == nil) {
        onError([ThreemaError threemaError:@"Identity is nil"]);
        return;
    }
        
    NSDictionary *request = @{
        @"username": [[LicenseStore sharedLicenseStore] licenseUsername],
        @"password": [[LicenseStore sharedLicenseStore] licensePassword],
        @"contacts": identities
    };

    [ServerAPIRequest postJSONToWorkAPIPath:@"identities" data:request onCompletion:^(id jsonObject) {
        onCompletion(jsonObject[@"contacts"]);
    } onError:^(NSError *error) {
        onError(error);
    }];
}


- (void)updateMyIdentityStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError* error))onError {
    [self fetchPrivateIdentityInfo:identityStore onCompletion:^(NSString *serverGroup, NSString *email, NSString *mobileNo) {
        DDLogVerbose(@"Got identity info: serverGroup %@, email %@, mobileNo %@", serverGroup, email, mobileNo);
        
        identityStore.serverGroup = serverGroup;
        
        identityStore.linkedEmail = email;
        if (identityStore.linkedEmail != nil) {
            identityStore.linkEmailPending = NO;
        }
        
        identityStore.linkedMobileNo = mobileNo;
        if (identityStore.linkedMobileNo != nil) {
            identityStore.linkMobileNoPending = NO;
        }
        
        onCompletion();
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (void)linkEmailWithStore:(MyIdentityStore*)identityStore email:(NSString*)email onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError {
    
    static NSString *apiPath = @"identity/link_email";
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    if (email == nil) {
        onError([ThreemaError threemaError:@"link email with store: email missing"]);
        return;
    }
    
    NSDictionary *request = @{
                              @"identity": identityStore.identity,
                              @"email": email,
                              @"lang": [self preferredLanguage]
                              };
    
    [self sendSignedRequestPhase1:request toApiPath:apiPath onCompletion:^(NSDictionary *response) {
        if ([response[@"linked"] boolValue]) {
            /* Already linked - update address with user provided value, as it is possible that we currently
               only have ***@*** from the server after an ID restore */
            identityStore.linkEmailPending = NO;
            identityStore.linkedEmail = email;
            onCompletion(YES);
            return;
        }
        
        [self sendSignedRequestPhase2:request toApiPath:apiPath phase1Response:response forStore:identityStore onCompletion:^(NSDictionary *response) {
            if (email.length == 0) {
                /* unlink */
                identityStore.linkEmailPending = NO;
                identityStore.linkedEmail = nil;
            } else {
                identityStore.linkEmailPending = YES;
                identityStore.linkedEmail = email;
            }
            onCompletion(NO);
        } onError:onError];
    } onError:onError];
}

- (NSString *)preferredLanguage {
    NSString *lang = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    if (lang) {
        return lang;
    } else {
        return @"en_US";
    }
}

- (void)checkLinkEmailStatus:(MyIdentityStore*)identityStore email:(NSString*)email onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError {

    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    if (email == nil) {
        onError([ThreemaError threemaError:@"check link email status: email missing"]);
        return;
    }
    
    NSDictionary *request = @{
                              @"identity": identityStore.identity,
                              @"email": email
                              };
    
    [self sendSignedRequestPhase1:request toApiPath:@"identity/link_email" onCompletion:^(NSDictionary *response) {
        BOOL linked = [response[@"linked"] boolValue];
        if (linked)
            [MyIdentityStore sharedMyIdentityStore].linkEmailPending = NO;
        
        onCompletion(linked);
    } onError:onError];
}

- (void)linkMobileNoWithStore:(MyIdentityStore*)identityStore mobileNo:(NSString*)mobileNo onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    if (mobileNo == nil) {
        onError([ThreemaError threemaError:@"link mobile: mobileNo missing"]);
        return;
    }
    
    static NSString *apiPath = @"identity/link_mobileno";
    
    NSString *urlScheme = @"threema";
    if ([LicenseStore requiresLicenseKey]) {
        urlScheme = @"threemawork";
    }
    
    NSDictionary *request = @{
                              @"identity": identityStore.identity,
                              @"mobileNo": mobileNo,
                              @"lang": [self preferredLanguage],
                              @"urlScheme": urlScheme
                              };
    
    [self sendSignedRequestPhase1:request toApiPath:apiPath onCompletion:^(NSDictionary *response) {
        if ([response[@"linked"] boolValue]) {
            /* already linked */
            identityStore.linkMobileNoPending = NO;
            identityStore.linkedMobileNo = mobileNo;
            identityStore.linkMobileNoVerificationId = nil;
            
            onCompletion(YES);
            return;
        }
        
        [self sendSignedRequestPhase2:request toApiPath:apiPath phase1Response:response forStore:identityStore onCompletion:^(NSDictionary *response) {
            if (mobileNo.length == 0) {
                /* unlink */
                identityStore.linkMobileNoPending = NO;
                identityStore.linkedMobileNo = nil;
                identityStore.linkMobileNoVerificationId = nil;
            } else {
                identityStore.linkMobileNoPending = YES;
                identityStore.linkedMobileNo = mobileNo;
                identityStore.linkMobileNoVerificationId = response[@"verificationId"];
                identityStore.linkMobileNoStartDate = [NSDate date];
            }
            onCompletion(NO);
        } onError:onError];
    } onError:onError];
}

- (void)linkMobileNoWithStore:(MyIdentityStore*)identityStore code:(NSString*)code onCompletion:(void(^)(BOOL linked))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (!identityStore.linkMobileNoPending || identityStore.linkMobileNoVerificationId == nil) {
        DDLogWarn(@"No mobileNo verification pending");
        onError([ThreemaError threemaError:@"No verification pending"]);
        return;
    }
    
    NSDictionary *req = @{
                          @"verificationId": identityStore.linkMobileNoVerificationId,
                          @"code": code
                          };
    
    [ServerAPIRequest postJSONToAPIPath:@"identity/link_mobileno" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"link mobileNo phase 3 request success: %@", jsonObject);
        
        identityStore.linkMobileNoPending = NO;
        identityStore.linkMobileNoVerificationId = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ThreemaIdentityLinkedWithMobileNo" object:nil];
        
        onCompletion(YES);
        
    } onError:^(NSError *error) {
        DDLogError(@"link mobileNo phase 3 request failed: %@", error);
        onError(error);
    }];
}

- (void)linkMobileNoRequestCallWithStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (!identityStore.linkMobileNoPending || identityStore.linkMobileNoVerificationId == nil) {
        DDLogWarn(@"No mobileNo verification pending");
        onError([ThreemaError threemaError:@"No verification pending"]);
        return;
    }
    
    NSDictionary *req = @{
                          @"verificationId": identityStore.linkMobileNoVerificationId
                          };
    
    [ServerAPIRequest postJSONToAPIPath:@"identity/link_mobileno_call" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"link mobileNo call request success: %@", jsonObject);
        onCompletion();
    } onError:^(NSError *error) {
        DDLogError(@"link mobileNo call request failed: %@", error);
        onError(error);
    }];
}

- (void)obtainMatchTokenForIdentity:(MyIdentityStore*)identityStore forceRefresh:(BOOL)forceRefresh onCompletion:(void(^)(NSString *matchToken))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onCompletion(nil);
        return;
    }
    
    // Cached match token?
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSString *matchToken = [defaults objectForKey:@"MatchToken"];
    if (!forceRefresh && matchToken) {
        onCompletion(matchToken);
        return;
    }
    
    NSDictionary *request = @{
        @"identity": identityStore.identity
    };

    [self sendSignedRequest:request toApiPath:@"identity/match_token" forStore:identityStore onCompletion:^(id jsonObject) {
        if (jsonObject[@"matchToken"]) {
            [defaults setObject:jsonObject[@"matchToken"] forKey:@"MatchToken"];
            [defaults synchronize];
            onCompletion(jsonObject[@"matchToken"]);
        } else {
            onError([ThreemaError threemaError:jsonObject[@"error"]]);
        }
    } onError:onError];
}

- (void)matchIdentitiesWithEmailHashes:(NSArray*)emailHashes mobileNoHashes:(NSArray*)mobileNoHashes includeInactive:(BOOL)includeInactive onCompletion:(void(^)(NSArray *identities, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError {
    
    [self obtainMatchTokenForIdentity:[MyIdentityStore sharedMyIdentityStore] forceRefresh:NO onCompletion:^(NSString *matchToken) {
        DDLogInfo(@"Match token: %@", matchToken);
        
        [self matchIdentitiesWithEmailHashes:emailHashes mobileNoHashes:mobileNoHashes includeInactive:includeInactive matchToken:matchToken onCompletion:onCompletion onError:^(NSError *error) {
            // Match token may be invalid/expired, refresh and try again
            [self obtainMatchTokenForIdentity:[MyIdentityStore sharedMyIdentityStore] forceRefresh:YES onCompletion:^(NSString *matchToken) {
                [self matchIdentitiesWithEmailHashes:emailHashes mobileNoHashes:mobileNoHashes includeInactive:includeInactive matchToken:matchToken onCompletion:onCompletion onError:onError];
            } onError:onError];
        }];
    } onError:^(NSError *error) {
        DDLogError(@"Cannot obtain match token: %@", error);
        onError(error);
    }];
}

- (void)matchIdentitiesWithEmailHashes:(NSArray*)emailHashes mobileNoHashes:(NSArray*)mobileNoHashes includeInactive:(BOOL)includeInactive matchToken:(NSString*)matchToken onCompletion:(void(^)(NSArray *identities, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError {
    
    NSMutableDictionary *req = [NSMutableDictionary dictionary];
    req[@"emailHashes"] = emailHashes;
    req[@"mobileNoHashes"] = mobileNoHashes;
    if (matchToken != nil) {
        req[@"matchToken"] = matchToken;
    }
    if (includeInactive) {
        req[@"includeInactive"] = @YES;
    }
    
    [ServerAPIRequest postJSONToAPIPath:@"identity/match" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Match identities request success: %@", jsonObject);
        onCompletion([jsonObject objectForKey:@"identities"], ((NSNumber*)jsonObject[@"checkInterval"]).intValue);
    } onError:^(NSError *error) {
        DDLogError(@"Match identities request failed: %@", error);
        onError(error);
    }];
}

- (void)setFeatureMask:(NSNumber *)featureMask forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    NSString *apiPath = @"identity/set_featuremask";
    NSDictionary *req = @{
                          @"identity": identityStore.identity,
                          @"featureMask": featureMask
                          };
    
    [self sendSignedRequest:req toApiPath:apiPath forStore:identityStore onCompletion:^(NSDictionary *response) {
        if ([response[@"success"] boolValue])
            onCompletion();
        else
            onError([ThreemaError threemaError:response[@"error"]]);
    } onError:onError];
}

- (void)getFeatureMasksForIdentities:(NSArray*)identities onCompletion:(void(^)(NSArray* featureMasks))onCompletion onError:(void(^)(NSError *error))onError {
    NSDictionary *req = [NSDictionary dictionaryWithObjectsAndKeys:identities, @"identities", nil];
    
    [ServerAPIRequest postJSONToAPIPath:@"identity/check_featuremask" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Check featureMask success: %@", jsonObject);
        NSArray *featureMaskStrings = jsonObject[@"featureMasks"];
        
        NSMutableArray *featureMaskNumbers = [NSMutableArray arrayWithCapacity: [featureMaskStrings count]];
        for (NSString *maskString in featureMaskStrings) {
            if ([maskString isEqual: [NSNull null]]) {
                NSNumber *number = [NSNumber numberWithInt: 0];
                [featureMaskNumbers addObject: number];
            } else {
                NSNumber *number = [NSNumber numberWithInt: maskString.intValue];
                [featureMaskNumbers addObject: number];
            }
        }
        
        onCompletion(featureMaskNumbers);
    } onError:^(NSError *error) {
        DDLogError(@"Check featureMask failed: %@", error);
        onError(error);
    }];
}

- (void)checkRevocationPasswordForStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(BOOL revocationPasswordSet, NSDate *lastChanged))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }

    NSDictionary *request = @{
                              @"identity": identityStore.identity
                              };
    
    [self sendSignedRequest:request toApiPath:@"identity/check_revocation_key" forStore:identityStore onCompletion:^(NSDictionary *response) {
        BOOL revocationPasswordSet = [response[@"revocationKeySet"] boolValue];
        NSDate *lastChanged = nil;
        if (revocationPasswordSet)
            lastChanged = [Utils parseISO8601DateString:response[@"lastChanged"]];
        onCompletion(revocationPasswordSet, lastChanged);
    } onError:onError];
}

- (void)setRevocationPassword:(NSString*)revocationPassword forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    /* key = first 32 bits of SHA-256 hash of password string */
    NSData *revocationPasswordData = [revocationPassword dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(revocationPasswordData.bytes, (CC_LONG)revocationPasswordData.length, digest);
    NSData *revocationKey = [NSData dataWithBytes:digest length:4];
    
    NSDictionary *request = @{
                              @"identity": identityStore.identity,
                              @"revocationKey": [revocationKey base64EncodedStringWithOptions:0]
                              };
    
    [self sendSignedRequest:request toApiPath:@"identity/set_revocation_key" forStore:identityStore onCompletion:^(id jsonObject) {
        if ([jsonObject[@"success"] boolValue])
            onCompletion();
        else
            onError([ThreemaError threemaError:jsonObject[@"error"]]);
    } onError:onError];
}

- (void)checkStatusOfIdentities:(NSArray*)identities onCompletion:(void(^)(NSArray* states, NSArray* types, NSArray* featureMasks, int checkInterval))onCompletion onError:(void(^)(NSError *error))onError {
    NSDictionary *req = [NSDictionary dictionaryWithObjectsAndKeys:identities, @"identities", nil];
    
    [ServerAPIRequest postJSONToAPIPath:@"identity/check" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Check ID status success: %@", jsonObject);
        onCompletion(jsonObject[@"states"], jsonObject[@"types"], jsonObject[@"featureMasks"], [jsonObject[@"checkInterval"] intValue]);
    } onError:^(NSError *error) {
        DDLogError(@"Check ID status failed: %@", error);
        onError(error);
    }];
}

- (void)revokeIdForStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    NSDictionary *request = @{
                              @"identity": identityStore.identity,
                              @"lang": [self preferredLanguage]
                              };
    
    [self sendSignedRequest:request toApiPath:@"identity/revoke" forStore:identityStore onCompletion:^(id jsonObject) {
        if ([jsonObject[@"success"] boolValue])
            onCompletion();
        else
            onError([ThreemaError threemaError:jsonObject[@"error"]]);
    } onError:onError];
}

- (void)validateLicenseUsername:(NSString*)licenseUsername password:(NSString*)licensePassword appId:(NSString*)appId version:(NSString*)version deviceId:(NSString*)deviceId onCompletion:(void(^)(BOOL success, NSDictionary *info))onCompletion onError:(void(^)(NSError *error))onError {
    
    static NSString *apiPath = @"check_license";
    
    NSDictionary *request = @{
                              @"licenseUsername": licenseUsername,
                              @"licensePassword": licensePassword,
                              @"appId": appId,
                              @"version": version,
                              @"deviceId": deviceId
                              };
    
    [self sendSignedRequestPhase1:request toApiPath:apiPath onCompletion:^(NSDictionary *response) {
        BOOL success = [response[@"success"] boolValue];
        onCompletion(success, response);
    } onError:onError];
}

- (void)updateWorkInfoForStore:(MyIdentityStore*)identityStore licenseUsername:(NSString*)licenseUsername password:(NSString*)licensePassword onCompletion:(void(^)(BOOL sent))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"store has no valid identity"]);
        return;
    }
    
    NSMutableDictionary *request = [@{
        @"identity": identityStore.identity,
        @"licenseUsername": licenseUsername,
        @"licensePassword": licensePassword,
        @"publicNickname": (identityStore.pushFromName != nil ? identityStore.pushFromName : identityStore.identity),
        @"version": [Utils getClientVersion]
    } mutableCopy];
    
    if (identityStore.firstName != nil)
        request[@"firstName"] = identityStore.firstName;
    if (identityStore.lastName != nil)
        request[@"lastName"] = identityStore.lastName;
    if (identityStore.csi != nil)
        request[@"csi"] = identityStore.csi;
    if (identityStore.category != nil)
        request[@"category"] = identityStore.category;
        
    if ([request isEqualToDictionary:identityStore.lastWorkUpdateRequest] && ![identityStore sendUpdateWorkInfoStatus]) {
        // request hasn't changed since last update and it's the same date
        onCompletion(false);
        return;
    }
    
    [self sendSignedRequest:request toApiPath:@"identity/update_work_info" forStore:identityStore onCompletion:^(id jsonObject) {
        if ([jsonObject[@"success"] boolValue]) {
            identityStore.lastWorkUpdateRequest = request;
            [identityStore setLastWorkUpdateDate:[NSDate date]];
            onCompletion(true);
        } else {
            onError([ThreemaError threemaError:jsonObject[@"error"]]);
        }
    } onError:onError];
}

- (void)searchInDirectory:(NSString *)searchString categories:(NSArray *)categories page:(int)page forLicenseStore:(LicenseStore *)licenseStore forMyIdentityStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSArray *contacts, NSDictionary *paging))onCompletion onError:(void(^)(NSError *error))onError {
    NSString *sortOrder = [[UserSettings sharedUserSettings] sortOrderFirstName] ? @"firstName" : @"lastName";

    NSMutableDictionary *req = [[NSMutableDictionary alloc] initWithDictionary:@{@"username": licenseStore.licenseUsername,
                          @"password": licenseStore.licensePassword,
                          @"identity": identityStore.identity,
                          @"query": searchString,
                          @"sort": @{@"by": sortOrder, @"asc": @true},
                          @"page": [NSNumber numberWithInt:page]
                          }];
    
    if (categories.count > 0) {
        [req setValue:categories forKey:@"categories"];
    }
    
    [ServerAPIRequest postJSONToWorkAPIPath:@"directory" data:req onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Work directory search success: %@", jsonObject);
        NSArray *contactsArray = jsonObject[@"contacts"];
        NSDictionary *paging = jsonObject[@"paging"];
        onCompletion(contactsArray, paging);
    } onError:^(NSError *error) {
        DDLogError(@"Check featureMask failed: %@", error);
        onError(error);
    }];
}

- (void)obtainTurnServersWithStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError {
    
    if (identityStore.identity == nil) {
        onError([ThreemaError threemaError:@"No identity"]);
        return;
    }
    
    NSDictionary *request = @{
        @"identity": identityStore.identity,
        @"type": @"voip"
    };

    [self sendSignedRequest:request toApiPath:@"identity/turn_cred" forStore:identityStore onCompletion:^(id jsonObject) {
        if (jsonObject[@"turnUrls"]) {
            onCompletion(jsonObject);
        } else {
            onError([ThreemaError threemaError:jsonObject[@"error"]]);
        }
    } onError:onError];
}

- (void)sendSignedRequest:(NSDictionary*)request toApiPath:(NSString*)apiPath forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError {
    [self sendSignedRequestPhase1:request toApiPath:apiPath onCompletion:^(NSDictionary *response) {
        [self sendSignedRequestPhase2:request toApiPath:apiPath phase1Response:response forStore:identityStore onCompletion:onCompletion onError:onError];
    } onError:onError];
}

- (void)sendSignedRequestPhase1:(NSDictionary*)request toApiPath:(NSString*)apiPath onCompletion:(void(^)(NSDictionary* response))onCompletion onError:(void(^)(NSError *error))onError {
    [ServerAPIRequest postJSONToAPIPath:apiPath data:request onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Send API request %@ phase 1 success: %@", apiPath, jsonObject);
        onCompletion((NSDictionary*)jsonObject);
    } onError:^(NSError *error) {
        DDLogVerbose(@"Send API request %@ phase 1 failed: %@", apiPath, error);
        onError(error);
    }];
}

- (void)sendSignedRequestPhase2:(NSDictionary*)request toApiPath:(NSString*)apiPath phase1Response:(id)phase1Response forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError {
    
    NSData *nonce = [[NaClCrypto sharedCrypto] randomBytes:kNaClCryptoNonceSize];
    [self sendSignedRequestPhase2:request toApiPath:apiPath phase1Response:phase1Response withNonce:nonce forStore:identityStore onCompletion:onCompletion onError:onError];
}

- (void)sendSignedRequestPhase2:(NSDictionary*)request toApiPath:(NSString*)apiPath phase1Response:(id)phase1Response withNonce:(NSData*)nonce forStore:(MyIdentityStore*)identityStore onCompletion:(void(^)(NSDictionary *response))onCompletion onError:(void(^)(NSError *error))onError {
    
    NSDictionary *resp1 = (NSDictionary*)phase1Response;
    
    NSString *tokenStr = resp1[@"token"];
    NSData *token = [[NSData alloc] initWithBase64EncodedString:tokenStr options:0];
    NSData *tokenRespKeyPub = [[NSData alloc] initWithBase64EncodedString:resp1[@"tokenRespKeyPub"] options:0];
        
    /* token must start with 0xff and be longer than 32 bytes to avoid payload confusion */
    if (token.length <= 32 || (((const uint8_t*)token.bytes)[0] != 0xff)) {
        onError([ThreemaError threemaError:@"Bad token"]);
        return;
    }

    /* sign token with our secret key */
    NSData *response = [identityStore encryptData:token withNonce:nonce publicKey:tokenRespKeyPub];
    if (response == nil) {
        NSError *error = [ThreemaError threemaError:@"could not encrypt response"];
        DDLogVerbose(@"Send API request %@ phase 2 failed: %@", apiPath, error);
        onError(error);
        return;
    }
    
    NSMutableDictionary *signedRequest = [NSMutableDictionary dictionaryWithDictionary:request];
    signedRequest[@"token"] = tokenStr;
    signedRequest[@"response"] = [response base64EncodedStringWithOptions:0];
    signedRequest[@"nonce"] = [nonce base64EncodedStringWithOptions:0];
    
    [ServerAPIRequest postJSONToAPIPath:apiPath data:signedRequest onCompletion:^(id jsonObject) {
        DDLogVerbose(@"Send API request %@ phase 2 success: %@", apiPath, jsonObject);
        onCompletion((NSDictionary*)jsonObject);
    } onError:^(NSError *error) {
        DDLogVerbose(@"Send API request %@ phase 2 failed: %@", apiPath, error);
        onError(error);
    }];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    switch (connection.currentRequest.cachePolicy) {
        case NSURLRequestReloadIgnoringLocalCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            return cachedResponse;
    }
}

@end
