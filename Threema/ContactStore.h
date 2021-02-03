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

@class Contact;

@interface ContactStore : NSObject

+ (ContactStore*)sharedContactStore;

- (void)fetchPublicKeyForIdentity:(NSString*)identity onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError;
- (void)prefetchIdentityInfo:(NSSet*)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;
- (Contact*)contactForIdentity:(NSString *)identity;

/* The following function must be run on the main queue! */
- (void)addContactWithIdentity:(NSString*)identity verificationLevel:(int32_t)verificationLevel onCompletion:(void(^)(Contact *contact, BOOL alreadyExists))onCompletion onError:(void(^)(NSError *error))onError;
- (Contact*)addContactWithIdentity:(NSString*)identity publicKey:(NSData*)publicKey cnContactId:(NSString *)cnContactId verificationLevel:(int32_t)verificationLevel featureMask:(NSNumber *)featureMask alerts:(BOOL)alerts;
- (Contact*)addContactWithIdentity:(NSString*)identity publicKey:(NSData*)publicKey cnContactId:(NSString *)cnContactId verificationLevel:(int32_t)verificationLevel state:(NSNumber *)state type:(NSNumber *)type featureMask:(NSNumber *)featureMask alerts:(BOOL)alerts;
- (Contact *)addWorkContactWithIdentity:(NSString *)identity publicKey:(NSData*)publicKey firstname:(NSString *)firstname lastname:(NSString *)lastname;

- (void)updateContact:(Contact*)contact;
- (void)linkContact:(Contact *)contact toCnContactId:(NSString *)cnContactId;
- (void)unlinkContact:(Contact*)contact;
- (void)upgradeContact:(Contact*)contact toVerificationLevel:(int)verificationLevel;
- (void)setWorkContact:(Contact *)contact workContact:(BOOL)workContact;
- (void)updateProfilePicture:(Contact *)contact imageData:(NSData *)imageData didFailWithError:(NSError **)error;
- (void)deleteProfilePicture:(Contact *)contact;
- (void)removeProfilePictureFlagForAllContacts;
- (void)removeProfilePictureFlagForContact:(NSString *)identity;

/* manage profile picture request list */
- (BOOL)existsProfilePictureRequest:(NSString *)identity;
- (void)removeProfilePictureRequest:(NSString *)identity;

/* synchronize contacts from address book with server */
- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError;
- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync ignoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError;

- (void)updateAllContacts;

- (void)updateFeatureMasksForContacts:(NSArray *)contacts onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;
- (void)updateFeatureMasksForIdentities:(NSArray *)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (void)linkedIdentities:(NSString*)email mobileNo:(NSString*)mobileNo onCompletion:(void(^)(NSArray *identities))onCompletion;

- (NSArray*)allIdentities;
- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel;
- (NSArray *)contactsWithFeatureMaskNil;
- (NSArray *)allContacts;

- (void)updateAllContactsToCNContact;

- (void)cnContactAskAccessEmailsForContact:(Contact *)contact completionHandler:(void (^)(BOOL granted, NSArray *array))completionHandler;
- (void)cnContactAskAccessPhoneNumbersForContact:(Contact *)contact completionHandler:(void (^)(BOOL granted, NSArray *array))completionHandler;
- (NSArray *)cnContactEmailsForContact:(Contact *)contact;
- (NSArray *)cnContactPhoneNumbersForContact:(Contact *)contact;

@end
