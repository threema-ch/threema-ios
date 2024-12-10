//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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
#import <ThreemaFramework/Ballot.h>
#import <ThreemaFramework/AbstractMessage.h>
#import <ThreemaFramework/AbstractGroupMessage.h>
#import <ThreemaFramework/MyIdentityStore.h>

@class ConversationEntity, DistributionListEntity, GroupCallEntity, NonceEntity, GroupEntity, LastGroupSyncRequestEntity, WebClientSessionEntity;

typedef enum : NSUInteger {
    ContactsAll,
    ContactsNoGateway,
    ContactsGatewayOnly,
    ContactsNoEchoEcho,
    ContactsNoGatewayNoEchoecho,
} ContactTypes;

typedef enum : NSUInteger {
    ContactListContacts,
    ContactListWork,
    ContactListContactsAndWork
} ContactList;

@interface EntityFetcher : NSObject

@property (readonly)NSManagedObjectContext *managedObjectContext;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext myIdentityStore:(id<MyIdentityStoreProtocol>)myIdentityStore;

- (__kindof NSManagedObject *)getManagedObjectById:(NSManagedObjectID *)objectID;

- (__kindof NSManagedObject *)existingObjectWithID:(NSManagedObjectID *)objectID;

- (__kindof NSManagedObject *)existingObjectWithIDString:(NSString *)objectIDString;

- (nullable BaseMessage *)ownMessageWithId:(nonnull NSData *)messageId conversationEntity:(nonnull ConversationEntity *)conversation NS_SWIFT_NAME(ownMessage(with:conversation:));

- (nullable BaseMessage *)messageWithId:(nonnull NSData *)messageId conversationEntity:(nonnull ConversationEntity *)conversation NS_SWIFT_NAME(message(with:conversation:));

- (NSArray *)quoteMessagesContaining:(NSString *)searchText message:(BaseMessage *)message inConversationEntity:(ConversationEntity *)conversation;

- (NSArray *)messagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit;

- (NSArray *)starredMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit;

- (NSArray *)textMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit;

- (ContactEntity *)contactForId:(NSString *)identity NS_SWIFT_NAME(contact(for:));

- (ContactEntity *)contactForId:(NSString *)identity error:(NSError **)error;

// the data model allows multiple contacts for the same ID (although this is not actually supported)
- (NSArray *)allContactsForID:(NSString *)identity;

- (NSArray *)allContacts;

/// A set of the identities of all contacts
///
/// This doesn't fetch the full `ContactEntity` managed objects. Thus this is about 3x faster than using `allContacts` and reading all identities.
///
/// - returns: A set of identity strings. If there are no contacts the set is empty.
- (nonnull NSSet<NSString *> *)allContactIdentities;

/// All valid contact identities that have a 1:1 conversation with `lastUpdate` set or are part of group that is not marked as left
///
/// See _Application Setup Steps_ of Threema Protocols for full specification of `solicited-contacts`.
///
/// - returns: A set of identity strings. If there are no matches the set is empty.
- (nonnull NSSet<NSString *> *)allSolicitedContactIdentities;

- (NSArray *)contactsFilteredByWords:(NSArray *)searchWords forContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members;

// Does a contact exist that contains my identity?
- (ContactEntity *_Nullable)contactsContainOwnIdentity;

/**
 Checks if there are duplicate contacts in the contact table.

 @param duplicateIdentities: Duplicate identities
 @return: YES if it has duplicate contacts, NO otherwise.
 */
- (BOOL)hasDuplicateContactsWithDuplicateIdentities:(NSSet **)duplicateIdentities;

- (NSArray *)allGroupConversations;

/// All active groups (i.e. not marked as (force) left)
///
/// - returns: An array of group entities for all active groups
- (nonnull NSArray<GroupEntity *> *)allActiveGroups;

- (NSArray *)allGatewayContacts;

// Is this still used somewhere?
- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel;

- (NSArray<ContactEntity *> *)contactsWithFeatureMaskNil;

- (NSArray *)contactsWithCustomTypingIndicator;

- (NSArray *)contactsWithCustomReadReceipt;

- (NSArray *)groupConversationsFilteredByWords:(NSArray *)searchWords;

- (NSArray *)distributionListsFilteredByWords:(NSArray *)searchWords;
/// Group conversations where this contact is a member
///
/// @param contact Only groups where this contact is member of are returned
/// @return Array with `Conversation`s (might contain `nil` values)
- (NSArray *)groupConversationsForContact:(ContactEntity *)contact NS_SWIFT_NAME(groupConversations(for:));

- (NSArray *)allConversations;

- (NSArray *)conversationsWithPredicate:(NSString *)predicate;

- (NSArray *)allMessages;

- (NSArray *)notArchivedConversations;

- (NSArray *)allConversationsSorted;

- (NSArray *)allUnarchivedConversationsSorted;

- (NSArray *)conversationsWithNegativeUnreadMessageCount;

- (NSArray *)privateConversations;

- (NSString *)displayNameForContactId:(NSString *)identity NS_SWIFT_NAME(displayName(for:));

- (ConversationEntity *)conversationEntityForContact:(ContactEntity *)contact NS_SWIFT_NAME(conversation(for:));

- (ConversationEntity *)conversationEntityForIdentity:(NSString *)identity;

- (nullable ConversationEntity *)conversationEntityForDistributionList:(nonnull DistributionListEntity *)distributionList;

- (NSArray *)conversationsForMember:(ContactEntity *)contact;

- (ConversationEntity *)conversationEntityForGroupMessage:(AbstractGroupMessage *)message;

- (nullable ConversationEntity *)conversationEntityForGroupId:(nonnull NSData *)groupId creator:(nonnull NSString *)creator NS_SWIFT_NAME(conversationEntity(for:creator:));

- (nullable ConversationEntity *)conversationEntityForDistributionListID:(nonnull NSNumber *)distributionListId
    NS_SWIFT_NAME(conversation(for:));

- (Ballot *)ballotForBallotId:(NSData *)ballotId NS_SWIFT_NAME(ballot(for:));

- (BallotChoice *)ballotChoiceForBallotId:(NSData *)ballotId choiceId:(NSNumber *)choiceId NS_SWIFT_NAME(ballotChoice(for:with:));

- (BOOL)isMessageAlreadyInDb:(AbstractMessage *)message;

- (nullable NSArray<NonceEntity *> *)allNonceEntities;

- (BOOL)isNonceAlreadyInDB:(NSData *)nonce NS_SWIFT_NAME(isNonceAlreadyInDB(nonce:));


- (nullable NSArray<GroupEntity *> *)groupEntitiesForGroupId:(nonnull NSData *)groupId
    NS_SWIFT_NAME(groupEntities(for:))
    DEPRECATED_MSG_ATTRIBUTE("This is deprecated, is needed for Push Settings migration. DO NOT USE THIS!");

- (GroupEntity *)groupEntityForGroupId:(NSData *)groupId groupCreator:(NSString *)groupCreator NS_SWIFT_NAME(groupEntity(for:with:));

- (nullable GroupEntity *)groupEntityForConversationEntity:(nonnull ConversationEntity *)conversation;

- (nullable DistributionListEntity *)distributionListEntityForConversationEntity:(nonnull ConversationEntity *)conversation;

- (nullable DistributionListEntity *) distributionListEntityForDistributionListID:(nonnull NSNumber *)distributionListID;

- (LastGroupSyncRequestEntity *)lastGroupSyncRequestFor:(NSData *)groupId groupCreator:(NSString *)groupCreator sinceDate:(NSDate *)sinceDate;

- (NSFetchRequest *)fetchRequestForEntity:(NSString *)entityName;

- (nullable NSArray *)executeFetchRequest:(nonnull NSFetchRequest *)fetchRequest;

- (NSInteger)executeCountFetchRequest:(NSFetchRequest *)fetchRequest;

/// An alternative to `executeCountFetchRequest` which only calls non-blocking Core Data methods
/// - Parameters:
///   - fetchRequest: The count fetch request to execute
///   - onCompletion: completion handler is called with the result of the count fetch request if the fetch succeeds. If onError is not set it will return 0 if it fails. Is always called on the main thread.
///   - onError: called if the fetch request returns an error. Is always called on the main thread.
- (void)executeCountFetchRequest:(nonnull NSFetchRequest *)fetchRequest onCompletion:(nonnull void(^)(NSInteger count))onCompletion onError:(nullable void(^)(NSError * _Nonnull))onError;

- (NSBatchUpdateResult *)executeBatchUpdateRequest:(NSBatchUpdateRequest *)batchUpdateRequest;

- (NSInteger)countBallotsForConversationEntity:(ConversationEntity *)conversation;

- (NSInteger)countOpenBallotsForConversationEntity:(ConversationEntity *)conversation;

- (NSArray *)imageMessagesForConversationEntity:(ConversationEntity *)conversation;

- (NSArray *)videoMessagesForConversationEntity:(ConversationEntity *)conversation;

- (NSArray *)fileMessagesForConversationEntity:(ConversationEntity *)conversation;

- (NSArray *)filesMessagesFilteredForPhotoBrowserForConversationEntity:(ConversationEntity *)conversation;

- (NSArray *)unreadMessagesForConversationEntity:(ConversationEntity *)conversation;

- (NSInteger)countMediaMessagesForConversationEntity:(ConversationEntity *)conversation;

- (NSInteger)countStarredMessagesInConversationEntity:(ConversationEntity *)conversation;

- (NSInteger)countUnreadMessagesForConversationEntity:(ConversationEntity *)conversation;

- (NSInteger)countMessagesForContactWithIdentity:(nonnull NSString *)identity;

- (NSInteger)countMessagesForContact:(nonnull ContactEntity *)contact;

- (NSInteger)countMessagesForContactEntity:(nonnull ContactEntity *)contact inConversationEntity:(ConversationEntity *)conversation;

- (NSFetchedResultsController *)fetchedResultsControllerForContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members;

- (NSFetchedResultsController *)fetchedResultsControllerForDistributionLists;
- (NSFetchedResultsController *)fetchedResultsControllerForGroups;

- (NSFetchedResultsController *)fetchedResultsControllerForConversations;

- (NSFetchedResultsController *)fetchedResultsControllerForArchivedConversations;

- (NSFetchedResultsController *)fetchedResultsControllerForWebClientSessions;

- (NSInteger)countArchivedConversations;

- (WebClientSessionEntity *)webClientSessionEntityForInitiatorPermanentPublicKeyHash:(NSString *)hash;

- (WebClientSessionEntity *)webClientSessionEntityForPrivateKey:(NSData *)privateKey;

- (WebClientSessionEntity *)activeWebClientSessionEntity;

- (NSArray *)allWebClientSessions;

- (NSArray *)allActiveWebClientSessions;

- (NSArray *)allNotPermanentWebClientSessions;

- (NSArray *)allLastGroupSyncRequests;

- (nonnull NSArray *)allCallsWith:(nonnull NSString *)identity callID:(uint32_t)callID;

- (NSArray *)allFileMessagesWithJsonCaptionButEmptyCaption;

- (nullable ConversationEntity *)legacyConversationForGroupId:(nullable NSData *)groupId NS_SWIFT_NAME(legacyConversation(for:)); DEPRECATED_MSG_ATTRIBUTE("This is deprecated and will be removed together with the web client code. DO NOT USE THIS!");

- (NSInteger)countFileMessagesWithNoMIMEType;

- (nonnull NSArray<GroupCallEntity *> *)allGroupCallEntities;

@end
