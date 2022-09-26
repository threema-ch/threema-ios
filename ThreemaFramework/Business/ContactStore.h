//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

NS_ASSUME_NONNULL_BEGIN

@protocol ContactStoreProtocol <NSObject>

- (nullable Contact *)contactForIdentity:(nullable NSString *)identity
    NS_SWIFT_NAME(contact(for:))
    DEPRECATED_MSG_ATTRIBUTE("Use EntityManager to load contact in the right database context");

- (void)prefetchIdentityInfo:(NSSet<NSString *> *)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchWorkIdentitiesInBlockUnknownCheck:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchPublicKeyForIdentity:(NSString*)identity onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(fetchPublicKey(for:onCompletion:onError:));

/**
 Fetch public key for identity and save core data contact.
 @param identity: Identity to fetch
 @param entityManagerObject: EntityManager to operate on the right core data DB context
 @param onCompletion: Called on completion and returns the public key
 @param onError: Called on any error
 */
- (void)fetchPublicKeyForIdentity:(nullable NSString *)identity entityManager:(NSObject * _Nonnull)entityManagerObject onCompletion:(void(^)(NSData * _Nullable publicKey))onCompletion onError:(nullable void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(fetchPublicKey(for:entityManager:onCompletion:onError:));

- (void)removeProfilePictureFlagForAllContacts;
- (void)removeProfilePictureRequest:(NSString *)identity;

- (void)addContactWithIdentity:(NSString *)identity verificationLevel:(int32_t)verificationLevel onCompletion:(void(^)(Contact * _Nullable contact, BOOL alreadyExists))onCompletion onError:(nullable void(^)(NSError *error))onError
    NS_SWIFT_NAME(addContact(with:verificationLevel:onCompletion:onError:));

/* synchronize contacts from address book with server */
- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync ignoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(nullable void(^)(BOOL addressBookAccessGranted))onCompletion onError:(nullable void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(synchronizeAddressBook(forceFullSync:ignoreMinimumInterval:onCompletion:onError:));

- (void)reflectContact:(nullable Contact *)contact;

- (void)reflectDeleteContact:(nullable NSString *)identity;

- (void)updateProfilePicture:(nullable NSString *)identity imageData:(NSData *)imageData shouldReflect:(BOOL)shouldReflect didFailWithError:(NSError * _Nullable * _Nullable)error;
- (void)deleteProfilePicture:(nullable NSString *)identity shouldReflect:(BOOL)shouldReflect;
- (void)removeProfilePictureFlagForIdentity:(NSString *)identity
    NS_SWIFT_NAME(removeProfilePictureFlag(for:));

- (void)updateAllContactsToCNContact;
- (void)updateAllContacts;

/**
 Set new instance of EntityManager, its needed in Notification Extension after reset of database context.
 */
- (void)resetEntityManager;

@end

@class MediatorSyncableContacts;

@interface ContactStore : NSObject <ContactStoreProtocol>

+ (ContactStore *)sharedContactStore;

- (void)addContactWithIdentity:(nullable NSString *)identity publicKey:(nullable NSData *)publicKey cnContactId:(nullable NSString *)cnContactId verificationLevel:(int32_t)verificationLevel state:(nullable NSNumber *)state type:(nullable NSNumber *)type featureMask:(nullable NSNumber *)featureMask alerts:(BOOL)alerts onCompletion:(nonnull void(^)(Contact * nullable))onCompletion
    NS_SWIFT_NAME(addContact(with:publicKey:cnContactID:verificationLevel:state:type:featureMask:alerts:onCompletion:));

- (nullable Contact *)addWorkContactWithIdentity:(NSString *)identity publicKey:(NSData*)publicKey firstname:(nullable NSString *)firstname lastname:(nullable NSString *)lastname shouldUpdateFeatureMask:(BOOL)shouldUpdateFeatureMask
    NS_SWIFT_NAME(addWorkContact(with:publicKey:firstname:lastname:shouldUpdateFeatureMask:));
- (nullable Contact *)batchAddWorkContactWithIdentity:(NSString *)identity publicKey:(nullable NSData*)publicKey firstname:(nullable NSString *)firstname lastname:(nullable NSString *)lastname shouldUpdateFeatureMask:(BOOL)shouldUpdateFeatureMask contactSyncer:(MediatorSyncableContacts*)mediatorSyncableContacts
    NS_SWIFT_NAME(batchAddWorkContact(with:publicKey:firstname:lastname:shouldUpdateFeatureMask:contactSyncer:));

- (void)resetImportedStatus;

- (void)linkContact:(Contact *)contact toCnContactId:(NSString *)cnContactId
    NS_SWIFT_NAME(link(_:toCnContactID:));
- (void)unlinkContact:(Contact *)contact
    NS_SWIFT_NAME(unlink(_:));
- (void)upgradeContact:(Contact *)contact toVerificationLevel:(int32_t)verificationLevel
    NS_SWIFT_NAME(upgrade(_:toVerificationLevel:));
- (void)setWorkContact:(nullable Contact *)contact workContact:(BOOL)workContact;

- (void)updateNickname:(nonnull NSString *)identity nickname:(NSString *)nickname shouldReflect:(BOOL)shouldReflect;

/* manage profile picture request list */
- (BOOL)existsProfilePictureRequestForIdentity:(nullable NSString *)identity
    NS_SWIFT_NAME(existsProfilePictureRequest(for:));

/* synchronize contacts from address book with server */
- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync onCompletion:(nullable void(^)(BOOL addressBookAccessGranted))onCompletion onError:(nullable void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(synchronizeAddressBook(forceFullSync:onCompletion:onError:));

- (void)updateFeatureMasksForContacts:(nullable NSArray *)contacts onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(updateFeatureMasks(for:onCompletion:onError:));
- (void)updateFeatureMasksForIdentities:(nullable NSArray *)identities
    NS_SWIFT_NAME(updateFeatureMasks(for:));

- (void)linkedIdentitiesForEmail:(NSString *)email AndMobileNo:(NSString *)mobileNo onCompletion:(void(^)(NSArray *identities))onCompletion
    NS_SWIFT_NAME(linkedIdentities(for:and:onCompletion:));

- (nullable NSArray *)allIdentities;
- (nullable NSArray *)contactsWithFeatureMaskNil;
- (nullable NSArray *)allContacts;

- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)cnContactEmailsForContact:(Contact *)contact;
- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)cnContactPhoneNumbersForContact:(Contact *)contact;

// Just for unit test
#if DEBUG
- (NSString*)hashEmailBase64:(NSString*)email;
#endif

@end

NS_ASSUME_NONNULL_END
