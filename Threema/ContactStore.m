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

#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>
#import "PhoneNumberNormalizer.h"

#import "ContactStore.h"
#import "NSString+Hex.h"
#import "Contact.h"
#import "ServerAPIConnector.h"
#import "MyIdentityStore.h"
#import "Utils.h"
#import "UserSettings.h"
#import "ProtocolDefines.h"
#import "EntityManager.h"
#import "ThreemaError.h"
#import "AppGroup.h"
#import "WorkDataFetcher.h"
#import "ValidationLogger.h"
#import "IdentityInfoFetcher.h"
#import "CryptoUtils.h"
#import "TrustedContacts.h"

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

- (id)init
{
    self = [super init];
    if (self) {
        syncQueue = dispatch_queue_create("ch.threema.contactsync", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(syncQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
        
        /* register a callback to get information about address book changes */
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressBookChangeDetected:) name:CNContactStoreDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orderChanged:) name:@"ThreemaContactsOrderChanged" object:nil];
        
        entityManager = [[EntityManager alloc] init];
        
        /* update display/sort order prefs to match system */
        if (@available(iOS 11.0, *)) {
            BOOL sortOrder = [[CNContactsUserDefaults sharedDefaults] sortOrder] == CNContactSortOrderGivenName;
            [[UserSettings sharedUserSettings] setSortOrderFirstName:sortOrder];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [[UserSettings sharedUserSettings] setSortOrderFirstName:(ABPersonGetSortOrdering() == kABPersonSortByFirstName)];
#pragma clang diagnostic pop
        }
    }
    return self;
}

- (void)dealloc {
    [checkStatusTimer invalidate];
}

- (void)addressBookChangeDetected:(NSNotification *)notification {
    DDLogInfo(@"Address book change detected");
    [[ValidationLogger sharedValidationLogger] logString:@"Address book change detected"];
    [self synchronizeAddressBookForceFullSync:NO onCompletion:^(BOOL addressBookAccessGranted) {
        [self updateAllContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddressbookSyncronized object:self userInfo:nil];
    } onError:^(NSError *error) {
        [self updateAllContacts];
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddressbookSyncronized object:self userInfo:nil];
    }];
}

- (Contact*)contactForIdentity:(NSString *)identity {
    /* check in local DB first */
    EntityManager *entityManager = [[EntityManager alloc] init];
    Contact *contact = [entityManager.entityFetcher contactForId: identity];
    return contact;
}

- (void)addContactWithIdentity:(NSString *)identity verificationLevel:(int32_t)verificationLevel onCompletion:(void(^)(Contact *contact, BOOL alreadyExists))onCompletion onError:(void(^)(NSError *error))onError {
    
    /* check in local DB first */
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSError *error;
    Contact *contact = [entityManager.entityFetcher contactForId:identity error:&error];
    if (contact) {
        onCompletion(contact, YES);
        return;
    }
    if (error != nil) {
        onError(error);
    }
    
    /* not found - request from server */
    ServerAPIConnector *apiConnector = [[ServerAPIConnector alloc] init];
    [apiConnector fetchIdentityInfo:identity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
        
        /* save new contact */
        dispatch_async(dispatch_get_main_queue(), ^{
            /* save new contact */
            Contact *contact = [self addContactWithIdentity:identity publicKey:publicKey cnContactId:nil verificationLevel:verificationLevel state:state type:type featureMask:featureMask alerts:YES];
            /* force synchronisation */
            [self synchronizeAddressBookForceFullSync:YES onCompletion:nil onError:nil];
            [WorkDataFetcher checkUpdateWorkDataForce:YES onCompletion:nil onError:nil];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kSafeBackupTrigger object:nil];
            
            onCompletion(contact, NO);
        });
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (Contact*)addContactWithIdentity:(NSString*)identity publicKey:(NSData*)publicKey cnContactId:(NSString *)cnContactId verificationLevel:(int32_t)verificationLevel featureMask:(NSNumber *)featureMask alerts:(BOOL)alerts {
    return [self addContactWithIdentity:identity publicKey:publicKey cnContactId:cnContactId verificationLevel:verificationLevel state:nil type:nil featureMask:featureMask alerts:alerts];
}

- (Contact*)addContactWithIdentity:(NSString*)identity publicKey:(NSData*)publicKey cnContactId:(NSString *)cnContactId verificationLevel:(int32_t)verificationLevel state:(NSNumber *)state type:(NSNumber *)type featureMask:(NSNumber *)featureMask alerts:(BOOL)alerts {
    /* Make sure this is not our own identity */
    if ([MyIdentityStore sharedMyIdentityStore].isProvisioned && [identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogInfo(@"Ignoring attempt to add own identity");
        return nil;
    }
    
    /* Check if we already have a contact with this identity */
    __block BOOL added = NO;
    __block Contact *contact;

    [entityManager performSyncBlockAndSafe:^{
        contact = [entityManager.entityFetcher contactForId: identity];
        if (contact) {
            DDLogInfo(@"Found existing contact with identity %@", identity);
            if (![publicKey isEqualToData:contact.publicKey]) {
                DDLogError(@"Public key doesn't match for existing identity %@!", identity);
                
                if (alerts) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationErrorPublicKeyMismatch object:nil userInfo:nil];
                }
                
                return;
            }
        } else {
            added = YES;
            contact = [entityManager.entityCreator contact];
            contact.identity = identity;
            contact.publicKey = publicKey;
            contact.featureMask  = featureMask;
            if (state != nil) {
                contact.state = state;
            }
            if (type != nil) {
                if ([type isEqualToNumber:@1]) {
                    NSMutableOrderedSet *workIdentities = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].workIdentities];
                    if (![workIdentities containsObject:contact.identity])
                        [workIdentities addObject:contact.identity];
                    [UserSettings sharedUserSettings].workIdentities = workIdentities;
                }
            }
            [self addProfilePictureRequest:identity];
        }
        
        if (contact.verificationLevel == nil || (contact.verificationLevel.intValue < verificationLevel && contact.verificationLevel.intValue != kVerificationLevelFullyVerified) || verificationLevel == kVerificationLevelFullyVerified)
            contact.verificationLevel = [NSNumber numberWithInt:verificationLevel];
        
        if (contact.workContact == nil) {
            if (contact.verificationLevel.intValue == kVerificationLevelWorkVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
                contact.workContact = [NSNumber numberWithBool:YES];
            } else if (contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
                contact.workContact = [NSNumber numberWithBool:YES];
            } else {
                contact.workContact = [NSNumber numberWithBool:NO];
            }
        }
        if ([contact.workContact isEqualToNumber:[NSNumber numberWithBool:YES]] && (contact.verificationLevel.intValue == kVerificationLevelWorkVerified || contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified)) {
            if (contact.verificationLevel.intValue == kVerificationLevelWorkVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
            } else if (contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
            }
        }
        
        // check if this is a trusted contact (like *THREEMA)
        if ([TrustedContacts isTrustedContactWithIdentity:identity publicKey:publicKey]) {
            contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
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
                                NSLog(@"error fetching contacts %@", error);
                            } else {
                                if (cnContacts.count == 1) {
                                    CNContact *foundContact = cnContacts.firstObject;
                                    NSString *firstName = foundContact.givenName;
                                    NSString *lastName = foundContact.familyName;
                                    
                                    if (contact.firstName != nil && contact.firstName.length > 0 && contact.lastName != nil && contact.lastName.length > 0) {
                                        if ([firstName isEqualToString:contact.firstName] && [lastName isEqualToString:contact.lastName]) {
                                            DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                            [self linkContact:contact toCnContactId:cnContactId];
                                        }
                                    }
                                    else if (contact.firstName != nil && contact.firstName.length > 0) {
                                        if ([firstName isEqualToString:contact.firstName]) {
                                            DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                            [self linkContact:contact toCnContactId:cnContactId];
                                        }
                                    }
                                    else if (contact.lastName != nil && contact.lastName.length > 0) {
                                        if ([lastName isEqualToString:contact.lastName]) {
                                            DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                            [self linkContact:contact toCnContactId:cnContactId];
                                        }
                                    }
                                    else {
                                        // No name for the contact to compare, replace the cncontactid
                                        DDLogInfo(@"Address book record ID has changed for %@ %@ (%@ -> %@) - relinking", firstName, lastName, contact.cnContactId, cnContactId);
                                        [self linkContact:contact toCnContactId:cnContactId];
                                    }
                                }
                            }
                        }
                    }];
                }
            } else {
                [self linkContact:contact toCnContactId:cnContactId];
            }
        }
    }];
    
    if (added)
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddedContact object:contact];
    
    return contact;
}

- (Contact *)addWorkContactWithIdentity:(NSString *)identity publicKey:(NSData*)publicKey firstname:(NSString *)firstname lastname:(NSString *)lastname {
    /* Make sure this is not our own identity */
    if ([MyIdentityStore sharedMyIdentityStore].isProvisioned && [identity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        DDLogInfo(@"Ignoring attempt to add own identity");
        return nil;
    }
    
    /* Check if we already have a contact with this identity */
    __block BOOL added = NO;
    __block Contact *contact;
    
    [entityManager performSyncBlockAndSafe:^{
        contact = [entityManager.entityFetcher contactForId: identity];
        if (contact) {
            DDLogInfo(@"Found existing contact with identity %@", identity);
            if (![publicKey isEqualToData:contact.publicKey]) {
                DDLogError(@"Public key doesn't match for existing identity %@!", identity);
                return;
            }
        } else {
            added = YES;
            contact = [entityManager.entityCreator contact];
            contact.identity = identity;
            contact.publicKey = publicKey;
            contact.firstName = firstname;
            contact.lastName = lastname;
            NSMutableOrderedSet *workIdentities = [[NSMutableOrderedSet alloc] initWithOrderedSet:[UserSettings sharedUserSettings].workIdentities];
            if (![workIdentities containsObject:contact.identity])
                [workIdentities addObject:contact.identity];
            [UserSettings sharedUserSettings].workIdentities = workIdentities;
            [self addProfilePictureRequest:identity];
        }
        
        contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
        contact.workContact = [NSNumber numberWithBool:YES];
    }];
    
    if (added)
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationAddedContact object:contact];
    
    [self updateFeatureMasksForContacts:@[contact] onCompletion:^{
    } onError:^(NSError *error) {
    }];
    return contact;
}

- (void)updateContact:(Contact*)contact {
    if (contact.cnContactId == nil) {
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
                [self _updateContact:contact withCnContact:foundContact];
            }
        }
    }];
}

- (void)_updateContact:(Contact *)contact withCnContact:(CNContact *)cnContact {
    
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
    
    if (newFirstName != contact.firstName && ![newFirstName isEqual:contact.firstName])
        contact.firstName = newFirstName;
    
    if (newLastName != contact.lastName && ![newLastName isEqual:contact.lastName])
        contact.lastName = newLastName;
    
    /* get image, if any */
    NSData *newImageData = nil;
    if (cnContact.imageDataAvailable) {
        newImageData = cnContact.thumbnailImageData;
    }
    
    if (newImageData != contact.imageData && ![newImageData isEqualToData:contact.imageData])
        contact.imageData = newImageData;
    
    DDLogVerbose(@"Updated contact %@ %@", contact.firstName, contact.lastName);
}

- (void)updateAllContacts {
    
    NSArray *allContacts = [entityManager.entityFetcher allContacts];
    if (allContacts == nil || allContacts.count == 0) {
        return;
    }
    
    // Migration of verfication level kVerificationLevelWorkVerified and kVerificationLevelWorkFullyVerified to flag workContact
    [entityManager performAsyncBlockAndSafe:^{
        for (Contact *contact in allContacts) {
            if (contact.workContact == nil || contact.verificationLevel.intValue == kVerificationLevelWorkVerified || contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                if (contact.verificationLevel.intValue == kVerificationLevelWorkVerified) {
                    contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelServerVerified];
                    contact.workContact = [NSNumber numberWithBool:YES];
                } else if (contact.verificationLevel.intValue == kVerificationLevelWorkFullyVerified) {
                    contact.verificationLevel = [NSNumber numberWithInt:kVerificationLevelFullyVerified];
                    contact.workContact = [NSNumber numberWithBool:YES];
                } else {
                    contact.workContact = [NSNumber numberWithBool:NO];
                }
            }
        }
    }];
    
    NSArray *linkedContacts = [allContacts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        Contact *contact = (Contact *)evaluatedObject;
        return contact.cnContactId != nil;
    }]];
    if (linkedContacts == nil || linkedContacts.count == 0) {
        return;
    }
    
    CNContactStore *cnAddressBook = [CNContactStore new];
    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted == YES) {
            [entityManager performAsyncBlockAndSafe:^{
                /* go through all contacts and resync with address book; only create
                 address book ref when encountering the first contact that is linked */
                int nupdated = 0;
                
                for (Contact *contact in linkedContacts) {
                    NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[contact.cnContactId]];
                    NSError *error;
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                    if (error) {
                        NSLog(@"error fetching contacts %@", error);
                    } else {
                        if (cnContacts != nil && cnContacts.count > 0) {
                            CNContact *foundContact = cnContacts.firstObject;
                            [self _updateContact:contact withCnContact:foundContact];
                            nupdated++;
                        }
                    }
                }
                
                DDLogInfo(@"Updated %d contacts", nupdated);
            }];
            
            [self updateStatusForAllContacts];
        }
    }];
}

- (void)linkContact:(Contact*)contact toCnContactId:(NSString *)cnContactId {
    /* obtain first/last name from address book */
    [entityManager performSyncBlockAndSafe:^{
        contact.cnContactId = cnContactId;
        [self updateContact:contact];
    }];
}

- (void)unlinkContact:(Contact*)contact {
    [entityManager performSyncBlockAndSafe:^{
        contact.abRecordId = [NSNumber numberWithInt:0];
        contact.cnContactId = nil;
        contact.firstName = nil;
        contact.lastName = nil;
        contact.imageData = nil;
    }];
}

- (void)fetchPublicKeyForIdentity:(NSString*)identity onCompletion:(void(^)(NSData *publicKey))onCompletion onError:(void(^)(NSError *error))onError {
    
    [entityManager performBlock:^{
        // check in local DB first
        Contact *contact = [entityManager.entityFetcher contactForId:identity];
        if (contact.publicKey) {
            onCompletion(contact.publicKey);
        } else {
            // not found - request from server
            if ([UserSettings sharedUserSettings].blockUnknown) {
                DDLogVerbose(@"Block unknown contacts is on - discarding message");
                onError([ThreemaError threemaError:@"Message received from unknown contact and block contacts is on" withCode:kBlockUnknownContactErrorCode]);
                return;
            }
            
            [[IdentityInfoFetcher sharedIdentityInfoFetcher] fetchIdentityInfoFor:identity onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // First, check in local DB again, as it may have already been saved in the meantime (in case of parallel requests)
                    Contact *contact = [entityManager.entityFetcher contactForId:identity];
                    if (contact.publicKey) {
                        onCompletion(contact.publicKey);
                        return;
                    }

                    // Save new contact. Do it on main queue to ensure that it's done by the time we signal completion.
                    [self addContactWithIdentity:identity publicKey:publicKey cnContactId:nil verificationLevel:kVerificationLevelUnverified state:state type:type featureMask:featureMask alerts:NO];
                    [self synchronizeAddressBookForceFullSync:YES onCompletion:nil onError:nil];
                    [WorkDataFetcher checkUpdateWorkDataForce:YES onCompletion:nil onError:nil];
                    
                    onCompletion(publicKey);
                });
            } onError:^(NSError * _Nonnull error) {
                onError(error);
            }];
        }
    }];
}

- (void)prefetchIdentityInfo:(NSSet*)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    NSMutableSet *identitiesToFetch = [NSMutableSet set];
    
    // Skip identities that we already have a contact for
    for (NSString *identity in identities) {
        Contact *contact = [entityManager.entityFetcher contactForId:identity];
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

- (void)upgradeContact:(Contact*)contact toVerificationLevel:(int)verificationLevel {
    if ((contact.verificationLevel.intValue < verificationLevel && contact.verificationLevel.intValue != kVerificationLevelFullyVerified) || verificationLevel == kVerificationLevelFullyVerified) {
        [entityManager performSyncBlockAndSafe:^{
            contact.verificationLevel = [NSNumber numberWithInt:verificationLevel];
        }];
    }
}

- (void)setWorkContact:(Contact *)contact workContact:(BOOL)workContact {
    [entityManager performSyncBlockAndSafe:^{
        contact.workContact = [NSNumber numberWithBool:workContact];
    }];
}

- (void)updateProfilePicture:(Contact *)contact imageData:(NSData *)imageData didFailWithError:(NSError **)error {
    UIImage *image = [UIImage imageWithData:imageData];
    if (image == nil) {
        *error = [ThreemaError threemaError:@"Image decoding failed"];
        return;
    }
    
    [entityManager performSyncBlockAndSafe:^{
        ImageData *dbImage = [entityManager.entityCreator imageData];
        dbImage.data = imageData;
        dbImage.width = [NSNumber numberWithInt:image.size.width];
        dbImage.height = [NSNumber numberWithInt:image.size.height];
        
        contact.contactImage = dbImage;
    }];
    
    [self removeProfilePictureRequest:contact.identity];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationIdentityAvatarChanged object:contact.identity];
}

- (void)deleteProfilePicture:(Contact *)contact {
    [entityManager performSyncBlockAndSafe:^{
        contact.contactImage = nil;
    }];
    
    [self removeProfilePictureRequest:contact.identity];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationIdentityAvatarChanged object:contact.identity];
}

- (void)removeProfilePictureFlagForAllContacts {
    [entityManager performAsyncBlockAndSafe:^{
        NSArray *allContacts = [entityManager.entityFetcher allContacts];
        
        if (allContacts != nil) {
            for (Contact *contact in allContacts) {
                contact.profilePictureSended = NO;
            }
        }
    }];
}

- (void)removeProfilePictureFlagForContact:(NSString *)identity {
    [entityManager performAsyncBlockAndSafe:^{
        Contact *contact = [entityManager.entityFetcher contactForId:identity];
        
        if (contact != nil) {
            contact.profilePictureSended = NO;
        }
    }];
}

- (BOOL)existsProfilePictureRequest:(NSString *)identity {
    @synchronized (self) {
        return [[[UserSettings sharedUserSettings] profilePictureRequestList] containsObject:identity];
    }
}

- (void)removeProfilePictureRequest:(NSString *)identity {
    @synchronized (self) {
        if ([self existsProfilePictureRequest:identity]) {
            NSMutableSet *profilePictureRequestList = [NSMutableSet setWithArray:[UserSettings sharedUserSettings].profilePictureRequestList];
            [profilePictureRequestList removeObject:identity];
            [UserSettings sharedUserSettings].profilePictureRequestList = profilePictureRequestList.allObjects;
        }
    }
}

- (void)addProfilePictureRequest:(NSString *)identity {
    @synchronized (self) {
        if (![self existsProfilePictureRequest:identity]) {
            NSMutableSet *profilePictureRequestList = [NSMutableSet setWithArray:[UserSettings sharedUserSettings].profilePictureRequestList];
            [profilePictureRequestList addObject:identity];
            [UserSettings sharedUserSettings].profilePictureRequestList = profilePictureRequestList.allObjects;
        }
    }
}

- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError {
    [self synchronizeAddressBookForceFullSync:forceFullSync ignoreMinimumInterval:NO onCompletion:onCompletion onError:onError];
}

- (void)synchronizeAddressBookForceFullSync:(BOOL)forceFullSync ignoreMinimumInterval:(BOOL)ignoreMinimumInterval onCompletion:(void(^)(BOOL addressBookAccessGranted))onCompletion onError:(void(^)(NSError *error))onError {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
        return;
    }
    
    /* Get all entries from the user's address book, hash the e-mail addresses
     and phone numbers and send to the server. */
    if (![UserSettings sharedUserSettings].syncContacts) {
        // trigger updating of status for identities
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^{
            [self updateStatusForAllContactsIgnoreInterval: ignoreMinimumInterval];
            if (onCompletion != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    onCompletion(NO);
                });
            }
        });
        return;
    }
    
    CNContactStore *cnAddressBook = [CNContactStore new];
    
    if ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] != CNAuthorizationStatusAuthorized) {
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                [self synchronizeAddressBookForceFullSync:forceFullSync onCompletion:onCompletion onError:onError];
            } else {
                DDLogInfo(@"Address book access has NOT been granted: %@", error);
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^{
                    [self updateStatusForAllContactsIgnoreInterval: ignoreMinimumInterval];
                });
                if (onCompletion != nil)
                    dispatch_async(dispatch_get_main_queue(), ^{
                        onCompletion(NO);
                    });
            }
        }];
        return;
    }
    
    if (cnAddressBook == nil) {
        DDLogInfo(@"Address book is nil");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^{
            [self updateStatusForAllContactsIgnoreInterval: ignoreMinimumInterval];
        });
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
            lastFullSyncDate = [NSDate date];
        }
        
        [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: build all e-mail and phone number hashes"];
        /* extract all e-mail and phone number hashes from the user's address book */
        [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted == YES) {
                NSError *error;
                NSMutableArray *allCNContacts = [NSMutableArray new];
                
                NSArray *containers = [cnAddressBook containersMatchingPredicate:nil error:&error];
                for (CNContainer *container in containers) {
                    NSPredicate *predicate = [CNContact predicateForContactsInContainerWithIdentifier:container.identifier];
                    NSArray *cnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
                    [allCNContacts addObjectsFromArray:cnContacts];
                }
                
                [self processAddressBookContacts:allCNContacts fullServerSync:fullServerSync ignoreMinimumInterval:ignoreMinimumInterval onCompletion:onCompletion onError:onError];
            }
        }];
    });
}

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
        [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: Start core data stuff"];
        /* Core data stuff on main thread */
        dispatch_async(dispatch_get_main_queue(), ^{
            NSSet *excludedIds = [NSSet setWithArray:[UserSettings sharedUserSettings].syncExclusionList];
            NSMutableArray *allIdentities = [NSMutableArray new];
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
                [self addContactWithIdentity:identity publicKey:[[NSData alloc] initWithBase64EncodedString:[identityData objectForKey:@"publicKey"] options:0] cnContactId:cnContactId verificationLevel:kVerificationLevelServerVerified featureMask:nil alerts:NO];
            }
            DDLogNotice(@"ContactSync: Found %lu contacts", (unsigned long)allIdentities.count);
            // trigger updating of status for identities
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, (unsigned long)NULL), ^{
                [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: update status and featuremask for all contacts"];
                [self updateStatusForAllContactsIgnoreInterval: ignoreMinimumInterval];
            });
            
            if (onCompletion != nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: onCompletion"];
                    onCompletion(YES);
                });
            } else {
                [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: finished"];
            }
        });
        
    } onError:^(NSError *error) {
        DDLogError(@"Synchronize address book failed: %@", error);
        [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Synchronize address book failed: %@", error]];
        if (onError != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onError(error);
            });
        }
    }];
}

- (void)linkedIdentities:(NSString*)email mobileNo:(NSString*)mobileNo onCompletion:(void(^)(NSArray *identities))onCompletion {
    
    NSArray *emailHashesBase64 = [NSArray array];
    NSArray *mobileNoHashesBase64 = [NSArray array];
    
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
            onCompletion(identities);
        } onError:^(NSError *error) {
            DDLogError(@"linked identities failed: %@", error);
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

- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel {
    return [entityManager.entityFetcher contactsWithVerificationLevel:verificationLevel];
}

- (NSArray *)contactsWithFeatureMaskNil {
    return [entityManager.entityFetcher contactsWithFeatureMaskNil];
}

- (NSArray *)allContacts {
    return [entityManager.entityFetcher allContacts];
}

- (void)orderChanged:(NSNotification*)notification {
    [entityManager performAsyncBlockAndSafe:^{
        /* update display name and sort index of all contacts */
        NSArray *allContacts = [entityManager.entityFetcher allContacts];
        
        if (allContacts != nil) {
            for (Contact *contact in allContacts) {
                /* set last name again to trigger update of display name and sort index */
                contact.lastName = contact.lastName;
            }
        }
    }];
}

- (NSArray *)identitiesForContacts:(NSArray *)contacts {
    NSMutableArray *identities = [NSMutableArray arrayWithCapacity:contacts.count];
    for (Contact *contact in contacts) {
        [identities addObject:contact.identity];
    }
    
    return identities;
}

- (NSArray *)validIdentitiesForContacts:(NSArray *)contacts {
    NSMutableArray *identities = [NSMutableArray arrayWithCapacity:contacts.count];
    for (Contact *contact in contacts) {
        if (contact.state.intValue != kStateInvalid) {
            [identities addObject:contact.identity];
        }
    }
    
    return identities;
}

- (void)updateFeatureMasksForContacts:(NSArray *)contacts onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    NSArray *identities = [self identitiesForContacts: contacts];
    
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn getFeatureMasksForIdentities:identities onCompletion:^(NSArray *featureMasks) {
        [entityManager performSyncBlockAndSafe:^{
            for (NSInteger i=0; i<[identities count]; i++) {
                NSNumber *featureMask = [featureMasks objectAtIndex: i];
                
                if (featureMask.integerValue >= 0) {
                    NSString *identityString = [identities objectAtIndex:i];
                    Contact *contact = [entityManager.entityFetcher contactForId: identityString];
                    contact.featureMask = featureMask;
                }
            }
        }];
        
        onCompletion();
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (void)updateFeatureMasksForIdentities:(NSArray *)identities onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *error))onError {
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn getFeatureMasksForIdentities:identities onCompletion:^(NSArray *featureMasks) {
        [entityManager performSyncBlockAndSafe:^{
            for (NSInteger i=0; i<[identities count]; i++) {
                NSNumber *featureMask = [featureMasks objectAtIndex: i];
                
                if (featureMask.integerValue >= 0) {
                    NSString *identityString = [identities objectAtIndex:i];
                    Contact *contact = [entityManager.entityFetcher contactForId: identityString];
                    contact.featureMask = featureMask;
                }
            }
        }];
        
        onCompletion();
    } onError:^(NSError *error) {
        onError(error);
    }];
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
    [self updateStatusForAllContactsIgnoreInterval:NO];
}

- (void)updateStatusForAllContactsIgnoreInterval:(BOOL)ignoreInterval {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {        
        NSArray *contacts = [entityManager.entityFetcher allContacts];
        [self updateStatusForContacts:contacts onCompletion:^() {
            [self setupCheckStatusTimer];
        } onError:^(){
            [self setupCheckStatusTimer];
        }];
    } else {
        if ([self needCheckStatus:ignoreInterval] == NO) {
            [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: do not update status and featuremasks"];
            return;
        }
        
        NSArray *contacts = [entityManager.entityFetcher allContacts];
        [self updateStatusForContacts:contacts onCompletion:^() {
            [self setupCheckStatusTimer];
            [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: update status and featuremasks finished"];
        } onError:^(){
            [[ValidationLogger sharedValidationLogger] logString:@"ContactSync: update status featuremasks finished with error"];
            [self setupCheckStatusTimer];
        }];
    }
}

- (void)updateStatusForContacts:(NSArray *)contacts onCompletion:(void(^)(void))onCompletion onError:(void(^)(void))onError {
    NSArray *identities = [self validIdentitiesForContacts: contacts];
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn checkStatusOfIdentities:identities onCompletion:^(NSArray *states, NSArray *types, NSArray *featureMasks, int checkInterval) {
        [entityManager performSyncBlockAndSafe:^{
            NSMutableOrderedSet *workIdentities = [NSMutableOrderedSet new];
            for (NSInteger i=0; i<[identities count]; i++) {
                NSNumber *state = [states objectAtIndex: i];
                NSNumber *type = [types objectAtIndex:i];
                NSNumber *featureMask = [featureMasks objectAtIndex:i];
                
                NSString *identityString = [identities objectAtIndex:i];
                Contact *contact = [entityManager.entityFetcher contactForId: identityString];
                if (![contact.state isEqualToNumber:state])
                    contact.state = state;
                
                if ([type isEqualToNumber:@1]) {
                    [workIdentities addObject:contact.identity];
                }
                
                if (![featureMask isEqual:[NSNull null]]) {
                    if (![contact.featureMask isEqualToNumber:featureMask]) {
                        contact.featureMask = featureMask;
                    }
                }
            }
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"FASTLANE_SNAPSHOT"]) {
                [UserSettings sharedUserSettings].workIdentities = workIdentities;
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
    
    NSArray *linkedContacts = [[entityManager.entityFetcher allContacts] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        Contact *contact = (Contact *)evaluatedObject;
        return contact.abRecordId != nil && contact.abRecordId.intValue != 0;
    }]];
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
            for (Contact *contact in linkedContacts) {
                
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

- (void)cnContactAskAccessEmailsForContact:(Contact *)contact completionHandler:(void (^)(BOOL granted, NSArray *array))completionHandler {
    if (contact.cnContactId == nil)
        completionHandler(YES, nil);
    
    __block NSArray *cnContacts;
    CNContactStore *cnAddressBook = [CNContactStore new];
    
    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted == YES) {
            NSError *error;
            NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[contact.cnContactId]];
            NSArray *tmpCnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
            if (error) {
                NSLog(@"error fetching contacts %@", error);
                completionHandler(YES, nil);
            } else {
                cnContacts = tmpCnContacts;
                
                NSMutableArray *emails = [NSMutableArray new];
                if (cnContacts.count == 1) {
                    for (CNContact *person in cnContacts) {
                        for (CNLabeledValue *label in person.emailAddresses) {
                            NSMutableDictionary *dict = [NSMutableDictionary new];
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
                completionHandler(YES, emails);
            }
        } else {
            completionHandler(NO, nil);
        }
    }];
}

- (void)cnContactAskAccessPhoneNumbersForContact:(Contact *)contact completionHandler:(void (^)(BOOL granted, NSArray *array))completionHandler {
    if (contact.cnContactId == nil)
        completionHandler(YES, nil);
    
    __block NSArray *cnContacts;
    CNContactStore *cnAddressBook = [CNContactStore new];
    
    [cnAddressBook requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted == YES) {
            NSError *error;
            NSPredicate *predicate = [CNContact predicateForContactsWithIdentifiers:@[contact.cnContactId]];
            NSArray *tmpCnContacts = [cnAddressBook unifiedContactsMatchingPredicate:predicate keysToFetch:kCNContactKeys error:&error];
            if (error) {
                NSLog(@"error fetching contacts %@", error);
                completionHandler(YES, nil);
            } else {
                cnContacts = tmpCnContacts;
                
                NSMutableArray *phoneNumbers = [NSMutableArray new];
                if (cnContacts.count == 1) {
                    for (CNContact *person in cnContacts) {
                        for (CNLabeledValue *label in person.phoneNumbers) {
                            NSMutableDictionary *dict = [NSMutableDictionary new];
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
                completionHandler(YES, phoneNumbers);
            }
        } else {
            completionHandler(NO, nil);
        }
    }];
}

- (NSArray *)cnContactEmailsForContact:(Contact *)contact {
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
        
        NSMutableArray *emails = [NSMutableArray new];
        if (cnContacts.count == 1) {
            for (CNContact *person in cnContacts) {
                for (CNLabeledValue *label in person.emailAddresses) {
                    NSMutableDictionary *dict = [NSMutableDictionary new];
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

- (NSArray *)cnContactPhoneNumbersForContact:(Contact *)contact {
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
        
        NSMutableArray *phoneNumbers = [NSMutableArray new];
        if (cnContacts.count == 1) {
            for (CNContact *person in cnContacts) {
                for (CNLabeledValue *label in person.phoneNumbers) {
                    NSMutableDictionary *dict = [NSMutableDictionary new];
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

@end
