//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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
#import "Group.h"
#import "LastGroupSyncRequest.h"
#import "WebClientSession.h"
#import "RequestedConversation.h"
#import "LastLoadedMessageIndex.h"
#import "RequestedThumbnail.h"

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

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext;

- (id)getManagedObjectById:(NSManagedObjectID *)objectID;

- (BaseMessage *)ownMessageWithId:(NSData *)messageId;

- (BaseMessage *)messageWithId:(NSData *)messageId;

- (BaseMessage *)messageWithId:(NSData *)messageId conversation:(Conversation *)conversation;

- (NSArray *)quoteMessagesContaining:(NSString *)searchText message:(BaseMessage *)message inConversation:(Conversation *)conversation;

- (NSArray *)messagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation;

- (NSArray *)textMessagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation fetchLimit:(NSInteger)fetchLimit;

- (Contact *)contactForId:(NSString *)identity;

- (Contact *)contactForId:(NSString *)identity error:(NSError **)error;

- (NSArray *)allContacts;

- (NSArray *)contactsFilteredByWords:(NSArray *)searchWords;

- (NSArray *)contactsFilteredByWords:(NSArray *)searchWords forContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members;

- (NSArray *)allGroupConversations;

- (NSArray *)allGatewayContacts;

- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel;

- (NSArray *)contactsWithFeatureMaskNil;

- (NSArray *)groupConversationsFilteredByWords:(NSArray *)searchWords;

- (NSArray *)groupConversationsForContact:(Contact *)contact;

- (NSArray *)allConversations;

- (NSArray *)allConversationsSorted;

- (NSArray *)conversationsWithNegativeUnreadMessageCount;

- (NSString *)displayNameForContactId:(NSString *)identity;

- (Conversation *)conversationForGroupId:(NSData *)groupId;

- (Conversation *)conversationForContact:(Contact *)contact;

- (Conversation *)conversationForIdentity:(NSString *)identity;

- (NSArray *)conversationsForMember:(Contact *)contact;

- (Conversation *)conversationForGroupMessage:(AbstractGroupMessage *)message;

- (Ballot *)ballotForBallotId:(NSData *)ballotId;

- (BallotChoice *)ballotChoiceForBallotId:(NSData *)ballotId choiceId:(NSNumber *)choiceId;

- (BOOL)isMessageAlreadyInDb:(AbstractMessage *)message;

- (BOOL)isNonceAlreadyInDb:(AbstractMessage *)message;

- (Group *)groupForGroupId:(NSData *)groupId groupCreator:(NSString *)groupCreator;

- (Group *)groupForConversation:(Conversation *)conversation;

- (LastGroupSyncRequest *)lastGroupSyncRequestFor:(NSData *)groupId groupCreator:(NSString *)groupCreator sinceDate:(NSDate *)sinceDate;

- (NSFetchRequest *)fetchRequestForEntity:(NSString *)entityName;

- (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest;

- (NSInteger)executeCountFetchRequest:(NSFetchRequest *)fetchRequest;

- (NSInteger)countBallotsForConversation:(Conversation *)conversation;

- (NSInteger)countOpenBallotsForConversation:(Conversation *)conversation;

- (NSArray *)imageMessagesForConversation:(Conversation *)conversation;

- (NSArray *)videoMessagesForConversation:(Conversation *)conversation;

- (NSArray *)fileMessagesForConversation:(Conversation *)conversation;

- (NSArray *)fileMessagesWOStickersForConversation:(Conversation *)conversation;

- (NSInteger)countMediaMessagesForConversation:(Conversation *)conversation;

- (NSFetchedResultsController *)fetchedResultsControllerForContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members;

- (NSFetchedResultsController *)fetchedResultsControllerForGroups;

- (NSFetchedResultsController *)fetchedResultsControllerForConversations;

- (NSFetchedResultsController *)fetchedResultsControllerForWebClientSessions;

- (Tag *)tagForName:(NSString *)name;

- (WebClientSession *)webClientSessionForInitiatorPermanentPublicKeyHash:(NSString *)hash;

- (WebClientSession *)webClientSessionForPrivateKey:(NSData *)privateKey;

- (WebClientSession *)activeWebClientSession;

- (NSArray *)allWebClientSessions;

- (NSArray *)allActiveWebClientSessions;

- (NSArray *)allNotPermanentWebClientSessions;

@end
