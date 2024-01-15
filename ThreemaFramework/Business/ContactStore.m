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

#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>
#import "PhoneNumberNormalizer.h"

#import "ContactStore.h"
#import "NSString+Hex.h"
#import "ContactEntity.h"
#import "ServerAPIConnector.h"
#import "ServerConnector.h"
#import "MyIdentityStore.h"
#import "ProtocolDefines.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "ThreemaError.h"
#import "AppGroup.h"
#import "WorkDataFetcher.h"
#import "ValidationLogger.h"
#import "IdentityInfoFetcher.h"
#import "CryptoUtils.h"
#import "TrustedContacts.h"
#import "LicenseStore.h"

#define MIN_CHECK_INTERVAL 5*60

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

static const uint8_t emailHashKey[] = {0x30,0xa5,0x50,0x0f,0xed,0x97,0x01,0xfa,0x6d,0xef,0xdb,0x61,0x08,0x41,0x90,0x0f,0xeb,0xb8,0xe4,0x30,0x88,0x1f,0x7a,0xd8,0x16,0x82,0x62,0x64,0xec,0x09,0xba,0xd7};
static const uint8_t mobileNoHashKey[] = {0x85,0xad,0xf8,0x22,0x69,0x53,0xf3,0xd9,0x6c,0xfd,0x5d,0x09,0xbf,0x29,0x55,0x5e,0xb9,0x55,0xfc,0xd8,0xaa,0x5e,0xc4,0xf9,0xfc,0xd8,0x69,0xe2,0x58,0x37,0x07,0x23};

static const NSTimeInterval minimumSyncInterval = 30;   /* avoid multiple concurrent syncs, e.g. triggered by interval timer + incoming message from unknown user */

@implementation ContactStore {
    NSDate *lastMaxModificationDate;
    NSDate *lastFullSyncDate;
    NSTimer *checkStatusTimer;
    dispatch_queue_t syncQueue;
    id<UserSettingsProtocol> userSettings;
    EntityManager *entityManager;
}

+ (ContactStore*)sharedContactStore {
    static ContactStore *instance;
    
    @synchronized (self) {
        if (!instance)
            instance = [[ContactStore alloc] init];
    }
    
    return instance;
}

- (instancetype)init
{
    return [self initWithUserSettings:[UserSettings sharedUserSettings] entityManager:[[EntityManager alloc] init]];
}

- (instancetype)initWithUserSettings:(id<UserSettingsProtocol>)userSettingsProtocol entityManager:(NSObject *)entityManagerObject {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Parameter entityManagerObject should be type of EntityManager");

    self = [super init];
    if (self) {
        syncQueue = dispatch_queue_create("ch.threema.contactsync", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(syncQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));

        /* register a callback to get information about address book changes */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressBookChangeDetected:) name:CNContactStoreDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orderChanged:) name:@"ThreemaContactsOrderChanged" object:nil];

        userSettings = userSettingsProtocol;
        entityManager = (EntityManager *)entityManagerObject;

        /* update display/sort order prefs to match system */
        BOOL sortOrder = [[CNContactsUserDefaults sharedDefaults] sortOrder] == CNContactSortOrderGivenName;
        [userSettings setSortOrderFirstName:sortOrder];
    }
    return self;
}

- (void)dealloc {
    [checkStatusTimer invalidate];
}

- (void)resetEntityManager {
    self->entityManager = [[EntityManager alloc] init];
}

- (void)addressBookChangeDetected:(NSNotification *)notification {
    DDLogNotice(@"Address book change detected");
    [self synchronizeAddressBookForceFullSync:NO onCompletion:^(BOOL addressBookAccessGranted) {
        [self updateAllContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddressbookSyncronized object:self userInfo:nil];
    } onError:^(NSError *error) {
        [self updateAllContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddressbookSyncronized object:self userInfo:nil];
    }];
}

- (ContactEntity*)contactForIdentity:(NSString *)identity {
    /* check in local DB first */
    ContactEntity *contact = [entityManager.entityFetcher contactForId: identity];
    return contact;
}

/**
 Add or update as none hidden contact.

 @param identity: Identity of the contact
 @param verificationLevel: Verification level for contact in case must be created
 */
- (void)addContactWithIdentity:(NSString *)identity verificationLevel:(int32_t)verificationLevel onCompletion:(nonnull void(^)(ContactEntity * _Nullable contact, BOOL alreadyExists))onCompletion onError:(void(^)(NSError *error))onError {

    /* check in local DB first */
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSError *error;
    ContactEntity *contact = [entityManager.entityFetcher contactForId:identity error:&error];
    if (contact) {
        [entityManager performSyncBlockAndSafe:^{
            if (contact.isContactHidden) {
                contact.isContactHidden = NO;

                MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
                [mediatorSyncableContacts updateAcquaintanceLevelWithIdentity:contact.identity value:[NSNumber numberWithInteger:ContactAcquaintanceLevelDirect]];
                [mediatorSyncableContacts syncAsync];
            }
        }];

        onCompletion(contact, YES);
        return;
    }
    if (error != nil) {
        if (onError != nil) {
            onError(error);
        }
        return;
    }
    
    /* not found - request from server */
    ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
    [apiConnector fetchIdentityInfo:identity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
        
        /* save new contact */
        dispatch_async(dispatch_get_main_queue(), ^{
            /* save new contact */
            MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

            __weak typeof(self) weakSelf = self;

            [self addContactWithIdentity:identity publicKey:publicKey cnContactId:nil verificationLevel:verificationLevel state:state type:type featureMask:featureMask acquaintanceLevel:ContactAcquaintanceLevelDirect alerts:YES contactSyncer:mediatorSyncableContacts onCompletion:^(ContactEntity *contact){
                [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
                    if (error == nil) {
                        /* force synchronisation */
                        [weakSelf synchronizeAddressBookForceFullSync:YES onCompletion:nil onError:nil];
                        [WorkDataFetcher checkUpdateWorkDataForce:YES onCompletion:nil onError:nil];

                        [[NSNotificationCenter defaultCenter] postNotificationName:kSafeBackupTrigger object:nil];

                        onCompletion(contact, NO);
                    }
                    else {
                        DDLogError(@"Contact multi device sync failed: %@", [error localizedDescription]);
                        onCompletion(nil, NO);
                    }
                }];
            }];
        });
    } onError:^(NSError *error) {
        if (onError != nil) {
            onError(error);
        }
    }];
}


- (void)addContactWithIdentity:(nullable NSString *)identity publicKey:(nullable NSData *)publicKey cnContactId:(nullable NSString *)cnContactId verificationLevel:(int32_t)verificationLevel state:(nullable NSNumber *)state type:(nullable NSNumber *)type featureMask:(nullable NSNumber *)featureMask acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel alerts:(BOOL)alerts onCompletion:(nonnull void(^)(ContactEntity * nullable))onCompletion {

    MediatorSyncableContacts *mediatorSyncableContacts = [MediatorSyncableContacts new];
    [self addContactWithIdentity:identity publicKey:publicKey cnContactId:cnContactId verificationLevel:verificationLevel state:state type:type featureMask:featureMask acquaintanceLevel:acquaintanceLevel alerts:alerts contactSyncer:mediatorSyncableContacts onCompletion:^(ContactEntity * contact) {

        [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
            if (error == nil) {
                onCompletion(contact);
            }
            else {
                onCompletion(nil);
            }
        }];
    }];
}

/**
 Add or update contact.

 @param identity: Identity of the contact (will be not validated)
 @param publicKey: Public key it corresponds with the identity (will be not validated)
 @param cnContactId: Is not null contact will be linked to this address book contact
 @param verificationLevel: Verification level of the identity
 @param state: State of the identity, will only be changed if is not null
 @param type: Type of the identity, will only be changed if is not null
 @param featureMask: Feature mask of the identity
 @param acquaintanceLevel: Is `group` contact will be marked as hidden
 @param alerts: Is `YES` an notification will be displayed, if public key of already existing contact differs to given public key
 @param contactSyncer: Contact syncer for multi device
 @param onCompletion: Completion handler with added/updated contact
 */
- (void)addContactWithIdentity:(nonnull NSString*)identity publicKey:(nonnull NSData*)publicKey cnContactId:(nullable NSString *)cnContactId verificationLevel:(int32_t)verificationLevel state:(nullable NSNumber *)state type:(nullable NSNumber *)type featureMask:(nullable NSNumber *)featureMask acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel alerts:(BOOL)alerts contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts onCompletion:(nonnull void(^)(ContactEntity * nullable))onCompletion {

    /* Make sure this is not our own identity */
    if ([MyIdentityStore sharedMyIdentityStore].isProvisioned && [identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogInfo(@"Ignoring attempt to add own identity");
        onCompletion(nil);
        return;
    }

    /* Check if we already have a contact with this identity */
    [entityManager performSyncBlockAndSafe:^{
        __block BOOL added = NO;

        void (^linkingFinished)(ContactEntity *) = ^(ContactEntity *contact){
            if (added) {
                [mediatorSyncableContacts updateAllWithIdentity:contact.identity added:added];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddedContact object:contact];
            }
            onCompletion(contact);
        };

        ContactEntity *contact = [entityManager.entityFetcher contactForId: identity];
        if (contact) {
            DDLogInfo(@"Found existing contact with identity %@", identity);
            if (![publicKey isEqualToData:contact.publicKey]) {
                DDLogError(@"Public key doesn't match for existing identity %@!", identity);
                
                if (alerts) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationErrorPublicKeyMismatch object:nil userInfo:nil];
                }

                onCompletion(contact);
                return;
            }

            if (contact.isContactHidden && acquaintanceLevel == ContactAcquaintanceLevelDirect) {
                contact.isContactHidden = NO;
                [mediatorSyncableContacts updateAcquaintanceLevelWithIdentity:contact.identity value:[NSNumber numberWithInteger:acquaintanceLevel]];
            }
        } else {
            added = YES;
            contact = [entityManager.entityCreator contact];
            contact.identity = identity;
            contact.publicKey = publicKey;
            contact.featureMask = featureMask;
            
            if (state != nil) {
                contact.state = state;
            }
            if (type != nil) {
                if ([type isEqualToNumber:@1]) {
                    [self addAsWorkWithIdentities:[[NSOrderedSet alloc] initWithArray:@[contact.identity]] contactSyncer:mediatorSyncableContacts];
                }
            }
            contact.isContactHidden = acquaintanceLevel == ContactAcquaintanceLevelGroup ? YES : NO;
            [self addProfilePictureRequest:identity];
        }
        
        if (contact.verificationLevel == nil || (contact.verificationLevel.intValue < verificationLevel && contact.verificationLevel.intValue != kVerificationLevelFullyVerified) || verificationLevel == kVerificationLevelFullyVerified) {
            contact.verificationLevel = [NSNumber numberWithInt:verificationLevel];
            [mediatorSyncableContacts updateVerificationLevelWithIdentity:identity value:contact.verificationLevel];
        }
        
        if (contact.workContact == nil) {
            if (contact.verificationLevel.intValue == kVerificationLevelWorkVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
                [mediatorSyncableContacts updateVerificationLevelWithIdentity:identity value:contact.verificationLevel];
                contact.workContact = @YES;
            } else if (contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
                [mediatorSyncableContacts updateVerificationLevelWithIdentity:identity value:contact.verificationLevel];
                contact.workContact = @YES;
            } else {
                contact.workContact = @NO;
            }
            [mediatorSyncableContacts updateWorkVerificationLevelWithIdentity:contact.identity value:contact.workContact];
        }
        if ([contact.workContact isEqualToNumber:@YES] && (contact.verificationLevel.intValue == kVerificationLevelWorkVerified || contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified)) {
            if (contact.verificationLevel.intValue == kVerificationLevelWorkVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
                [mediatorSyncableContacts updateVerificationLevelWithIdentity:identity value:contact.verificationLevel];
            } else if (contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
                [mediatorSyncableContacts updateVerificationLevelWithIdentity:identity value:contact.verificationLevel];
            }
        }
        
        // check if this is a trusted contact (like *THREEMA)
        if ([TrustedContacts isTrustedContactWithIdentity:identity publicKey:publicKey]) {
            contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
            [mediatorSyncableContacts updateVerificationLevelWithIdentity:identity value:contact.verificationLevel];
        }
        
        if (cnContactId) {
            if (contact.cnContactId != nil) {
                if (![contact.cnContactId isEqualToString:cnContactId]) {
                    /* contact is already linked to a different CNContactID - check if the name matches;
                     if so, the CNContactID may have changed and we need to re-link */
                    CNContactStore *cnAddressBook = [CNContactStore new];
                    
                    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                        if (granted == YES) {
                            NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[cnContactId]];
                            NSError *error;
                            NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                            if (error) {
                                DDLogError(@"error fetching contacts %@", error);
                            }
                            else {
                                if (cnContacts.count == 1) {
                                    CNContact *foundContact = cnContacts.firstObject;
                                    NSString *firstName = foundContact.givenName;
                                    NSString *lastName = foundContact.familyName;
                                    
                                    if (contact.firstName != nil && contact.firstName.length > 0 && contact.lastName != nil && contact.lastName.length > 0) {
                                        if ([firstName isEqualToString:contact.firstName] && [lastName isEqualToString:contact.lastName]) {
                                            DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                            [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts onCompletion:^{
                                                linkingFinished(contact);
                                            }];
                                            return;
                                        }
                                    }
                                    else if (contact.firstName != nil && contact.firstName.length > 0) {
                                        if ([firstName isEqualToString:contact.firstName]) {
                                            DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                            [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts onCompletion:^{
                                                linkingFinished(contact);
                                            }];
                                            return;
                                        }
                                    }
                                    else if (contact.lastName != nil && contact.lastName.length > 0) {
                                        if ([lastName isEqualToString:contact.lastName]) {
                                            DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                            [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts onCompletion:^{
                                                linkingFinished(contact);
                                            }];
                                            return;
                                        }
                                    }
                                    else {
                                        // No name for the contact to compare, replace the cncontactid
                                        DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                        [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts onCompletion:^{
                                            linkingFinished(contact);
                                        }];
                                        return;
                                    }
                                } // if (cnContacts.count == 1)
                            }
                        } // if (granted == YES)
                        
                        linkingFinished(contact);
                    }];
                    return;
                } // if (![contact.cnContactId isEqualToString:cnContactId])
            } // if (contact.cnContactId != nil)
            else {
                [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts onCompletion:^{
                    linkingFinished(contact);
                }];
                return;
            }
        } // if (cnContactId)

        linkingFinished(contact);
    }];
}

/**
 Add or update all linked address book contacts.

 @param identities: Identities to add and update
 @param emailHashes: Email hashes with contact id of address book
 @param mobileHashes: Mobile hashes with contact id of address book
 @param contactSyncer: Contact syncer for multi device
 @param onCompletion: Completion handler
 */
- (void)addContactsWithIdentities:(NSArray * _Nonnull)identities emailHashes:(NSDictionary * _Nonnull)emailHashToCnContactId mobileNoHashes:(NSDictionary * _Nonnull)mobileNoHashToCnContactId contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts onCompletion:(nonnull void(^)(void))onCompletion
{
    NSSet *excludedIds = [NSSet setWithArray:userSettings.syncExclusionList];
    NSMutableArray *allIdentities = [NSMutableArray new];

    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_group_t dispatchGroup = dispatch_group_create();

        for (NSDictionary *identityData in identities) {
            NSString *identity = [identityData objectForKey:@"identity"];

            /* ignore this ID? */
            if ([excludedIds containsObject:identity])
                continue;

            NSString *cnContactId = [emailHashToCnContactId objectForKey:[identityData objectForKey:@"emailHash"]];
            if (cnContactId == nil) {
                cnContactId = [mobileNoHashToCnContactId objectForKey:[identityData objectForKey:@"mobileNoHash"]];
            }
            if (cnContactId == nil) {
                continue;
            }

            DDLogVerbose(@"Adding identity %@ to contacts", identity);
            [allIdentities addObject:identity];

            dispatch_group_enter(dispatchGroup);

            [self addContactWithIdentity:identity publicKey:[[NSData alloc] initWithBase64EncodedString:[identityData objectForKey:@"publicKey"] options:0] cnContactId:cnContactId verificationLevel:kVerificationLevelServerVerified state:nil type:nil featureMask:nil acquaintanceLevel:ContactAcquaintanceLevelDirect alerts:NO contactSyncer:mediatorSyncableContacts onCompletion:^(ContactEntity *contact) {

                dispatch_group_leave(dispatchGroup);
            }];
        }
        DDLogNotice(@"[ContactSync] Found %lu new address book contacts", (unsigned long)allIdentities.count);

        dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);

        onCompletion();
    });
}

- (void)resetImportedStatus {
    [entityManager performSyncBlockAndSafe:^{
        NSArray *contacts = [entityManager.entityFetcher allContacts];
        for (ContactEntity *contact in contacts) {
            contact.importedStatus = ImportedStatusInitial;
        }
    }];
}

/** Add or update work contact, if multi device activated contact will be synced.

 @param identity: Identity of the contact (will be not validated)
 @param publicKey: Public key it corresponds with the identity (will be not validated)
 @param firstname: First name of the contact
 @param lastname: Last name of the contact
 @param acquaintanceLevel: Is `group` contact will be marked as hidden
 @param onCompletion: Returns added/updated contact
 @param onError: Error handler
 */
- (void)addWorkContactAndUpdateFeatureMaskWithIdentity:(nonnull NSString *)identity publicKey:(nonnull NSData *)publicKey firstname:(nullable NSString *)firstname lastname:(nullable NSString *)lastname acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel onCompletion:(nonnull void(^)(ContactEntity * _Nonnull contactEntity))onCompletion onError:(nonnull void(^)(NSError * _Nonnull error))onError {
    __block MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
    __block ContactEntity *contact;
    [entityManager performSyncBlockAndSafe:^{
        contact = [self addWorkContactWithIdentity:identity publicKey:publicKey firstname:firstname lastname:lastname acquaintanceLevel:acquaintanceLevel entityManager:entityManager contactSyncer:mediatorSyncableContacts];
    }];

    if (contact) {
        [self updateFeatureMasksForIdentities:@[contact.identity] contactSyncer:mediatorSyncableContacts onCompletion:^{
            [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
                if (error == nil) {
                    onCompletion(contact);
                }
                else {
                    DDLogError(@"Sync of contact failed: %@", error.localizedDescription);
                    onError(error);
                }
            }];
        } onError:^(NSError * _Nonnull error) {
            DDLogError(@"Update feature mask failed: %@", error.localizedDescription);
            onError(error);
        }];
    }
}

/**
 Add or update work contact, if multi device activated contact will be synced.

 @param identity: Identity of the contact (will be not validated)
 @param publicKey: Public key it corresponds with the identity (will be not validated)
 @param firstname: First name of the contact
 @param lastname: Last name of the contact
 @param acquaintanceLevel: Is `group` contact will be marked as hidden
 @returns: Added/updated contact or null if public key of already existing contact differs to given public key
 */
- (nullable ContactEntity *)addWorkContactWithIdentity:(nonnull NSString *)identity publicKey:(nonnull NSData *)publicKey firstname:(NSString *)firstname lastname:(NSString *)lastname acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel entityManager:(NSObject * _Nonnull)entityManagerObject contactSyncer:(MediatorSyncableContacts*)mediatorSyncableContacts {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Parameter entityManagerObject should be type of EntityManager");
    EntityManager *em = (EntityManager *)entityManagerObject;

    /* Make sure this is not our own identity */
    if ([MyIdentityStore sharedMyIdentityStore].isProvisioned && [identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogInfo(@"Ignoring attempt to add own identity");
        return nil;
    }
    
    /* Check if we already have a contact with this identity */
    ContactEntity *contact;

    BOOL added = NO;
    contact = [em.entityFetcher contactForId: identity];
    if (contact) {
        DDLogInfo(@"Found existing contact with identity %@", identity);
        if (![publicKey isEqualToData:contact.publicKey]) {
            DDLogError(@"Public key doesn't match for existing identity %@!", identity);
            contact = nil;
        }
        else {
            if (contact.isContactHidden && acquaintanceLevel == ContactAcquaintanceLevelDirect) {
                contact.isContactHidden = NO;
                [mediatorSyncableContacts updateAcquaintanceLevelWithIdentity:contact.identity value:[NSNumber numberWithInteger:acquaintanceLevel]];
            }
        }
    } else {
        DDLogNotice(@"New work contact added");
        added = YES;
        contact = [em.entityCreator contact];
        contact.identity = identity;
        contact.publicKey = publicKey;
        contact.isContactHidden = acquaintanceLevel == ContactAcquaintanceLevelGroup ? YES : NO;
        [self addAsWorkWithIdentities:[[NSOrderedSet alloc] initWithArray:@[contact.identity]] contactSyncer:mediatorSyncableContacts];
        [self addProfilePictureRequest:identity];
    }

    if (firstname != nil) {
        if (firstname.length > 0) {
            if (![contact.firstName isEqualToString:firstname]) {
                contact.firstName = firstname;
                [mediatorSyncableContacts updateFirstNameWithIdentity:contact.identity value:contact.firstName];
            }
        }
    }

    if (lastname != nil) {
        if (lastname.length > 0) {
            if (![contact.lastName isEqualToString:lastname]) {
                contact.lastName = lastname;
                [mediatorSyncableContacts updateLastNameWithIdentity:contact.identity value:contact.lastName];
            }
        }
    }

    if (contact.verificationLevel.intValue != kVerificationLevelFullyVerified) {
        if(![contact.verificationLevel isEqualToNumber:[NSNumber numberWithInt:kVerificationLevelServerVerified]]) {
            contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
            [mediatorSyncableContacts updateVerificationLevelWithIdentity:contact.identity value:contact.verificationLevel];
        }
    }

    if (![contact.workContact isEqualToNumber:@YES]) {
        contact.workContact = @YES;
        [mediatorSyncableContacts updateWorkVerificationLevelWithIdentity:contact.identity value:contact.workContact];
    }


    if (added) {
        [mediatorSyncableContacts updateAllWithIdentity:contact.identity added:added];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddedContact object:contact];
    }

    return contact;
}

- (void)updateFromAddressBookWithContact:(nonnull ContactEntity*)contact contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts forceImport:(BOOL)forceImport onCompletion:(nullable void(^)(void))onCompletion {

    if ([contact importedStatus] != ImportedStatusInitial && !forceImport) {
        DDLogInfo(@"Contact already imported. Do not import again.");
        if (onCompletion) {
            onCompletion();
        }
        return;
    }
    
    CNContactStore *cnAddressBook = [CNContactStore new];
    
    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted == YES) {
            NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[contact.cnContactId]];
            NSError *error;
            NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys  error:&error];
            if (error) {
                NSLog(@"error fetching contacts %@", error);
            } else {
                CNContact *foundContact = cnContacts.firstObject;
                if (foundContact != nil) {
                    [self _updateContact:contact withCnContact:foundContact forceImport:forceImport contactSyncer:mediatorSyncableContacts];
                }
            }
        }
        if (onCompletion) onCompletion();
    }];
}

- (void)_updateContact:(nonnull ContactEntity *)contact withCnContact:(nonnull CNContact *)cnContact forceImport:(BOOL)forceImport contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts {

    if (cnContact == nil) {
        DDLogError(@"Cannot update contact from nil cnContact");
        return;
    }
    
    if ([contact importedStatus] != ImportedStatusInitial && !forceImport) {
        DDLogInfo(@"Contact already imported. Do not import again.");
        return;
    }
    
    NSString *newFirstName = cnContact.givenName;
    NSString *newLastName = cnContact.familyName;
    
    /* no name? try company name and e-mail address (Outlook auto-generated contacts etc.) */
    if (newFirstName.length == 0 && newLastName.length == 0) {
        NSString *companyName = cnContact.organizationName;
        if (companyName.length > 0) {
            newLastName = companyName;
        } else {
            /* no name? try e-mail address (Outlook auto-generated contacts etc.) */
            if (cnContact.emailAddresses.count > 0) {
                newLastName = ((CNLabeledValue *)cnContact.emailAddresses.firstObject).value;
            }
        }
    }
    
    if (newFirstName != contact.firstName && ![newFirstName isEqual:contact.firstName]) {
        contact.firstName = newFirstName;
        [mediatorSyncableContacts updateFirstNameWithIdentity:contact.identity value:newFirstName];
    }
    
    if (newLastName != contact.lastName && ![newLastName isEqual:contact.lastName]) {
        contact.lastName = newLastName;
        [mediatorSyncableContacts updateLastNameWithIdentity:contact.identity value:newLastName];
    }

    
    /* get image, if any */
    NSData *newImageData = nil;
    if (cnContact.imageDataAvailable) {
        newImageData = cnContact.thumbnailImageData;
    }
    
    if (newImageData != contact.imageData && ![newImageData isEqualToData:contact.imageData]) {
        contact.imageData = newImageData;

        [mediatorSyncableContacts setProfileUpdateTypeWithIdentity:contact.identity value:contact.imageData != nil ? MediatorSyncableContacts.deltaUpdateTypeUpdated : MediatorSyncableContacts.deltaUpdateTypeRemoved];
    }

    ImportedStatus importedStatus = [[UserSettings sharedUserSettings] enableMultiDevice] ? ImportedStatusImported : ImportedStatusInitial;
    if (contact.importedStatus != importedStatus) {
        contact.importedStatus = importedStatus;
    }

    DDLogVerbose(@"Updated contact %@ to %@ %@", contact.identity, contact.firstName, contact.lastName);
}

- (void)updateAllContacts {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
    
    NSArray *allContacts = [entityManager.entityFetcher allContacts];
    if (allContacts == nil || allContacts.count == 0) {
        return;
    }
    
    // Migration of verification level kVerificationLevelWorkVerified and kVerificationLevelWorkFullyVerified to flag workContact
    [entityManager performSyncBlockAndSafe:^{
        for (ContactEntity *contact in allContacts) {
            if (contact.workContact == nil || contact.verificationLevel.intValue == kVerificationLevelWorkVerified || contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                if (contact.verificationLevel.intValue == kVerificationLevelWorkVerified) {
                    contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
                    [mediatorSyncableContacts updateVerificationLevelWithIdentity:contact.identity value:contact.verificationLevel];
                    contact.workContact = @YES;
                } else if (contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                    contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
                    [mediatorSyncableContacts updateVerificationLevelWithIdentity:contact.identity value:contact.verificationLevel];
                    contact.workContact = @YES;
                } else {
                    contact.workContact = @NO;
                }
                [mediatorSyncableContacts updateWorkVerificationLevelWithIdentity:contact.identity value:contact.workContact];
            }
        }
    }];
    
    __block NSArray *linkedContacts;
    [entityManager performBlockAndWait:^{
        linkedContacts = [allContacts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            ContactEntity *contact = (ContactEntity *)evaluatedObject;
            return contact.cnContactId != nil;
        }]];
    }];
    if (linkedContacts == nil || linkedContacts.count == 0) {
        [mediatorSyncableContacts syncAsync];
        return;
    }
    
    CNContactStore *cnAddressBook = [CNContactStore new];
    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted == YES) {
            // Go through all contacts and resync with address book; only create
            // address book ref when encountering the first contact that is linked
            __block int nupdated = 0;
                
            for (ContactEntity *contact in linkedContacts) {
                if (contact.cnContactId == nil) {
                    DDLogNotice(@"CNContactID of linked contact was nil.");
                    continue;
                };
                
                [entityManager performSyncBlockAndSafe:^{
                    ContactEntity *fetchedContact = [entityManager.entityFetcher contactForId:contact.identity];
                    NSString *cnContactID = [fetchedContact.cnContactId copy];
                    if (cnContactID == nil) {
                        return;
                    }

                    NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[cnContactID]];
                    NSError *error;
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                    if (error) {
                        DDLogError(@"Fetching address book contacts failed %@", error);
                    } else {
                        if (cnContacts != nil && cnContacts.count > 0) {
                            CNContact *foundContact = cnContacts.firstObject;
                            [self _updateContact:fetchedContact withCnContact:foundContact forceImport:NO contactSyncer:mediatorSyncableContacts];
                            nupdated++;
                        }
                    }
                }];
            }
            DDLogInfo(@"Updated %d contacts", nupdated);
    
            
            [self updateStatusForAllContactsIgnoreInterval:NO contactSyncer:mediatorSyncableContacts onCompletion:^{
                [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        DDLogError(@"Contact sync failed: %@", [error localizedDescription]);
                    }
                }];
            }];
        }
    }];
}

/**
 Update contact if attributes has changed and sync is multi device activated.

 @param identity: Identity of the contact to changed
 @param avatar: Image data of the contact avatar
 @param firstName: First name of the contact
 @param lastName: Last name of the contact
 */
- (void)updateContactWithIdentity:(NSString * _Nonnull)identity avatar:(NSData * _Nullable)avatar firstName:(NSString * _Nullable)firstName lastName:(NSString * _Nullable)lastName {

    [entityManager performSyncBlockAndSafe:^{
        ContactEntity *contact = [[entityManager entityFetcher] contactForId:identity];
        if (contact) {
            MediatorSyncableContacts *mediatorSyncableContacts = [MediatorSyncableContacts new];

            if (contact.imageData != avatar) {
                contact.imageData = avatar;
                [mediatorSyncableContacts setProfileUpdateTypeWithIdentity:identity value:contact.imageData ? 2 : 1];
            }

            if (contact.firstName != firstName) {
                contact.firstName = firstName;
                [mediatorSyncableContacts updateFirstNameWithIdentity:identity value:contact.firstName];
            }

            if (contact.lastName != lastName) {
                contact.lastName = lastName;
                [mediatorSyncableContacts updateLastNameWithIdentity:identity value:contact.lastName];
            }

            [mediatorSyncableContacts syncAsync];
        }
        else {
            DDLogError(@"Missing contact %@ to update", identity);
        }
    }];
}

/**
 Delete contact if no 1:1-conversation exists or it is not member in group. Hidden contacts are deleted if there exists a 1:1-conversation as long as there are no
 messages from this hidden contact (and they are not in a group).
 
 If Multi Device is activated the deletion will be reflected.

 @param identity: Identity of the contact to delete
 @param entityManagerObject: EntityManager on which the deletion will de executed
 */
- (void)deleteContactWithIdentity:(nonnull NSString *)identity entityManagerObject:(nonnull NSObject *)entityManagerObject {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Parameter entityManagerObject should be type of EntityManager");
    EntityManager *em = (EntityManager *)entityManagerObject;

    __block BOOL doReflect = NO;

    [em performSyncBlockAndSafe:^{
        ContactEntity *contact = [[em entityFetcher] contactForId:identity];
        if (contact) {
            if (!contact.isContactHidden) {
                // Prevent deletion if has contact a 1:1 conversation
                Conversation *conversation = [[em entityFetcher] conversationForContact:contact];
                if (conversation) {
                    DDLogWarn(@"Contact %@ can't be deleted because has a 1:1 conversation", contact.identity);
                    return;
                }
            }

            // Prevent deletion if is (hidden) contact member of a group
            NSArray<Conversation *> *groups = [[em entityFetcher] groupConversationsForContact:contact];
            if (groups && [groups count] > 0) {
                DDLogWarn(@"Contact %@ (hidden %d) can't be deleted because is still member of a group", contact.identity, contact.isContactHidden);
                return;
            }
            
            // Prevent deletion if hidden contact still has messages (in groups)
            if (contact.isContactHidden) {
                NSInteger numberOfMessages = [[em entityFetcher] countMessagesForContactWithIdentity:identity];
                if (numberOfMessages > 0) {
                    DDLogWarn(@"Hidden contact %@ can't be deleted because it still has %d messages", identity, numberOfMessages);
                    return;
                }
            }

            [[em entityDestroyer] deleteObjectWithObject:contact];

            [PushSettingManagerObjc deleteWithThreemaIdentity:contact.identity];

            doReflect = YES;
        }
    }];

    if (doReflect) {
        [self reflectDeleteContact:identity];
    }
}

- (void)linkContact:(ContactEntity *)contact toCnContactId:(NSString *)cnContactId {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
    [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts forceImport:YES onCompletion:^{
        [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                DDLogError(@"Contact multi device sync failed: %@", [error localizedDescription]);
            }
        }];
    }];
}

- (void)linkContact:(ContactEntity*)contact toCnContactId:(NSString *)cnContactId contactSyncer:(MediatorSyncableContacts *)mediatorSyncableContacts onCompletion:(void(^)(void))onCompletion {
    [self linkContact:contact toCnContactId:cnContactId contactSyncer:mediatorSyncableContacts forceImport:NO onCompletion:onCompletion];
}

- (void)linkContact:(ContactEntity*)contact toCnContactId:(NSString *)cnContactId contactSyncer:(MediatorSyncableContacts *)mediatorSyncableContacts forceImport:(BOOL)forceImport onCompletion:(void(^)(void))onCompletion {
    /* obtain first/last name from address book */
    [entityManager performSyncBlockAndSafe:^{
        contact.cnContactId = cnContactId;
        [self updateFromAddressBookWithContact:contact contactSyncer:mediatorSyncableContacts forceImport:forceImport onCompletion:onCompletion];
    }];
}

- (void)unlinkContact:(ContactEntity*)contact {
    __block MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

    [entityManager performSyncBlockAndSafe:^{
        contact.abRecordId = [NSNumber numberWithInt:0];
        contact.cnContactId = nil;
        if (contact.firstName) {
            contact.firstName = nil;
            [mediatorSyncableContacts updateFirstNameWithIdentity:contact.identity value:@""];
        }
        if (contact.lastName) {
            contact.lastName = nil;
            [mediatorSyncableContacts updateLastNameWithIdentity:contact.identity value:@""];
        }
        if (contact.imageData) {
            contact.imageData = nil;
            [mediatorSyncableContacts setProfileUpdateTypeWithIdentity:contact.identity value:MediatorSyncableContacts.deltaUpdateTypeRemoved];
        }
    }];
    
    [mediatorSyncableContacts syncAsync];
}

#pragma mark - Fetch contact

- (void)fetchPublicKeyForIdentity:(NSString*)identity acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError {
    [self fetchPublicKeyForIdentity:identity acquaintanceLevel:acquaintanceLevel entityManager:entityManager onCompletion:onCompletion onError:onError];
}

/**
 Fetch public key for identity, the completion handler will be executed in background thread.

 @param identity: Contact identity
 @param acquaintanceLevel: If contact new and acquaintance level is `ContactAcquaintanceLevelGroup`, than the created contact is marked as hidden
 @param entityManagerObject: Must be type of `EntityManager`, is needed to run DB on main or background context
 @param onCompletion: Executed on background thread
 @param onError: Executed on arbitrary thread
 */
- (void)fetchPublicKeyForIdentity:(NSString*)identity acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel entityManager:(NSObject*)entityManagerObject onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError {

    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Parameter entityManagerObject should be type of EntityManager");
    EntityManager *em = (EntityManager *)entityManagerObject;

    [em performBlock:^{
        // check in local DB first
        ContactEntity *contact = [em.entityFetcher contactForId:identity];
        if (contact.publicKey) {
            onCompletion(contact.publicKey);
        } else {
            
            if ([LicenseStore requiresLicenseKey]) {
                [self fetchWorkPublicKeyForIdentity:identity acquaintanceLevel:acquaintanceLevel entityManager:em onCompletion:onCompletion onError:onError];
            } else {
                // Block message if user is not in our subscription
                if (userSettings.blockUnknown) {
                    DDLogVerbose(@"Block unknown contacts is on - discarding message");
                    onError([ThreemaError threemaError:@"Message received from unknown contact and block contacts is on" withCode:ThreemaProtocolErrorBlockUnknownContact]);
                } else {
                    [self fetchAddContactAndSyncWithIdentity:identity acquaintanceLevel:acquaintanceLevel entityManager:em onCompletion:onCompletion onError:onError];
                }
            }
        }
    }];
}

/// Fetch public key for identity in the work subscription to know if this identity should be blocked or not.
/// If identity was not found and block unknown is disabled, contact will be fetched and added in fetchAddContactAndSyncWithIdentity.
/// The completion handler will be executed in background thread
/// @param identity Contact identity
/// @param acquaintanceLevel If contact new and acquaintance level is `ContactAcquaintanceLevelGroup`, than the created contact is marked as hidden
/// @param entityManagerObject Must be type of `EntityManager`, is needed to run DB on main or background context
/// @param onCompletion Executed on background thread
/// @param onError Executed on arbitrary thread
- (void)fetchWorkPublicKeyForIdentity:(nonnull NSString*)identity acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel entityManager:(nonnull NSObject*)entityManagerObject onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError {
    EntityManager *em = (EntityManager *)entityManagerObject;
    
    [self fetchWorkIdentities:@[identity] onCompletion:^(NSArray *foundIdentities) {
        // First, check in local DB again, as it may have already been saved in the meantime (in case of parallel requests)
        if ([em existingContactWith:identity]) {
            __block NSData *publicKey;
            [em performBlockAndWait:^{
                publicKey = [em.entityFetcher contactForId:identity].publicKey;
            }];
            
            if (publicKey != nil) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    onCompletion(publicKey);
                });
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (foundIdentities.count > 0) {
                for (NSDictionary *foundIdentity in foundIdentities) {
                    if ([foundIdentity[@"id"] isEqualToString:identity]) {
                        // Save new contact. Do it on main queue to ensure that it's done by the time we signal completion.
                        NSData *publicKey = [[NSData alloc] initWithBase64EncodedString:foundIdentity[@"pk"] options:0];
                        if (!publicKey) {
                            continue;
                        }
                        NSString *firstName = nil;
                        NSString *lastName = nil;
                        if (![foundIdentity[@"first"] isEqual:[NSNull null]]) {
                            firstName = foundIdentity[@"first"];
                        }
                        if (![foundIdentity[@"last"] isEqual:[NSNull null]]) {
                            lastName = foundIdentity[@"last"];
                        }
                        
                        [self addWorkContactAndUpdateFeatureMaskWithIdentity:identity publicKey:publicKey firstname:firstName lastname:lastName acquaintanceLevel:acquaintanceLevel onCompletion:^(ContactEntity * _Nonnull contactEntity) {
                            onCompletion(publicKey);
                        } onError:^(NSError * _Nonnull error) {
                            DDLogError(@"Add work contact failed: %@", error.localizedDescription);
                            onError(error);
                        }];
                        return;
                    }
                }
            }
            
            // Block message if user is not in our subscription
            if (userSettings.blockUnknown) {
                DDLogVerbose(@"Block unknown contacts is on and contact not found in work list - discarding message");
                onError([ThreemaError threemaError:@"Message received from unknown contact and block contacts is on" withCode:ThreemaProtocolErrorBlockUnknownContact]);
            } else {
                [self fetchAddContactAndSyncWithIdentity:identity acquaintanceLevel:acquaintanceLevel entityManager:em onCompletion:onCompletion onError:onError];
            }
        });
    } onError:^(NSError *error) {
        onError(error);
    }];
}

/// Fetch public key for identity and add it to the contactlist. The completion handler will be executed in background thread.
/// @param identity Contact identity
/// @param acquaintanceLevel If contact new and acquaintance level is `ContactAcquaintanceLevelGroup`, than the created contact is marked as hidden
/// @param entityManagerObject Must be type of `EntityManager`, is needed to run DB on main or background context
/// @param onCompletion Executed on background thread
/// @param onError Executed on arbitrary thread
- (void)fetchAddContactAndSyncWithIdentity:(nonnull NSString*)identity acquaintanceLevel:(ContactAcquaintanceLevel)acquaintanceLevel entityManager:(nonnull NSObject*)entityManagerObject onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError {
    
    EntityManager *em = (EntityManager *)entityManagerObject;
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

    [[IdentityInfoFetcher sharedIdentityInfoFetcher] fetchIdentityInfoFor:identity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
        // First, check in local DB again, as it may have already been saved in the meantime (in case of parallel requests)
        ContactEntity *contact = [em.entityFetcher contactForId:identity];
        if (contact.publicKey) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                onCompletion(contact.publicKey);
            });
            return;
        }
        
        // Save new contact. Do it on main queue to ensure that it's done by the time we signal completion.
        dispatch_async(dispatch_get_main_queue(), ^{
            __weak typeof(self) weakSelf = self;
            [self addContactWithIdentity:identity publicKey:publicKey cnContactId:nil verificationLevel:kVerificationLevelUnverified state:state type:type featureMask:featureMask acquaintanceLevel:acquaintanceLevel alerts:NO contactSyncer:mediatorSyncableContacts onCompletion:^(ContactEntity * __unused contact){
                [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
                    if (error == nil) {
                        [weakSelf synchronizeAddressBookForceFullSync:YES onCompletion:nil onError:nil];

                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            onCompletion(publicKey);
                        });
                    }
                    else {
                        onError(error);
                    }
                }];
            }];
        });
    } onError:^(NSError * _Nonnull error) {
        onError(error);
    }];
}

- (void)prefetchIdentityInfo:(NSSet*)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    NSMutableSet *identitiesToFetch = [NSMutableSet set];
    
    // Skip identities that we already have a contact for
    for (NSString *identity in identities) {
        ContactEntity *contact = [entityManager.entityFetcher contactForId:identity];
        if (!contact) {
            [identitiesToFetch addObject:identity];
        }
    }
    
    if ([identitiesToFetch count] == 0) {
        onCompletion();
        return;
    }
    
    [[IdentityInfoFetcher sharedIdentityInfoFetcher] prefetchIdentityInfo:identitiesToFetch onCompletion:onCompletion onError:onError];
}

- (void)fetchWorkIdentities:(NSArray *)identities onCompletion:(void(^)(NSArray *foundIdentities))onCompletion onError:(void(^)(NSError *error))onError {
    [[IdentityInfoFetcher sharedIdentityInfoFetcher] fetchWorkIdentitiesInfo:identities onCompletion:onCompletion onError:onError];
}

- (void)upgradeContact:(ContactEntity*)contact toVerificationLevel:(int32_t)verificationLevel {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

    [entityManager performSyncBlockAndSafe:^{
        if ((contact.verificationLevel.intValue < verificationLevel && contact.verificationLevel.intValue != kVerificationLevelFullyVerified) || verificationLevel == kVerificationLevelFullyVerified) {

            contact.verificationLevel = [NSNumber numberWithInt:verificationLevel];
            contact.isContactHidden = NO;
            [mediatorSyncableContacts updateVerificationLevelWithIdentity:contact.identity value:contact.verificationLevel];
            [mediatorSyncableContacts updateAcquaintanceLevelWithIdentity:contact.identity value:[NSNumber numberWithInteger:ContactAcquaintanceLevelDirect]];
        }
    }];

    [mediatorSyncableContacts syncAsync];
}

- (void)setWorkContact:(ContactEntity *)contact workContact:(BOOL)workContact {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

    [entityManager performSyncBlockAndSafe:^{
        contact.workContact = [NSNumber numberWithBool:workContact];
        [mediatorSyncableContacts updateWorkVerificationLevelWithIdentity:contact.identity value:contact.workContact];

        if (!workContact && contact.verificationLevel.intValue != kVerificationLevelFullyVerified) {
            contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelUnverified];
            [mediatorSyncableContacts updateVerificationLevelWithIdentity:contact.identity value:contact.verificationLevel];
        }
    }];
    
    [mediatorSyncableContacts syncAsync];
}

- (void)addAsWorkWithIdentities:(NSOrderedSet *)identities contactSyncer:(nullable MediatorSyncableContacts *)mediatorSyncableContacts {
    BOOL hasChanged = NO;
    NSMutableOrderedSet *currentWorkIdentities = [[NSMutableOrderedSet alloc] initWithOrderedSet:[userSettings workIdentities]];
    for (NSString *identity in identities) {
        if (![currentWorkIdentities containsObject:identity]) {
            [currentWorkIdentities addObject:identity];
            [mediatorSyncableContacts updateIdentityTypeWithIdentity:identity value:@YES];
            hasChanged = YES;
        }
    }
    if (hasChanged) {
        userSettings.workIdentities = currentWorkIdentities;
    }
}

#pragma mark - Nickname

/**
 Update nickname if is necessary.

 @param identity: Identity of contact to change nickname
 @param nickname: Nickname to update
 */
- (void)updateNickname:(nonnull NSString *)identity nickname:(NSString *)nickname {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

    [entityManager performSyncBlockAndSafe:^{
        ContactEntity *contact = [entityManager.entityFetcher contactForId:identity];

        if (contact) {
            BOOL hasChanged = NO;

            if (nickname && nickname.length > 0 && ![contact.publicNickname isEqualToString:nickname]) {
                if ([nickname isEqualToString:identity]) {
                    DDLogNotice(@"[Nickname] Set new nickname (ID) for %@", identity);
                }
                else {
                    DDLogNotice(@"[Nickname] Set new nickname for %@", identity);
                }
                contact.publicNickname = nickname;
                hasChanged = YES;
            }
            else if (nickname == nil && ![contact.publicNickname isEqualToString:contact.identity]) {
                DDLogNotice(@"[Nickname] Set ID as nickname for %@", identity);
                contact.publicNickname = contact.identity;
                hasChanged = YES;
            }

            if (hasChanged) {
                [mediatorSyncableContacts updateNicknameWithIdentity:contact.identity value:contact.publicNickname];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshContactSortIndices object:nil];
            }
        }
    }];

    if ([[UserSettings sharedUserSettings] enableMultiDevice]) {
        [mediatorSyncableContacts syncAsync];
    }
}

#pragma mark - Profile Picture

- (void)updateProfilePicture:(nullable NSString *)identity imageData:(NSData *)imageData shouldReflect:(BOOL)shouldReflect blobID:(nullable NSData *)blobID encryptionKey:(nullable NSData *)encryptionKey didFailWithError:(NSError * _Nullable __autoreleasing * _Nullable)error {
    UIImage *image = [UIImage imageWithData:imageData];
    if (image == nil) {
        *error = [ThreemaError threemaError:@"Image decoding failed"];
        return;
    }

    __block ContactEntity *contact;

    [entityManager performSyncBlockAndSafe:^{
        contact = [entityManager.entityFetcher contactForId:identity];
        if (contact) {
            ImageData *dbImage = [entityManager.entityCreator imageData];
            dbImage.data = imageData;
            dbImage.width = [NSNumber numberWithInt:image.size.width];
            dbImage.height = [NSNumber numberWithInt:image.size.height];

            contact.contactImage = dbImage;
        }
    }];

    if (!contact) {
        *error = [ThreemaError threemaError:@"Contact not found"];
        return;
    }

    [self removeProfilePictureRequest:identity];
    
    if ([[UserSettings sharedUserSettings] enableMultiDevice] && shouldReflect) {
        MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
        [mediatorSyncableContacts setContactProfileUpdateTypeWithIdentity:identity value:MediatorSyncableContacts.deltaUpdateTypeUpdated blobID:blobID encryptionKey:encryptionKey];
        [mediatorSyncableContacts syncAsync];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationIdentityAvatarChanged object:identity];
}

- (void)deleteProfilePicture:(nullable NSString *)identity shouldReflect:(BOOL)shouldReflect {
    __block ContactEntity *contact;

    [entityManager performSyncBlockAndSafe:^{
        contact = [entityManager.entityFetcher contactForId:identity];
        if (contact) {
            contact.contactImage = nil;
        }
    }];

    if (!contact) {
        return;
    }

    [self removeProfilePictureRequest:identity];
    
    if ([[UserSettings sharedUserSettings] enableMultiDevice] && shouldReflect) {
        MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
        [mediatorSyncableContacts setContactProfileUpdateTypeWithIdentity:identity value:MediatorSyncableContacts.deltaUpdateTypeRemoved blobID:nil encryptionKey:nil];
        [mediatorSyncableContacts syncAsync];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationIdentityAvatarChanged object:identity];
}

- (void)removeProfilePictureFlagForAllContacts {
    [entityManager performAsyncBlockAndSafe:^{
        NSArray *allContacts = [entityManager.entityFetcher allContacts];
        
        if (allContacts != nil) {
            for (ContactEntity *contact in allContacts) {
                contact.profilePictureSended = NO;
                contact.profilePictureBlobID = nil;
            }
        }
    }];
}

- (void)removeProfilePictureFlagForIdentity:(NSString *)identity {
    [entityManager performSyncBlockAndSafe:^{
        ContactEntity *contact = [entityManager.entityFetcher contactForId:identity];
        if (contact) {
            contact.profilePictureSended = NO;
        }
    }];
}

- (BOOL)existsProfilePictureRequestForIdentity:(NSString *)identity {
    @synchronized (self) {
        return [[userSettings profilePictureRequestList] containsObject:identity];
    }
}

- (void)removeProfilePictureRequest:(NSString *)identity {
    @synchronized (self) {
        if ([self existsProfilePictureRequestForIdentity:identity]) {
            NSMutableSet *profilePictureRequestList = [NSMutableSet setWithArray:userSettings.profilePictureRequestList];
            [profilePictureRequestList removeObject:identity];
            userSettings.profilePictureRequestList = profilePictureRequestList.allObjects;
        }
    }
}

- (void)addProfilePictureRequest:(NSString *)identity {
    @synchronized (self) {
        if (![self existsProfilePictureRequestForIdentity:identity]) {
            NSMutableSet *profilePictureRequestList = [NSMutableSet setWithArray:userSettings.profilePictureRequestList];
            [profilePictureRequestList addObject:identity];
            userSettings.profilePictureRequestList = profilePictureRequestList.allObjects;
        }
    }
}

#pragma mark - Sync Address Book

- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError {
    [self synchronizeAddressBookForceFullSync:forceFullSync ignoreMinimumInterval:NO onCompletion:onCompletion onError:onError];
}

- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync ignoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError {
    if (ProcessInfoHelper.isRunningForScreenshots)  {
        return;
    }

    if (userSettings.blockCommunication) {
        DDLogInfo(@"Communication is blocked");
        return;
    }
    
    /* Get all entries from the user's address book, hash the e-mail addresses
     and phone numbers and send to the server. */
    if (!userSettings.syncContacts) {
        DDLogInfo(@"Contact sync is disabled");
        [self processStatusUpdateOnlyWithIgnoreMinimumInterval:ignoreMinimumInterval onCompletion:onCompletion onError:onError];
        return;
    }

    CNContactStore *cnAddressBook = [CNContactStore new];
    if (cnAddressBook == nil) {
        DDLogInfo(@"Address book not found");
        [self processStatusUpdateOnlyWithIgnoreMinimumInterval:ignoreMinimumInterval onCompletion:onCompletion onError:onError];
        return;
    }

    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized) {
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                [self synchronizeAddressBookForceFullSync:forceFullSync onCompletion:onCompletion onError:onError];
            } else {
                DDLogInfo(@"Address book access has NOT been granted: %@", error);
                [self processStatusUpdateOnlyWithIgnoreMinimumInterval:ignoreMinimumInterval onCompletion:onCompletion onError:onError];
            }
        }];
        return;
    }

    dispatch_async(syncQueue, ^{
        NSUserDefaults *defaults = [AppGroup userDefaults];
        NSDate *lastServerCheck = [defaults objectForKey:@"ContactsSyncLastCheck"];
        NSInteger lastServerCheckInterval = [defaults integerForKey:@"ContactsSyncLastCheckInterval"];
        BOOL fullServerSync = YES;
        
        /* calculate earliest date for next server check */
        if (lastServerCheck != nil) {
            if (-[lastServerCheck timeIntervalSinceNow] < lastServerCheckInterval) {
                DDLogInfo(@"Last server contacts sync less than %ld seconds ago", (long)lastServerCheckInterval);
                if (forceFullSync) {
                    DDLogInfo(@"Forcing full sync");
                } else {
                    fullServerSync = NO;
                }
            }
        }
        
        /* check if we are within the minimum interval */
        if (fullServerSync) {
            if (!ignoreMinimumInterval && lastFullSyncDate != nil && -[lastFullSyncDate timeIntervalSinceNow] < minimumSyncInterval) {
                DDLogInfo(@"Still within minimum interval - not syncing");
                if (onCompletion != nil)
                    dispatch_async(dispatch_get_main_queue(), ^{
                        onCompletion(YES);
                    });
                return;
            }
        }
        
        DDLogNotice(@"[ContactSync] Build all e-mail and phone number hashes");
        /* extract all e-mail and phone number hashes from the user's address book */
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                NSError *error;
                NSMutableArray *allCNContacts = [NSMutableArray new];
                
                NSArray *containers = [cnAddressBook containersMatchingPredicate:nil error:&error];
                for (CNContainer *container in containers) {
                    NSPredicate *predicate = [CNContact predicateForContactsInContainerWithIdentifier:container.identifier];
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                    if (cnContacts != nil) {
                        [allCNContacts addObjectsFromArray:cnContacts];
                    }
                }
                
                [self processAddressBookContacts:allCNContacts fullServerSync:fullServerSync ignoreMinimumInterval:ignoreMinimumInterval onCompletion:onCompletion onError:onError];
            }
        }];
    });
}

/**
 Process status request/update to all contacts.

 @param ignoreMinimumInterval: True contact status request/update will be called anyway
 @param onCompletion: Completion handler
 @param onError: Error handler
 */
- (void)processStatusUpdateOnlyWithIgnoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError * _Nonnull))onError {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^{
        MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
        [self updateStatusForAllContactsIgnoreInterval:ignoreMinimumInterval contactSyncer:mediatorSyncableContacts onCompletion:^{
            [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
                if (error == nil) {
                    if (onCompletion != nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            onCompletion(NO);
                        });
                    }
                }
                else {
                    DDLogError(@"[ContactSync] Contact multi device sync failed: %@", [error localizedDescription]);
                    if (onError != nil) {
                        onError(error);
                    }
                }
            }];
        }];
    });
}

/**
 Process address book contacts and status request/update to all contacts.

 @param contacts: Address book contacts to add or update as Threema contact
 @param fullServerSync: True sync all address book contacts otherwise just the new ones
 @param ignoreMinimumInterval: True contact status request/update will be called anyway
 @param onCompletion: Completion handler
 @param onError: Error handler
 */
- (void)processAddressBookContacts:(NSArray*)contacts fullServerSync:(BOOL)fullServerSync ignoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError {
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    
    NSSet *emailLastCheck = [NSSet setWithArray:[defaults objectForKey:@"ContactsSyncLastEmailHashes"]];
    NSSet *mobileNoLastCheck = [NSSet setWithArray:[defaults objectForKey:@"ContactsSyncLastMobileNoHashes"]];
    
    PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
    NSString *countryCode = [PhoneNumberNormalizer userRegion];
    DDLogInfo(@"Current country code: %@", countryCode);
    
    NSMutableSet *emailHashesBase64 = [NSMutableSet set];
    NSMutableSet *mobileNoHashesBase64 = [NSMutableSet set];
    
    NSMutableDictionary *emailHashToCnContactId = [NSMutableDictionary dictionary];
    NSMutableDictionary *mobileNoHashToCnContactId = [NSMutableDictionary dictionary];
    
    for (CNContact *person in contacts) {
        NSString *cnContactId = person.identifier;
        NSString *name = [CNContactFormatter stringFromContact:person style:CNContactFormatterStyleFullName];
        
        for (CNLabeledValue *label in person.emailAddresses) {
            NSString *email = label.value;
            if (email.length > 0) {
                NSString *emailNormalized = [[email lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *emailHashBase64 = [self hashEmailBase64:emailNormalized];
                [emailHashToCnContactId setObject:cnContactId forKey:emailHashBase64];
                [emailHashesBase64 addObject:emailHashBase64];
                
                /* Gmail address? If so, hash with the other domain as well */
                NSString *emailNormalizedAlt = nil;
                if ([emailNormalized hasSuffix:@"@gmail.com"])
                    emailNormalizedAlt = [emailNormalized stringByReplacingOccurrencesOfString:@"@gmail.com" withString:@"@googlemail.com"];
                else if ([emailNormalized hasSuffix:@"@googlemail.com"])
                    emailNormalizedAlt = [emailNormalized stringByReplacingOccurrencesOfString:@"@googlemail.com" withString:@"@gmail.com"];
                
                if (emailNormalizedAlt != nil) {
                    NSString *emailHashAltBase64 = [self hashEmailBase64:emailNormalizedAlt];
                    [emailHashToCnContactId setObject:cnContactId forKey:emailHashAltBase64];
                    [emailHashesBase64 addObject:emailHashAltBase64];
                }
                
                DDLogVerbose(@"%@ (%@): %@", name, cnContactId, emailNormalized);
            }
        }
        
        for (CNLabeledValue *label in person.phoneNumbers) {
            NSString *phone = [label.value stringValue];
            if (phone.length > 0) {
                /* normalize phone number first */
                NSString *mobileNoNormalized = [normalizer phoneNumberToE164:phone withDefaultRegion:countryCode prettyFormat:nil];
                if (mobileNoNormalized == nil)
                    continue;
                NSString *mobileNoHashBase64 = [self hashMobileNoBase64:mobileNoNormalized];
                [mobileNoHashToCnContactId setObject:cnContactId forKey:mobileNoHashBase64];
                [mobileNoHashesBase64 addObject:mobileNoHashBase64];
                DDLogVerbose(@"%@ (%@): %@", name, cnContactId, mobileNoNormalized);
            }
        }
    }
    
    if (!fullServerSync) {
        /* a full server sync is not scheduled right now, so remove any hashes that we checked last time from the list */
        for (NSString *emailHash in emailLastCheck) {
            [emailHashesBase64 removeObject:emailHash];
        }
        for (NSString *mobileNoHash in mobileNoLastCheck) {
            [mobileNoHashesBase64 removeObject:mobileNoHash];
        }
    }
    
    if (emailHashesBase64.count == 0 && mobileNoHashesBase64.count == 0) {
        DDLogInfo(@"No new contacts to synchronize");
        if (onCompletion != nil)
            dispatch_async(dispatch_get_main_queue(), ^{
                onCompletion(YES);
            });
        return;
    }
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"ContactSync: Start request %lu emails, %lu phonenumbers", (unsigned long)emailHashesBase64.count, (unsigned long)mobileNoHashesBase64.count]];
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn matchIdentitiesWithEmailHashes:[emailHashesBase64 allObjects] mobileNoHashes:[mobileNoHashesBase64 allObjects] includeInactive:NO onCompletion:^(NSArray *identities, int checkInterval) {
        
        if (fullServerSync) {
            [defaults setObject:[emailHashesBase64 allObjects] forKey:@"ContactsSyncLastEmailHashes"];
            [defaults setObject:[mobileNoHashesBase64 allObjects] forKey:@"ContactsSyncLastMobileNoHashes"];
            [defaults setObject:[NSDate date] forKey:@"ContactsSyncLastCheck"];
        } else {
            /* add the hashes we just checked to the full list */
            NSMutableArray *prevEmailHashes = [NSMutableArray arrayWithArray:[defaults objectForKey:@"ContactsSyncLastEmailHashes"]];
            NSMutableArray *prevMobileNoHashes = [NSMutableArray arrayWithArray:[defaults objectForKey:@"ContactsSyncLastMobileNoHashes"]];
            [prevEmailHashes addObjectsFromArray:[emailHashesBase64 allObjects]];
            [prevMobileNoHashes addObjectsFromArray:[mobileNoHashesBase64 allObjects]];
            [defaults setObject:prevEmailHashes forKey:@"ContactsSyncLastEmailHashes"];
            [defaults setObject:prevMobileNoHashes forKey:@"ContactsSyncLastMobileNoHashes"];
        }
        [defaults setInteger:checkInterval forKey:@"ContactsSyncLastCheckInterval"];
        [defaults synchronize];

        DDLogNotice(@"[ContactSync] Start Core Data stuff");

        MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
        [self addContactsWithIdentities:identities emailHashes:emailHashToCnContactId mobileNoHashes:mobileNoHashToCnContactId contactSyncer:mediatorSyncableContacts onCompletion:^{
            // trigger updating of status for identities
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^{
                DDLogNotice(@"[ContactSync] Update status and featuremask for all contacts");
                [self updateStatusForAllContactsIgnoreInterval:ignoreMinimumInterval contactSyncer:mediatorSyncableContacts onCompletion:^{
                    if (fullServerSync && ignoreMinimumInterval && mediatorSyncableContacts) {
                        // Sync all contacts when server full sync was called
                        EntityManager *backgroundEntityManager = [[EntityManager alloc] initWithChildContextForBackgroundProcess:YES];
                        [backgroundEntityManager performBlockAndWait:^{
                            NSArray *allContacts = [backgroundEntityManager.entityFetcher allContacts];
                            for (ContactEntity *contact in allContacts) {
                                [mediatorSyncableContacts updateAllWithIdentity:contact.identity added:NO];
                            }
                        }];
                    }

                    [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
                        if (error == nil) {
                            if (fullServerSync) {
                                lastFullSyncDate = [NSDate date];
                            }

                            DDLogNotice(@"[ContactSync] Address book sync finished");
                            if (onCompletion != nil) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    onCompletion(YES);
                                });
                            }
                        }
                        else {
                            DDLogError(@"[ContactSync] Contact multi device sync failed: %@", [error localizedDescription]);
                            if (onCompletion) onCompletion(YES);
                        }
                    }];
                }];
            });
        }];
    } onError:^(NSError *error) {
        DDLogError(@"[ContactSync] Synchronize address book failed: %@", error);
        if (onError != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onError(error);
            });
        }
    }];
}

- (void)linkedIdentitiesForEmail:(NSString *)email AndMobileNo:(NSString *)mobileNo onCompletion:(void(^)(NSArray *identities))onCompletion {
    
    NSArray<NSString *> *emailHashesBase64 = [NSArray array];
    NSArray<NSString *> *mobileNoHashesBase64 = [NSArray array];
    
    if (email.length > 0) {
        NSString *emailNormalized = [[email lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *emailHashBase64 = [self hashEmailBase64:emailNormalized];
        emailHashesBase64 = @[emailHashBase64];
    }
    
    if (mobileNo.length > 0) {
        /* normalize phone number first */
        PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
        NSString *countryCode = [PhoneNumberNormalizer userRegion];
        NSString *mobileNoNormalized = [normalizer phoneNumberToE164:mobileNo withDefaultRegion:countryCode prettyFormat:nil];
        if (mobileNoNormalized != nil) {
            NSString *mobileNoHashBase64 = [self hashMobileNoBase64:mobileNoNormalized];
            
            mobileNoHashesBase64 = @[mobileNoHashBase64];
        }
    }
    
    if (emailHashesBase64.count > 0 || mobileNoHashesBase64.count > 0) {
        ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
        [conn matchIdentitiesWithEmailHashes:emailHashesBase64 mobileNoHashes:mobileNoHashesBase64 includeInactive:YES onCompletion:^(NSArray *identities, int checkInterval) {
            if (identities == nil) {
                NSArray *emptyArray = [NSArray array];
                onCompletion(emptyArray);
            } else {
                onCompletion(identities);
            }
        } onError:^(NSError *error) {
            DDLogError(@"Linked identities failed: %@", error);
            NSArray *emptyArray = [NSArray array];
            onCompletion(emptyArray);
        }];
    } else {
        NSArray *emptyArray = [NSArray array];
        onCompletion(emptyArray);
    }
}

- (NSArray *)allIdentities {
    NSFetchRequest *fetchRequest = [entityManager.entityFetcher fetchRequestForEntity:@"Contact"];
    fetchRequest.propertiesToFetch = @[@"identity"];
    
    NSArray *result = [entityManager.entityFetcher executeFetchRequest:fetchRequest];
    if (result != nil) {
        return [self identitiesForContacts:result];
    } else {
        DDLogError(@"Cannot get identities");
        return nil;
    }
}

- (NSArray<NSString *> *)contactsWithFeatureMaskNil {
    __block NSArray<NSString *> *identities;
    [entityManager performBlockAndWait:^{
        identities = [self identitiesForContacts:[entityManager.entityFetcher contactsWithFeatureMaskNil]];
    }];
    return identities;
}

- (NSArray *)allContacts {
    return [entityManager.entityFetcher allContacts];
}

- (void)orderChanged:(NSNotification*)notification {
    [entityManager performAsyncBlockAndSafe:^{
        /* update display name and sort index of all contacts */
        NSArray *allContacts = [entityManager.entityFetcher allContacts];
        
        if (allContacts != nil) {
            for (ContactEntity *contact in allContacts) {
                /* set last name again to trigger update of display name and sort index */
                contact.lastName = contact.lastName;
            }
        }
    }];
}

- (NSArray<NSString *> *)identitiesForContacts:(NSArray<ContactEntity *> *)contacts {
    NSMutableArray *identities = [NSMutableArray arrayWithCapacity:contacts.count];
    for (ContactEntity *contact in contacts) {
        [identities addObject:contact.identity];
    }
    return identities;
}

- (NSArray *)validIdentities {
    NSMutableArray *identities = [[NSMutableArray alloc] init];
    
    EntityManager *privateEntityManager = [[EntityManager alloc] initWithChildContextForBackgroundProcess:YES];
    [privateEntityManager performBlockAndWait:^{
        NSArray *contacts = [privateEntityManager.entityFetcher allContacts];
        
        for (ContactEntity *contact in contacts) {
            if (contact.state.intValue != kStateInvalid) {
                [identities addObject:contact.identity];
            }
        }
    }];
    
    return identities;
}

- (void)updateFeatureMasksForContacts:(NSArray *)contacts contactSyncer:(MediatorSyncableContacts * _Nullable)mediatorSyncableContacts onCompletion:(nonnull void(^)(void))onCompletion onError:(nonnull void(^)(NSError *error))onError {
    NSArray *identities = [self identitiesForContacts: contacts];
    [self updateFeatureMasksForIdentities:identities contactSyncer:mediatorSyncableContacts onCompletion:onCompletion onError:onError];
}

- (void)updateFeatureMasksForIdentities:(NSArray<NSString *> *)identities onCompletion:(nonnull void(^)(void))onCompletion onError:(nonnull void(^)(NSError *error))onError {
    MediatorSyncableContacts *mediatorSyncableContacts = [MediatorSyncableContacts new];
    [self updateFeatureMasksForIdentities:identities contactSyncer:mediatorSyncableContacts onCompletion:^{
        [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
            if (error == nil) {
                onCompletion();
            }
            else {
                DDLogError(@"Contact multi device sync failed: %@", [error localizedDescription]);
                onError(error);
            }
        }];
    } onError:onError];
}

- (void)updateFeatureMasksForIdentities:(nonnull NSArray *)identities contactSyncer:(MediatorSyncableContacts * _Nullable)mediatorSyncableContacts onCompletion:(nonnull void(^)(void))onCompletion onError:(nonnull void(^)(NSError * error))onError {
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn getFeatureMasksForIdentities:identities onCompletion:^(NSArray *featureMasks) {
        [entityManager performSyncBlockAndSafe:^{
            for (NSInteger i=0; i<[identities count]; i++) {
                NSNumber *featureMask = [featureMasks objectAtIndex: i];

                if (featureMask.integerValue >= 0) {
                    NSString *identityString = [identities objectAtIndex:i];
                    ContactEntity *contact = [entityManager.entityFetcher contactForId: identityString];
                    if (![contact.featureMask isEqualToNumber:featureMask]) {
                        contact.featureMask = featureMask;
                        [mediatorSyncableContacts updateFeatureMaskWithIdentity:contact.identity value:contact.featureMask];
                    }
                }
            }
        }];

        onCompletion();
    } onError:onError];
}

- (BOOL)needCheckStatus:(BOOL)ignoreInterval {
    if (ignoreInterval) {
        return YES;
    }
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSDate *dateLastCheck = [defaults objectForKey:@"DateLastCheckStatus"];
    if (dateLastCheck == nil) {
        return true;
    }
    
    NSInteger checkInterval = [self getCheckStatusInterval];
    NSDate *dateOfNextCheck = [dateLastCheck dateByAddingTimeInterval:checkInterval];
    NSDate *now = [NSDate date];
    return [now timeIntervalSinceDate:dateOfNextCheck] > 0;
}

- (void)setupCheckStatusTimer {
    NSUserDefaults *defaults = [AppGroup userDefaults];
    
    NSDate *now = [NSDate date];
    [defaults setObject:now forKey:@"DateLastCheckStatus"];
    [defaults synchronize];
    
    NSInteger checkInterval = [self getCheckStatusInterval];
    checkStatusTimer = [NSTimer scheduledTimerWithTimeInterval:checkInterval target:self selector:@selector(updateStatusForAllContacts) userInfo:nil repeats:NO];
}

- (NSInteger) getCheckStatusInterval {
    NSUserDefaults *defaults = [AppGroup userDefaults];
    NSInteger checkInterval = [defaults integerForKey:@"CheckStatusInterval"];

    return MAX(checkInterval, MIN_CHECK_INTERVAL);
}

- (void)updateStatusForAllContacts {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
    [self updateStatusForAllContactsIgnoreInterval:NO contactSyncer:mediatorSyncableContacts onCompletion:^{
        [mediatorSyncableContacts syncObjcWithCompletionHandler:^(NSError * _Nullable error) {
            if (error) {
                DDLogError(@"Contact multi device sync failed: %@", [error localizedDescription]);
            }
        }];
    }];
}

- (void)updateStatusForAllContactsIgnoreInterval:(BOOL)ignoreInterval contactSyncer:(MediatorSyncableContacts *)mediatorSyncableContacts onCompletion:(void(^)(void))onCompletion {
    if (ProcessInfoHelper.isRunningForScreenshots)  {
        [self updateStatusWithContactSyncer:mediatorSyncableContacts onCompletion:^() {
            [self setupCheckStatusTimer];
        } onError:^(){
            [self setupCheckStatusTimer];
        }];
    } else {
        if ([self needCheckStatus:ignoreInterval] == NO) {
            DDLogNotice(@"[ContactSync] Do not update status and featuremasks");
            if (onCompletion) onCompletion();
            return;
        }
        
        [self updateStatusWithContactSyncer:mediatorSyncableContacts onCompletion:^() {
            [self setupCheckStatusTimer];
            if (onCompletion) onCompletion();
            DDLogNotice(@"[ContactSync] Update status and featuremasks finished");
        } onError:^(){
            DDLogNotice(@"[ContactSync] Update status featuremasks finished with error");
            [self setupCheckStatusTimer];
            if (onCompletion) onCompletion();
        }];
    }
}

- (void)updateStatusWithContactSyncer:(MediatorSyncableContacts *)mediatorSyncableContacts onCompletion:(void(^)(void))onCompletion onError:(void(^)(void))onError  {
    NSArray *identities = [self validIdentities];
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn checkStatusOfIdentities:identities onCompletion:^(NSArray *states, NSArray *types, NSArray *featureMasks, int checkInterval) {
        [entityManager performSyncBlockAndSafe:^{
            NSMutableOrderedSet *workIdentities = [NSMutableOrderedSet new];
            for (NSInteger i=0; i<[identities count]; i++) {
                NSNumber *state = [states objectAtIndex: i];
                NSNumber *type = [types objectAtIndex:i];
                NSNumber *featureMask = [featureMasks objectAtIndex:i];
                
                NSString *identityString = [identities objectAtIndex:i];
                ContactEntity *contact = [entityManager.entityFetcher contactForId: identityString];
                if (![contact.state isEqualToNumber:state]) {
                    contact.state = state;
                    [mediatorSyncableContacts updateStateWithIdentity:contact.identity value:contact.state];
                }
                
                if ([type isEqualToNumber:@1]) {
                    [workIdentities addObject:contact.identity];
                }
                
                if (![featureMask isEqual:[NSNull null]]) {
                    if (![contact.featureMask isEqualToNumber:featureMask]) {
                        contact.featureMask = featureMask;
                        [mediatorSyncableContacts updateFeatureMaskWithIdentity:contact.identity value:contact.featureMask];
                    }
                }
            }
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
                [self addAsWorkWithIdentities:workIdentities contactSyncer:mediatorSyncableContacts];
            }
        }];
        
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults setInteger:checkInterval forKey:@"CheckStatusInterval"];
        [defaults synchronize];
        
        onCompletion();
    } onError:^(NSError *error) {
        DDLogError(@"Status update failed: %@", error);
        onError();
    }];
}

- (void)updateAllContactsToCNContact {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    NSUserDefaults *defaults = [AppGroup userDefaults];
    if ([defaults boolForKey:@"AlreadyUpdatedToCNContacts"]) {
        return;
    }
    
    __block NSArray *linkedContacts;
    [entityManager performBlockAndWait:^{
        linkedContacts = [[entityManager.entityFetcher allContacts] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            ContactEntity *contact = (ContactEntity *)evaluatedObject;
            return contact.abRecordId != nil && contact.abRecordId.intValue != 0;
        }]];
    }];
    if (linkedContacts == nil || linkedContacts.count == 0) {
        NSUserDefaults *defaults = [AppGroup userDefaults];
        [defaults setBool:YES forKey:@"AlreadyUpdatedToCNContacts"];
        [defaults synchronize];
        
        return;
    }
    
    CNContactStore *cnAddressBook = [CNContactStore new];
    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted == YES) {
            ABAddressBookRef addressBook = nil;
            
            int nupdated = 0;
            for (ContactEntity *contact in linkedContacts) {
                
                if (addressBook == nil) {
                    addressBook = ABAddressBookCreate();
                    if (addressBook == nil)
                        return;
                }
                
                ABRecordRef abPerson = ABAddressBookGetPersonWithRecordID(addressBook, contact.abRecordId.intValue);
                if (abPerson != nil) {
                    NSString *firstName = CFBridgingRelease(ABRecordCopyValue(abPerson, kABPersonFirstNameProperty));
                    NSString *lastName = CFBridgingRelease(ABRecordCopyValue(abPerson, kABPersonLastNameProperty));
                    NSString *middleName = CFBridgingRelease(ABRecordCopyValue(abPerson, kABPersonMiddleNameProperty));
                    NSString *company = CFBridgingRelease(ABRecordCopyValue(abPerson, kABPersonOrganizationProperty));
                    NSString *fullName = [NSString stringWithFormat:@"%@ %@ %@", firstName, middleName, lastName];
                    
                    ABMutableMultiValueRef multiPhone = ABRecordCopyValue(abPerson, kABPersonPhoneProperty);
                    NSMutableArray *personPhones = [NSMutableArray new];
                    if (ABMultiValueGetCount(multiPhone) > 0) {
                        
                        for (CFIndex i = 0; i < ABMultiValueGetCount(multiPhone); i++) {
                            CFStringRef phoneRef = ABMultiValueCopyValueAtIndex(multiPhone, i);
                            [personPhones addObject:(__bridge NSString *)phoneRef];
                            CFRelease(phoneRef);
                        }
                    }
                    CFRelease(multiPhone);
                    
                    ABMutableMultiValueRef multiEmail = ABRecordCopyValue(abPerson, kABPersonEmailProperty);
                    NSMutableArray *personEmails = [NSMutableArray new];
                    if (ABMultiValueGetCount(multiEmail) > 0) {
                        
                        for (CFIndex i = 0; i < ABMultiValueGetCount(multiEmail); i++) {
                            CFStringRef emailRef = ABMultiValueCopyValueAtIndex(multiEmail, i);
                            [personEmails addObject:(__bridge NSString *)emailRef];
                            CFRelease(emailRef);
                        }
                    }
                    CFRelease(multiEmail);
                    
                    // Check is there a CNContact for the ABPerson
                    NSPredicate *predicate = [CNContact predicateForContactsMatchingName:fullName];
                    NSError *error;
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                    if (error) {
                        NSLog(@"error fetching contacts %@", error);
                    } else {
                        if (cnContacts.count == 1) {
                            NSLog(@"Found the CNContact for ABPerson; Identifier: %@", [((CNContact *)cnContacts.firstObject) identifier]);
                            [entityManager performSyncBlockAndSafe:^{
                                contact.cnContactId = [((CNContact *)cnContacts.firstObject) identifier];
                            }];
                        }
                        else if (cnContacts.count > 1) {
                            // Find correct contact in array
                            NSMutableArray *phoneEmailMatch = [NSMutableArray new];
                            NSMutableArray *phoneMatch = [NSMutableArray new];
                            NSMutableArray *emailMatch = [NSMutableArray new];
                            
                            for (CNContact *contact in cnContacts) {
                                if ([company isEqualToString:contact.organizationName]) {
                                    // compare ABPerson numbers with CNContact numbers
                                    BOOL foundPhone = NO;
                                    for (NSString *abPhone in personPhones) {
                                        for (CNLabeledValue *label in contact.phoneNumbers) {
                                            NSString *phoneNumber = [label.value stringValue];
                                            if (phoneNumber.length > 0) {
                                                if ([phoneNumber isEqualToString:abPhone]) {
                                                    foundPhone = YES;
                                                } else {
                                                    foundPhone = NO;
                                                }
                                            }
                                        }
                                    }
                                    
                                    // compare ABPerson emails with CNContact emails
                                    BOOL foundEmail = NO;
                                    for (NSString *abEmail in personEmails) {
                                        for (CNLabeledValue *label in contact.emailAddresses) {
                                            NSString *email = label.value;
                                            if (email.length > 0) {
                                                if ([email isEqualToString:abEmail]) {
                                                    foundEmail = YES;
                                                } else {
                                                    foundEmail = NO;
                                                }
                                            }
                                        }
                                    }
                                    
                                    if (foundEmail && foundPhone) {
                                        [phoneEmailMatch addObject:contact];
                                    } else {
                                        if (foundEmail) {
                                            [emailMatch addObject:contact];
                                        }
                                        if (foundPhone) {
                                            [phoneMatch addObject:contact];
                                        }
                                    }
                                }
                            }
                            
                            // compare is only one contact with mail and phone match
                            if (phoneEmailMatch.count == 1) {
                                [entityManager performSyncBlockAndSafe:^{
                                    NSLog(@"Found phone and email of the CNContact for ABPerson; Identifier: %@", [((CNContact *)phoneEmailMatch.firstObject) identifier]);
                                    contact.cnContactId = [((CNContact *)phoneEmailMatch.firstObject) identifier];
                                }];
                            }
                            else if (phoneMatch.count == 1 && emailMatch.count == 0) {
                                [entityManager performSyncBlockAndSafe:^{
                                    NSLog(@"Found phone of the CNContact for ABPerson; Identifier: %@", [((CNContact *)phoneMatch.firstObject) identifier]);
                                    contact.cnContactId = [((CNContact *)phoneMatch.firstObject) identifier];
                                }];
                            }
                            else if (emailMatch.count == 1 && phoneMatch.count == 0) {
                                [entityManager performSyncBlockAndSafe:^{
                                    NSLog(@"Found email of the CNContact for ABPerson; Identifier: %@", [((CNContact *)emailMatch.firstObject) identifier]);
                                    contact.cnContactId = [((CNContact *)emailMatch.firstObject) identifier];
                                }];
                            } else {
                                NSLog(@"Found %lu contacts that could match", phoneEmailMatch.count + phoneMatch.count + emailMatch.count);
                            }
                        }
                        else {
                            NSLog(@"Found no CNContact for ABPerson");
                            // skip
                        }
                    }
                    nupdated++;
                }
            }
            
            if (addressBook != nil)
                CFRelease(addressBook);
            
            DDLogInfo(@"Updated %d contacts to CNContact", nupdated);
            
            NSUserDefaults *defaults = [AppGroup userDefaults];
            [defaults setBool:YES forKey:@"AlreadyUpdatedToCNContacts"];
            [defaults synchronize];
        }
    }];
#pragma clang diagnostic pop
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)cnContactEmailsForContact:(ContactEntity *)contact {
    if (contact.cnContactId == nil)
        return nil;
    
    __block NSArray *cnContacts;
    CNContactStore *cnAddressBook = [CNContactStore new];
    
    NSError *error;
    NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[contact.cnContactId]];
    NSArray *tmpCnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
    if (error) {
        NSLog(@"error fetching contacts %@", error);
        return nil;
    } else {
        cnContacts = tmpCnContacts;
        
        NSMutableArray<NSDictionary<NSString *, NSString *> *> *emails = [NSMutableArray new];
        if (cnContacts.count == 1) {
            for (CNContact *person in cnContacts) {
                for (CNLabeledValue<NSString *> *label in person.emailAddresses) {
                    NSMutableDictionary<NSString *, NSString *> *dict = [NSMutableDictionary new];
                    NSString *emailLabel = label.label;
                    NSString *email = label.value;
                    if (email.length > 0) {
                        [dict setValue:[CNLabeledValue localizedStringForLabel:emailLabel] forKey:@"label"];
                        [dict setValue:email forKey:@"address"];
                        [emails addObject:dict];
                    }
                }
            }
        }
        return emails;
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)cnContactPhoneNumbersForContact:(ContactEntity *)contact {
    if (contact.cnContactId == nil)
        return nil;
    
    __block NSArray *cnContacts;
    CNContactStore *cnAddressBook = [CNContactStore new];
    
    NSError *error;
    NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[contact.cnContactId]];
    NSArray *tmpCnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
    if (error) {
        NSLog(@"error fetching contacts %@", error);
        return nil;
    } else {
        cnContacts = tmpCnContacts;
        
        NSMutableArray<NSDictionary<NSString *, NSString *> *> *phoneNumbers = [NSMutableArray new];
        if (cnContacts.count == 1) {
            for (CNContact *person in cnContacts) {
                for (CNLabeledValue<CNPhoneNumber *> *label in person.phoneNumbers) {
                    NSMutableDictionary<NSString *, NSString *> *dict = [NSMutableDictionary new];
                    NSString *phoneLabel = label.label;
                    NSString *phone = [label.value stringValue];
                    if (phone.length > 0) {
                        [dict setValue:[CNLabeledValue localizedStringForLabel:phoneLabel] forKey:@"label"];
                        [dict setValue:phone forKey:@"number"];
                        [phoneNumbers addObject:dict];
                    }
                }
            }
        }
        return phoneNumbers;
    }
}

- (NSString*)hashEmailBase64:(NSString*)email {
    NSData *emailHashKeyData = [NSData dataWithBytes:emailHashKey length:sizeof(emailHashKey)];
    return [[CryptoUtils hmacSha256ForData:[email dataUsingEncoding:NSASCIIStringEncoding] key:emailHashKeyData] base64EncodedStringWithOptions:0];
}

- (NSString*)hashMobileNoBase64:(NSString*)mobileNo {
    NSData *mobileNoHashKeyData = [NSData dataWithBytes:mobileNoHashKey length:sizeof(mobileNoHashKey)];
    return [[CryptoUtils hmacSha256ForData:[mobileNo dataUsingEncoding:NSASCIIStringEncoding] key:mobileNoHashKeyData] base64EncodedStringWithOptions:0];
}

#pragma mark - Read receipts

- (void)resetCustomReadReceipts {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];

    [entityManager performAsyncBlockAndSafe:^{
        NSArray *contactsWithCustomReadReceipts = [entityManager.entityFetcher contactsWithCustomReadReceipt];
        
        if (contactsWithCustomReadReceipts != nil) {
            for (ContactEntity *contact in contactsWithCustomReadReceipts) {
                contact.readReceipt = ReadReceiptDefault;
                [mediatorSyncableContacts updateReadReceiptWithIdentity:contact.identity value:ReadReceiptDefault];
            }
        }
    }];
    
    [mediatorSyncableContacts syncAsync];
}

#pragma mark - Multi Device Sync

- (void)reflectContact:(ContactEntity *)contact {
    MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
    [mediatorSyncableContacts updateAllWithIdentity:contact.identity added:NO];
    [mediatorSyncableContacts syncAsync];
}

- (void)reflectDeleteContact:(NSString *)identity {
    if (identity != nil && [[UserSettings sharedUserSettings] enableMultiDevice] == YES) {
        MediatorSyncableContacts *mediatorSyncableContacts = [[MediatorSyncableContacts alloc] init];
        [mediatorSyncableContacts deleteAndSyncObjcWithIdentity:identity completionHandler:^(NSError * _Nullable error) {
            if (error) {
                DDLogError(@"Contact delete and sync failed: %@", [error localizedDescription]);
            }
        }];
    }
}

@end
