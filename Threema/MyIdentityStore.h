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

@interface MyIdentityStore : NSObject

@property (strong, nonatomic, readwrite) NSString *identity;
@property (strong, nonatomic, readwrite) NSString *serverGroup;
@property (strong, nonatomic, readonly) NSData *publicKey;

@property (strong, nonatomic, readwrite) NSString *pushFromName;
@property (strong, nonatomic, readwrite) NSMutableDictionary *profilePicture;

@property (nonatomic, readwrite) BOOL linkEmailPending;
@property (strong, nonatomic, readwrite) NSString *linkedEmail;

@property (nonatomic, readwrite) BOOL linkMobileNoPending;
@property (strong, nonatomic, readwrite) NSString *linkMobileNoVerificationId;
@property (strong, nonatomic, readwrite) NSDate *linkMobileNoStartDate;
@property (strong, nonatomic, readwrite) NSString *linkedMobileNo;

@property (strong, nonatomic, readwrite) NSDate *privateIdentityInfoLastUpdate;

@property (nonatomic, readwrite) NSInteger lastSentFeatureMask;

@property (strong, nonatomic, readwrite) NSDate *revocationPasswordSetDate;
@property (strong, nonatomic, readwrite) NSDate *revocationPasswordLastCheck;

@property (strong, nonatomic, readwrite) NSDate *licenseLastCheck;
@property (strong, nonatomic, readwrite) NSString *licenseLogoLightUrl;
@property (strong, nonatomic, readwrite) NSString *licenseLogoDarkUrl;
@property (strong, nonatomic, readwrite) NSString *licenseSupportUrl;

/*!
 * @field pendingCreateID
 * This property should be true if the threema id is created or restored and the setup is not completed.
 * When the setup is completed, we have to set this value to false. Otherwise it can't connect to the server.
 */
@property (nonatomic, readwrite) BOOL pendingCreateID;
@property (strong, nonatomic, readwrite) NSString *createIDEmail;
@property (strong, nonatomic, readwrite) NSString *createIDPhone;

@property (strong, nonatomic, readwrite) NSString *firstName;
@property (strong, nonatomic, readwrite) NSString *lastName;
@property (strong, nonatomic, readwrite) NSString *csi;
@property (strong, nonatomic, readwrite) NSString *category;

@property (strong, nonatomic, readwrite) NSString *companyName;
@property (strong, nonatomic, readwrite) NSMutableDictionary *directoryCategories;

@property (strong, nonatomic, readwrite) NSString *tempSafePassword;

@property (strong, nonatomic, readwrite) NSDictionary *lastWorkUpdateRequest;
@property (strong, nonatomic, readwrite) NSDate *lastWorkUpdateDate;

+ (MyIdentityStore*)sharedMyIdentityStore;
+ (void)resetSharedInstance;

- (BOOL)isProvisioned;
- (BOOL)isKeychainLocked;
- (void)generateKeyPairWithSeed:(NSData*)seed;
- (void)destroy;
- (void)storeInKeychain;
- (void)updateConnectionRights;
- (NSArray *)directoryCategoryIdsSortedByName;

- (NSData*)encryptData:(NSData*)data withNonce:(NSData*)nonce publicKey:(NSData*)publicKey;
- (NSData*)decryptData:(NSData*)data withNonce:(NSData*)nonce publicKey:(NSData*)_publicKey;
- (NSData*)keySecret;

- (NSString*)backupIdentityWithPassword:(NSString*)password;
- (NSString*)addBackupGroupDashes:(NSString*)backup;
- (void)restoreFromBackup:(NSString*)backup withPassword:(NSString*)password onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;
- (void)restoreFromBackup:(NSString*)myIdentity withSecretKey:(NSData*)mySecretKey onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;
- (BOOL)isValidBackupFormat:(NSString*)backup;
- (BOOL)sendUpdateWorkInfoStatus;

@end
