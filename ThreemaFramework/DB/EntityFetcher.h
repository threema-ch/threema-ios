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
#import "Conversation.h"
#import "Ballot.h"
#import "AbstractMessage.h"
#import "AbstractGroupMessage.h"
#import "GroupEntity.h"
#import "LastGroupSyncRequest.h"
#import "WebClientSession.h"
#import "RequestedConversation.h"
#import "LastLoadedMessageIndex.h"
#import "RequestedThumbnail.h"
#import "MyIdentityStore.h"
#import "Nonce.h"

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

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext myIdentityStore:(id<MyIdentityStoreProtocol>)myIdentityStore;

- (__kindof NSManagedObject *)getManagedObjectById:(NSManagedObjectID *)objectID;

- (__kindof NSManagedObject *)existingObjectWithID:(NSManagedObjectID *)objectID;

- (__kindof NSManagedObject *)existingObjectWithIDString:(NSString *)objectIDString;

- (nullable BaseMessage *)ownMessageWithId:(nonnull NSData *)messageId conversation:(nonnull Conversation *)conversation NS_SWIFT_NAME(ownMessage(with:conversation:));

- (nullable BaseMessage *)messageWithId:(nonnull NSData *)messageId conversation:(nonnull Conversation *)conversation NS_SWIFT_NAME(message(with:conversation:));

- (NSArray *)quoteMessagesContaining:(NSString *)searchText message:(BaseMessage *)message inConversation:(Conversation *)conversation;

- (NSArray *)messagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation fetchLimit:(NSInteger)fetchLimit;

- (NSArray *)textMessagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation fetchLimit:(NSInteger)fetchLimit;

- (ContactEntity *)contactForId:(NSString *)identity NS_SWIFT_NAME(contact(for:));

- (ContactEntity *)contactForId:(NSString *)identity error:(NSError **)error;

// the data model allows multiple contacts for the same ID (although this is not actually supported)
- (NSArray *)allContactsForID:(NSString *)identity;

- (NSArray *)allContacts;

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

- (NSArray *)allGatewayContacts;

// Is this still used somewhere?
- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel;

- (NSArray<ContactEntity *> *)contactsWithFeatureMaskNil;

- (NSArray *)contactsWithCustomTypingIndicator;

- (NSArray *)contactsWithCustomReadReceipt;

- (NSArray *)groupConversationsFilteredByWords:(NSArray *)searchWords;

/// Group conversations where this contact is a member
///
/// @param contact Only groups where this contact is member of are returned
/// @return Array with `Conversation`s (might contain `nil` values)
- (NSArray *)groupConversationsForContact:(ContactEntity *)contact NS_SWIFT_NAME(groupConversations(for:));

- (NSArray *)allConversations;

- (NSArray *)allMessages;

- (NSArray *)notArchivedConversations;

- (NSArray *)allConversationsSorted;

- (NSArray *)allUnarchivedConversationsSorted;

- (NSArray *)conversationsWithNegativeUnreadMessageCount;

- (NSArray *)privateConversations;

- (NSString *)displayNameForContactId:(NSString *)identity NS_SWIFT_NAME(displayName(for:));

- (Conversation *)conversationForContact:(ContactEntity *)contact NS_SWIFT_NAME(conversation(for:));

- (Conversation *)conversationForIdentity:(NSString *)identity;

- (NSArray *)conversationsForMember:(ContactEntity *)contact;

- (Conversation *)conversationForGroupMessage:(AbstractGroupMessage *)message;

- (nullable Conversation *)conversationForGroupId:(nonnull NSData *)groupId creator:(nonnull NSString *)creator NS_SWIFT_NAME(conversation(for:creator:));

- (Ballot *)ballotForBallotId:(NSData *)ballotId NS_SWIFT_NAME(ballot(for:));

- (BallotChoice *)ballotChoiceForBallotId:(NSData *)ballotId choiceId:(NSNumber *)choiceId NS_SWIFT_NAME(ballotChoice(for:with:));

- (BOOL)isMessageAlreadyInDb:(AbstractMessage *)message;

- (nullable NSArray<Nonce *> *)allNonces;

- (BOOL)isNonceAlreadyInDB:(NSData *)nonce NS_SWIFT_NAME(isNonceAlreadyInDB(nonce:));


- (nullable NSArray<GroupEntity *> *)groupEntitiesForGroupId:(nonnull NSData *)groupId
    NS_SWIFT_NAME(groupEntities(for:))
    DEPRECATED_MSG_ATTRIBUTE("This is deprecated, is needed for Push Settings migration. DO NOT USE THIS!");

- (GroupEntity *)groupEntityForGroupId:(NSData *)groupId groupCreator:(NSString *)groupCreator NS_SWIFT_NAME(groupEntity(for:with:));

- (nullable GroupEntity *)groupEntityForConversation:(nonnull Conversation *)conversation;

- (LastGroupSyncRequest *)lastGroupSyncRequestFor:(NSData *)groupId groupCreator:(NSString *)groupCreator sinceDate:(NSDate *)sinceDate;

- (NSFetchRequest *)fetchRequestForEntity:(NSString *)entityName;

- (nullable NSArray *)executeFetchRequest:(nonnull NSFetchRequest *)fetchRequest;

- (NSInteger)executeCountFetchRequest:(NSFetchRequest *)fetchRequest;

/// An alternative to `executeCountFetchRequest` which only calls non-blocking Core Data methods
/// - Parameters:
///   - fetchRequest: The count fetch request to execute
///   - onCompletion: completion handler is called with the result of the count fetch request if the fetch succeeds. If onError is not set it will return 0 if it fails. Is always called on the main thread.
///   - onError: called if the fetch request returns an error. Is always called on the main thread.
- (void)executeCountFetchRequest:(nonnull NSFetchRequest *)fetchRequest onCompletion:(nonnull void(^)(NSInteger count))onCompletion onError:(nullable void(^)(NSError * _Nonnull))onError;

- (NSBatchUpdateResult *)executeBatchUpdateRequest:(NSBatchUpdateRequest *)batchUpdateRequst;

- (NSInteger)countBallotsForConversation:(Conversation *)conversation;

- (NSInteger)countOpenBallotsForConversation:(Conversation *)conversation;

- (NSArray *)imageMessagesForConversation:(Conversation *)conversation;

- (NSArray *)videoMessagesForConversation:(Conversation *)conversation;

- (NSArray *)fileMessagesForConversation:(Conversation *)conversation;

- (NSArray *)filesMessagesFilteredForPhotoBrowserForConversation:(Conversation *)conversation;

- (NSArray *)unreadMessagesForConversation:(Conversation *)conversation;

- (NSInteger)countMediaMessagesForConversation:(Conversation *)conversation;

- (NSInteger)countUnreadMessagesForConversation:(Conversation *)conversation;

- (NSInteger)countMessagesForContactWithIdentity:(nonnull NSString *)identity;

- (NSInteger)countMessagesForContact:(nonnull ContactEntity *)contact;

- (NSInteger)countMessagesForContactInConversation:(nonnull ContactEntity *)contact forConversation:(Conversation *)conversation;

- (NSFetchedResultsController *)fetchedResultsControllerForContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members;

- (NSFetchedResultsController *)fetchedResultsControllerForGroups;

- (NSFetchedResultsController *)fetchedResultsControllerForConversations;

- (NSFetchedResultsController *)fetchedResultsControllerForArchivedConversations;

- (NSFetchedResultsController *)fetchedResultsControllerForWebClientSessions;

- (NSInteger)countArchivedConversations;

- (Tag *)tagForName:(NSString *)name;

- (WebClientSession *)webClientSessionForInitiatorPermanentPublicKeyHash:(NSString *)hash;

- (WebClientSession *)webClientSessionForPrivateKey:(NSData *)privateKey;

- (WebClientSession *)activeWebClientSession;

- (NSArray *)allWebClientSessions;

- (NSArray *)allActiveWebClientSessions;

- (NSArray *)allNotPermanentWebClientSessions;

- (NSArray *)allLastGroupSyncRequests;

- (nonnull NSArray *)allCallsWith:(nonnull NSString *)identity callID:(uint32_t)callID;

- (nullable Conversation *)legacyConversationForGroupId:(nullable NSData *)groupId NS_SWIFT_NAME(legacyConversation(for:)); DEPRECATED_MSG_ATTRIBUTE("This is deprecated and will be removed together with the web client code. DO NOT USE THIS!");

- (NSInteger)countFileMessagesWithNoMIMEType;

- (nonnull NSArray *)allGroupCallEntities;

@end
