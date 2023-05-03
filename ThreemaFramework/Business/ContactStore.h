//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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
#import <PromiseKit/PromiseKit.h>
#import "UserSettings.h"

@class ContactEntity, Conversation;
@class MediatorSyncableContacts;

typedef NS_CLOSED_ENUM(NSInteger, ContactAcquaintanceLevel) {
    ContactAcquaintanceLevelDirect = 0,     // Contact is added manually or by sync with address book or by work directory or has a 1:1 conversation
    ContactAcquaintanceLevelGroup = 1       // Contact is only member of a group conversation -> contact is marked as hidden
};

NS_ASSUME_NONNULL_BEGIN

@protocol ContactStoreProtocol <NSObject>

- (nullable ContactEntity *)contactForIdentity:(nullable NSString *)identity
    NS_SWIFT_NAME(contact(for:))
    DEPRECATED_MSG_ATTRIBUTE("Use EntityManager to load contact in the right database context");

- (void)prefetchIdentityInfo:(NSSet<NSString *> *)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchWorkIdentities:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError;

- (void)fetchPublicKeyForIdentity:(NSString*)identity acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError
    NS_SWIFT_NAME(fetchPublicKey(for:acquaintanceLevel:onCompletion:onError:));

- (void)fetchPublicKeyForIdentity:(nullable NSString *)identity acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel entityManager:(NSObject * _Nonnull)entityManagerObject onCompletion:(void(^)(NSData * _Nullable publicKey))onCompletion onError:(nullable void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(fetchPublicKey(for:acquaintanceLevel:entityManager:onCompletion:onError:));

- (void)removeProfilePictureFlagForAllContacts;
- (void)removeProfilePictureRequest:(NSString *)identity;

- (void)addContactWithIdentity:(NSString *)identity verificationLevel:(int32_t)verificationLevel onCompletion:(void(^)(ContactEntity * _Nullable contact, BOOL alreadyExists))onCompletion onError:(nullable void(^)(NSError *error))onError
    NS_SWIFT_NAME(addContact(with:verificationLevel:onCompletion:onError:));

- (void)updateContactWithIdentity:(NSString * _Nonnull)identity avatar:(NSData * _Nullable)avatar firstName:(NSString * _Nullable)firstName lastName:(NSString * _Nullable)lastName;

- (void)deleteContactWithIdentity:(nonnull NSString *)identity entityManagerObject:(nonnull NSObject *)entityManagerObject NS_SWIFT_NAME(deleteContact(identity:entityManagerObject:));

/* synchronize contacts from address book with server */
- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync ignoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(nullable void(^)(BOOL addressBookAccessGranted))onCompletion onError:(nullable void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(synchronizeAddressBook(forceFullSync:ignoreMinimumInterval:onCompletion:onError:));

- (void)reflectContact:(nullable ContactEntity *)contact NS_SWIFT_NAME(reflect(_:));

- (void)reflectDeleteContact:(nullable NSString *)identity;

- (void)updateProfilePicture:(nullable NSString *)identity imageData:(NSData *)imageData shouldReflect:(BOOL)shouldReflect didFailWithError:(NSError * _Nullable * _Nullable)error;
- (void)deleteProfilePicture:(nullable NSString *)identity shouldReflect:(BOOL)shouldReflect;
- (void)removeProfilePictureFlagForIdentity:(NSString *)identity
    NS_SWIFT_NAME(removeProfilePictureFlag(for:));

- (void)updateAllContactsToCNContact;
- (void)updateAllContacts;

/**
 Mark contact identity as work contact, adding identities to `UserSettings.workIdentities`.

 @param identities: Identities of contacts to mark as work contact
 @param contactSyncer: Contact synchronizer for multi device
 */
- (void)addAsWorkWithIdentities:(NSOrderedSet *)identities contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts
    NS_SWIFT_NAME(addAsWork(identities:contactSyncer:));

/**
 Set new instance of EntityManager, its needed in Notification Extension after reset of database context.
 */
- (void)resetEntityManager;

@end

@interface ContactStore : NSObject <ContactStoreProtocol>

+ (ContactStore *)sharedContactStore;
- (instancetype) __unavailable init;

#if DEBUG
- (instancetype)initWithUserSettings:(id<UserSettingsProtocol>)userSettingsProtocol entityManager:(NSObject *)entityManagerObject;
#endif

- (void)addContactWithIdentity:(nullable NSString *)identity publicKey:(nullable NSData *)publicKey cnContactId:(nullable NSString *)cnContactId verificationLevel:(int32_t)verificationLevel state:(nullable NSNumber *)state type:(nullable NSNumber *)type featureMask:(nullable NSNumber *)featureMask acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel alerts:(BOOL)alerts onCompletion:(nonnull void(^)(ContactEntity * nullable))onCompletion
    NS_SWIFT_NAME(addContact(with:publicKey:cnContactID:verificationLevel:state:type:featureMask:acquaintanceLevel:alerts:onCompletion:));

- (AnyPromise *)addWorkContactAndUpdateFeatureMaskWithIdentity:(nonnull NSString *)identity publicKey:(nonnull NSData *)publicKey firstname:(nullable NSString *)firstname lastname:(nullable NSString *)lastname acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel
    NS_SWIFT_NAME(addWorkContact(with:publicKey:firstname:lastname:acquaintanceLevel:));
- (nullable ContactEntity *)addWorkContactWithIdentity:(nonnull NSString *)identity publicKey:(nonnull NSData *)publicKey firstname:(nullable NSString *)firstname lastname:(nullable NSString *)lastname acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel entityManager:(NSObject * _Nonnull)entityManagerObject contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts
    NS_SWIFT_NAME(addWorkContact(with:publicKey:firstname:lastname:acquaintanceLevel:entityManager:contactSyncer:));

- (void)resetImportedStatus;

- (void)linkContact:(ContactEntity *)contact toCnContactId:(NSString *)cnContactId
    NS_SWIFT_NAME(link(_:toCnContactID:));
- (void)unlinkContact:(ContactEntity *)contact
    NS_SWIFT_NAME(unlink(_:));
- (void)upgradeContact:(ContactEntity *)contact toVerificationLevel:(int32_t)verificationLevel
    NS_SWIFT_NAME(upgrade(_:toVerificationLevel:));
- (void)setWorkContact:(nullable ContactEntity *)contact workContact:(BOOL)workContact;

- (void)updateNickname:(nonnull NSString *)identity nickname:(NSString *)nickname shouldReflect:(BOOL)shouldReflect;

/* manage profile picture request list */
- (BOOL)existsProfilePictureRequestForIdentity:(nullable NSString *)identity
    NS_SWIFT_NAME(existsProfilePictureRequest(for:));

/* synchronize contacts from address book with server */
- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync onCompletion:(nullable void(^)(BOOL addressBookAccessGranted))onCompletion onError:(nullable void(^)(NSError * _Nullable error))onError
    NS_SWIFT_NAME(synchronizeAddressBook(forceFullSync:onCompletion:onError:));

- (AnyPromise *)updateFeatureMasksForContacts:(nonnull NSArray *)contacts contactSyncer:(MediatorSyncableContacts * _Nullable)mediatorSyncableContacts;
- (AnyPromise *)updateFeatureMasksForIdentities:(nonnull NSArray<NSString *> *)Identities;
- (AnyPromise *)updateFeatureMasksForIdentities:(nonnull NSArray *)identities contactSyncer:(MediatorSyncableContacts * _Nullable)mediatorSyncableContacts;

- (void)linkedIdentitiesForEmail:(NSString *)email AndMobileNo:(NSString *)mobileNo onCompletion:(void(^)(NSArray *identities))onCompletion
    NS_SWIFT_NAME(linkedIdentities(for:and:onCompletion:));

- (nullable NSArray *)allIdentities;
- (nullable NSArray<NSString *> *)contactsWithFeatureMaskNil;
- (nullable NSArray *)allContacts;

- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)cnContactEmailsForContact:(ContactEntity *)contact NS_SWIFT_NAME(cnContactEmails(for:));
- (nullable NSArray<NSDictionary<NSString *, NSString *> *> *)cnContactPhoneNumbersForContact:(ContactEntity *)contact NS_SWIFT_NAME(cnContactPhoneNumbers(for:));

// Just for unit test
#if DEBUG
- (NSString*)hashEmailBase64:(NSString*)email;
#endif

@end

NS_ASSUME_NONNULL_END
