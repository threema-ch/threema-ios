//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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

#import "EntityFetcher.h"
#import "DatabaseManager.h"
#import "AbstractGroupMessage.h"
#import "MyIdentityStore.h"
#import "Contact.h"
#import "UserSettings.h"
#import "BaseMessage.h"
#import "BundleUtil.h"
#import "TextMessage.h"
#import "LicenseStore.h"
#import "NonceHasher.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface EntityFetcher ()

@property NSManagedObjectContext *managedObjectContext;

@end

@implementation EntityFetcher

/*
- (instancetype)init
{
    self = [super init];
    if (self) {
        _managedObjectContext = [[DatabaseManager dbManager] getManagedObjectContext:![NSThread isMainThread]];
    }
    return self;
}
*/

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext {
    self = [super init];
    if (self) {
        _managedObjectContext = managedObjectContext;
    }
    return self;
}

- (id)getManagedObjectById:(NSManagedObjectID *)objectID {
    return [_managedObjectContext objectWithID: objectID];
}

- (BaseMessage *)ownMessageWithId:(NSData *)messageId {
    return [self singleEntityNamed:@"Message" withPredicate: @"id == %@ AND isOwn == YES", messageId];
}

- (BaseMessage *)messageWithId:(NSData *)messageId {
    return [self singleEntityNamed:@"Message" withPredicate: @"id == %@", messageId];
}

- (BaseMessage *)messageWithId:(NSData *)messageId conversation:(Conversation *)conversation {
    return [self singleEntityNamed:@"Message" withPredicate: @"id == %@ AND conversation == %@", messageId, conversation];
}

- (NSArray *)quoteMessagesContaining:(NSString *)searchText message:(BaseMessage *)message inConversation:(Conversation *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    NSArray *textMessages = [self entitiesNamed:@"TextMessage" fetchLimit:0 sortedBy:sortDescriptors withPredicate: @"text contains[cd] %@ AND conversation == %@ && date < %@", searchText, conversation, message.date];
    NSArray *imageMessages = [self entitiesNamed:@"ImageMessage" fetchLimit:0 sortedBy:sortDescriptors withPredicate: @"conversation == %@ && date < %@", conversation, message.date];
    NSArray *fileMessages = [self entitiesNamed:@"FileMessage" fetchLimit:0 sortedBy:sortDescriptors withPredicate: @"conversation == %@ && date < %@", conversation, message.date];
    NSArray *locationMessages = [self entitiesNamed:@"LocationMessage" fetchLimit:0 sortedBy:sortDescriptors withPredicate: @"conversation == %@ && date < %@", conversation, message.date];
    
    if (imageMessages.count > 0 || fileMessages.count > 0 || locationMessages.count > 0) {
        NSMutableArray *allMessages = [NSMutableArray arrayWithArray:textMessages];
        [allMessages addObjectsFromArray:imageMessages];
        [allMessages addObjectsFromArray:fileMessages];
        [allMessages addObjectsFromArray:locationMessages];
        
        NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
        [allMessages sortUsingDescriptors:(NSArray *)sortDescriptors];
        return allMessages;
    } else {
        return textMessages;
    }
}

- (NSArray *)messagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation {
    NSArray *textMessages = [self textMessagesContaining:searchText inConversation:conversation fetchLimit:0];
    NSArray *ballotMessages = [self ballotMessagesContaining:searchText inConversation:conversation fetchLimit:0];
    NSArray *fileMessages = [self fileMessagesContaining:searchText inConversation:conversation fetchLimit:0];
    
    if ([ballotMessages count] > 0 || [fileMessages count] > 0) {
        NSMutableArray *allMessages = [NSMutableArray arrayWithArray:textMessages];
        [allMessages addObjectsFromArray:ballotMessages];
        [allMessages addObjectsFromArray:fileMessages];
        
        NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
        [allMessages sortUsingDescriptors:(NSArray *)sortDescriptors];
        return allMessages;
    } else {
        return textMessages;
    }
}

- (NSArray *)textMessagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    return [self entitiesNamed:@"TextMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"text contains[cd] %@ AND conversation == %@", searchText, conversation];
}

- (NSArray *)ballotMessagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    return [self entitiesNamed:@"BallotMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"ballot.title contains[cd] %@ AND conversation == %@", searchText, conversation];
}

- (NSArray *)fileMessagesContaining:(NSString *)searchText inConversation:(Conversation *)conversation fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    return [self entitiesNamed:@"FileMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"fileName contains[cd] %@ AND conversation == %@", searchText, conversation];
}

- (Conversation *)conversationForGroupId:(NSData *)groupId {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"groupId == %@", groupId];
}

- (Conversation *)conversationForContact:(Contact *)contact {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"contact == %@ AND groupId == nil", contact];
}

- (Conversation *)conversationForIdentity:(NSString *)identity {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"contact.identity == %@ AND groupId == nil", identity];
}

- (NSArray *)conversationsForMember:(Contact *)contact {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate: @"%@ IN members", contact];
}

- (Conversation *)conversationForGroupMessage:(AbstractGroupMessage *)message {
    /* is this a group that we started? */
    if ([message.groupCreator isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        return [self singleEntityNamed:@"Conversation" withPredicate: @"contact == nil AND groupId == %@", message.groupId];
    } else {
        return [self singleEntityNamed:@"Conversation" withPredicate: @"contact.identity == %@ AND groupId == %@", message.groupCreator, message.groupId];
    }
}

- (Contact *)contactForId:(NSString *)identity {
    return [self singleEntityNamed:@"Contact" withPredicate: @"identity == %@", identity];
}

- (Contact *)contactForId:(NSString *)identity error:(NSError **)error {
    NSError *err;
    Contact *contact = [self singleEntityNamed:@"Contact" error:&err withPredicate:@"identity == %@", identity];
    if (err) {
        *error = err;
        return nil;
    } else {
        return contact;
    }
}

- (NSArray *)allContacts {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate:nil];
}

- (NSArray *)allGatewayContacts {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: @"identity beginswith '*'"];
}

- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: @"verificationLevel == %@", [NSNumber numberWithInteger:verificationLevel]];
}

- (NSArray *)contactsWithFeatureMaskNil {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: @"featureLevel == nil"];
}
    
- (NSArray *)contactsFilteredByWords:(NSArray *)searchWords {
    NSMutableArray *predicates = [NSMutableArray array];
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state == %d", kStateActive];
        [predicates addObject:predicate];
    }

    for (NSString *searchWord in searchWords) {
        if (searchWord.length > 0) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"firstName contains[cd] %@ or lastName contains[cd] %@ or identity contains[c] %@ or publicNickname contains[cd] %@", searchWord, searchWord, searchWord, searchWord];
            [predicates addObject:predicate];
        }
    }

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Contact"];
    [fetchRequest setFetchBatchSize:100];
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];

    NSArray *sortDescriptors = [self nameSortDescriptors];
    [fetchRequest setSortDescriptors:sortDescriptors];

    return [self executeFetchRequest:fetchRequest];
}

- (NSArray *)contactsFilteredByWords:(NSArray *)searchWords forContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members {
    NSMutableArray *predicates = [NSMutableArray array];
    
    if (types == ContactsNoGateway) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not identity beginswith '*'"];
        [predicates addObject:predicate];
    } else if (types == ContactsNoEchoEcho) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not identity beginswith 'ECHOECHO'"];
        [predicates addObject:predicate];
    }
    else if (types == ContactsGatewayOnly) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identity beginswith '*'"];
        [predicates addObject:predicate];
    } else if (types == ContactsNoGatewayNoEchoecho) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not identity beginswith '*'"];
        [predicates addObject:predicate];
        predicate = [NSPredicate predicateWithFormat:@"not identity BEGINSWITH 'ECHOECHO'"];
        [predicates addObject:predicate];
    }
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state == %d", kStateActive];
        [predicates addObject:predicate];
    }
    
    if (contactList == ContactListWork) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"workContact == %@", @1];
        [predicates addObject:predicate];
    } else {
        if (contactList == ContactListContacts) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"workContact == %@", @0];
            [predicates addObject:predicate];
        }
    }
    
    for (NSString *searchWord in searchWords) {
        if (searchWord.length > 0) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"firstName contains[cd] %@ or lastName contains[cd] %@ or identity contains[c] %@ or publicNickname contains[cd] %@", searchWord, searchWord, searchWord, searchWord];
            [predicates addObject:predicate];
        }
    }
    
    NSMutableArray *allPredicates = [NSMutableArray array];
    [allPredicates addObject:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        if (members.count > 0) {
            for (Contact *contact in members) {
                NSMutableArray *andPredicates = [NSMutableArray array];
                NSPredicate *memberPredicate = [NSPredicate predicateWithFormat:@"identity == %@", contact.identity];
                [andPredicates addObject:memberPredicate];
                for (NSString *searchWord in searchWords) {
                    if (searchWord.length > 0) {
                        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"firstName contains[cd] %@ or lastName contains[cd] %@ or identity contains[c] %@ or publicNickname contains[cd] %@", searchWord, searchWord, searchWord, searchWord];
                        [andPredicates addObject:searchPredicate];
                    }
                }
                [allPredicates addObject:[NSCompoundPredicate andPredicateWithSubpredicates:andPredicates]];
            }
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Contact"];
    [fetchRequest setFetchBatchSize:100];
    [fetchRequest setPredicate:[NSCompoundPredicate orPredicateWithSubpredicates:allPredicates]];
    
    NSArray *sortDescriptors = [self nameSortDescriptors];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    return [self executeFetchRequest:fetchRequest];
}

- (NSArray *)allGroupConversations {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"groupName" ascending:YES]];
    
    return [self allEntitiesNamed:@"Conversation" sortedBy:sortDescriptors withPredicate:@"groupId != nil"];
}

- (NSArray *)groupConversationsForContact:(Contact *)contact {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ IN members", contact, contact];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Conversation"];
    fetchRequest.predicate = predicate;
    
    return [self executeFetchRequest:fetchRequest];
}

- (NSArray *)groupConversationsFilteredByWords:(NSArray *)searchWords {
    NSMutableArray *predicates = [NSMutableArray array];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"groupId != nil"];
    [predicates addObject:predicate];
    
    for (NSString *searchWord in searchWords) {
        if (searchWord.length > 0) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"groupName contains[cd] %@", searchWord];
            [predicates addObject:predicate];
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Conversation"];
    [fetchRequest setFetchBatchSize:100];
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    return [self executeFetchRequest:fetchRequest];
}

- (NSArray *)allConversations {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:nil];
}

- (NSArray *)allConversationsSorted {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"marked" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"lastMessage.date" ascending:NO]];
    return [self allEntitiesNamed:@"Conversation" sortedBy:sortDescriptors withPredicate:nil];
}

- (NSArray *)conversationsWithNegativeUnreadMessageCount {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:@"unreadMessageCount == %@", [NSNumber numberWithInt:-1]];
}

- (NSString *)displayNameForContactId:(NSString *)identity {
    /* Is this our own identity? */
    if ([identity isEqual:[MyIdentityStore sharedMyIdentityStore].identity])
        return [BundleUtil localizedStringForKey:@"me"];
    
    Contact *contact = [self contactForId:identity];
    if (contact == nil) {
        return identity;
    }
    
    return contact.displayName;
}

- (Ballot *)ballotForBallotId:(NSData *)ballotId {
    return [self singleEntityNamed:@"Ballot" withPredicate: @"id == %@", ballotId];
}

- (NSInteger)countBallotsForConversation:(Conversation *)conversation {
    return [self countEntityNamed:@"Ballot" withPredicate:@"conversation == %@", conversation];
}

- (NSInteger)countOpenBallotsForConversation:(Conversation *)conversation {
    return [self countEntityNamed:@"Ballot" withPredicate:@"conversation == %@ && state == %d", conversation, kBallotStateOpen];
}

- (NSInteger)countMediaMessagesForConversation:(Conversation *)conversation {
    NSInteger numImages = [self countEntityNamed:@"ImageMessage" withPredicate:@"conversation == %@", conversation];
    NSInteger numVideos = [self countEntityNamed:@"VideoMessage" withPredicate:@"conversation == %@", conversation];
    NSInteger numFiles = [self countEntityNamed:@"FileMessage" withPredicate:@"conversation == %@", conversation];

    return numImages + numVideos + numFiles;
}

- (NSArray *)imageMessagesForConversation:(Conversation *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"ImageMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@", conversation];
}

- (NSArray *)videoMessagesForConversation:(Conversation *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"VideoMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@", conversation];
}

- (NSArray *)fileMessagesForConversation:(Conversation *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"FileMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@", conversation];
}

- (NSArray *)fileMessagesWOStickersForConversation:(Conversation *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"FileMessage" sortedBy:sortDescriptors withPredicate:@"(conversation == %@) AND (type != 2)", conversation];
}


- (BallotChoice *)ballotChoiceForBallotId:(NSData *)ballotId choiceId:(NSNumber *)choiceId {
    return [self singleEntityNamed:@"BallotChoice" withPredicate: @"id == %@ AND ballot.id == %@", choiceId, ballotId];
}


- (BOOL)isMessageAlreadyInDb:(AbstractMessage *)message {
    id result;
    
    if ([message isKindOfClass:[AbstractGroupMessage class]]) {
        result = [self singleEntityNamed:@"Message" withPredicate:@"id == %@ AND sender.identity == %@",
                  message.messageId, message.fromIdentity];
    } else {
        result = [self singleEntityNamed:@"Message" withPredicate:@"id == %@ AND conversation.contact.identity == %@",
                  message.messageId, message.fromIdentity];
    }
    
    
    return result != nil;
}

- (BOOL)isNonceAlreadyInDb:(AbstractMessage *)message {
    id result;
    
    NSData *hashedNonce = [NonceHasher hashedNonce:message.nonce];
    result = [self singleEntityNamed:@"Nonce" withPredicate:@"nonce == %@ OR nonce == %@", message.nonce, hashedNonce];
    
    return result != nil;
}

- (Group *)groupForGroupId:(NSData *)groupId groupCreator:(NSString *)groupCreator {
    return [self singleEntityNamed:@"Group" withPredicate: @"groupId == %@ AND groupCreator == %@", groupId, groupCreator];
}

- (Group *)groupForConversation:(Conversation *)conversation {
    /* is this a group that we started? */
    if (conversation.isGroup) {
        if (conversation.contact) {
            return [self singleEntityNamed:@"Group" withPredicate: @"groupId == %@ AND groupCreator == %@", conversation.groupId, conversation.contact.identity];
        } else {
            return [self singleEntityNamed:@"Group" withPredicate: @"groupId == %@ AND groupCreator == nil", conversation.groupId];
        }
    }
    
    return nil;
}

- (LastGroupSyncRequest *)lastGroupSyncRequestFor:(NSData *)groupId groupCreator:(NSString *)groupCreator sinceDate:(NSDate *)sinceDate {
    return [self singleEntityNamed:@"LastGroupSyncRequest" withPredicate: @"groupId == %@ AND groupCreator == %@ AND lastSyncRequest >= %@", groupId, groupCreator, sinceDate];
}

- (NSFetchRequest *)fetchRequestForEntity:(NSString *)entityName {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:_managedObjectContext];
    
    return fetchRequest;
}

- (NSArray *)executeFetchRequest:(NSFetchRequest *)fetchRequest {
    __block NSError *error;
    __block NSArray *result;
    [_managedObjectContext performBlockAndWait:^{
        result = [_managedObjectContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    if (result == nil) {
        DDLogError(@"Error in fetch request: %@, %@", error, [error userInfo]);
        return nil;
    } else {
        return result;
    }

}

- (NSInteger)executeCountFetchRequest:(NSFetchRequest *)fetchRequest {
    __block NSError *error;
    __block NSUInteger count;
    [_managedObjectContext performBlockAndWait:^{
        count = [_managedObjectContext countForFetchRequest:fetchRequest error:&error];
    }];
    
    if (count != NSNotFound) {
        return count;
    } else {
        return 0;
    }
}

- (NSArray *)nameSortDescriptors {
    NSArray *sortDescriptors;
    if ([UserSettings sharedUserSettings].sortOrderFirstName) {
        sortDescriptors = @[
                            [NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES],
                            [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES selector:@selector(localizedStandardCompare:)],
                            [NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES selector:@selector(localizedStandardCompare:)],
                            [NSSortDescriptor sortDescriptorWithKey:@"publicNickname" ascending:YES selector:@selector(localizedStandardCompare:)]
                            ];
    } else {
        sortDescriptors = @[
                            [NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES],
                            [NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES selector:@selector(localizedStandardCompare:)],
                            [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:YES selector:@selector(localizedStandardCompare:)],
                            [NSSortDescriptor sortDescriptorWithKey:@"publicNickname" ascending:YES selector:@selector(localizedStandardCompare:)]
                            ];
    }
    
    return sortDescriptors;
}

- (NSFetchedResultsController *)fetchedResultsControllerForContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:100];
    
    NSMutableArray *predicates = [NSMutableArray array];
    
    if (types == ContactsNoGateway) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not identity beginswith '*'"];
        [predicates addObject:predicate];
    } else if (types == ContactsNoEchoEcho) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not identity beginswith 'ECHOECHO'"];
        [predicates addObject:predicate];
    } else if (types == ContactsGatewayOnly) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identity beginswith '*'"];
        [predicates addObject:predicate];
    } else if (types == ContactsNoGatewayNoEchoecho) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not identity beginswith '*'"];
        [predicates addObject:predicate];
        predicate = [NSPredicate predicateWithFormat:@"not identity beginswith 'ECHOECHO'"];
        [predicates addObject:predicate];
    }
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state == %d", kStateActive];
        [predicates addObject:predicate];
    }
    
    if (contactList == ContactListWork) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"workContact == %@ ", @1];
        [predicates addObject:predicate];
    } else {
        if (contactList == ContactListContactsAndWork) {
            // do not predicate for work contacts
        } else {
            if ([LicenseStore requiresLicenseKey]) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"workContact == %@ ", @0];
                [predicates addObject:predicate];
            }
        }
    }
    
    NSMutableArray *allPredicates = [NSMutableArray array];
    [allPredicates addObject:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        if (members.count > 0) {
            for (Contact *contact in members) {
                NSPredicate *memberPredicate = [NSPredicate predicateWithFormat:@"identity == %@", contact.identity];
                [allPredicates addObject:memberPredicate];
            }
        }
    }
    
    [fetchRequest setPredicate:[NSCompoundPredicate orPredicateWithSubpredicates:allPredicates]];

    NSArray *sortDescriptors = [self nameSortDescriptors];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:@"sortIndex" cacheName:nil];
    
    return fetchedResultsController;
}

- (NSFetchedResultsController *)fetchedResultsControllerForGroups {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"groupId != nil"];

    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"groupName" ascending:YES]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    return fetchedResultsController;
}

- (NSFetchedResultsController *)fetchedResultsControllerForConversations {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];

    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"marked" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"lastMessage.date" ascending:NO]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];

    return fetchedResultsController;
}

- (NSFetchedResultsController *)fetchedResultsControllerForWebClientSessions {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"WebClientSession" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"active" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"lastConnection" ascending:NO]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    return fetchedResultsController;
}

- (WebClientSession *)webClientSessionForInitiatorPermanentPublicKeyHash:(NSString *)hash {
    return [self singleEntityNamed:@"WebClientSession" withPredicate:@"initiatorPermanentPublicKeyHash == %@", hash];
}

- (WebClientSession *)webClientSessionForPrivateKey:(NSData *)privateKey {
    return [self singleEntityNamed:@"WebClientSession" withPredicate:@"privateKey == %@", privateKey];
}

- (WebClientSession *)activeWebClientSession {
    return [self singleEntityNamed:@"WebClientSession" withPredicate:@"active == YES"];
}

- (NSArray *)allWebClientSessions {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastConnection" ascending:YES]];
    return [self allEntitiesNamed:@"WebClientSession" sortedBy:sortDescriptors withPredicate:nil];
}

- (NSArray *)allActiveWebClientSessions {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastConnection" ascending:YES]];
    return [self allEntitiesNamed:@"WebClientSession" sortedBy:sortDescriptors withPredicate:@"active == YES"];
}

- (NSArray *)allNotPermanentWebClientSessions {
    return [self allEntitiesNamed:@"WebClientSession" sortedBy:nil withPredicate:@"permanent == NO"];
}


#pragma mark - private

- (NSInteger)countEntityNamed:(NSString *)name withPredicate:(NSString *) predicate, ... {
    va_list args;
    va_start(args, predicate);
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:name inManagedObjectContext:_managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:predicate arguments: args];
    
    return [self executeCountFetchRequest: fetchRequest];
}

- (id)singleEntityNamed:(NSString *)name withPredicate:(NSString *) predicate, ... {
    va_list args;
    va_start(args, predicate);
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:name inManagedObjectContext:_managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:predicate arguments: args];
    fetchRequest.fetchLimit = 1;
    
    NSArray *result = [self executeFetchRequest:fetchRequest];
    
    if (result != nil && [result count] > 0) {
        return [result objectAtIndex: 0];
    } else {
        return nil;
    }
}

- (id)singleEntityNamed:(NSString *)name error:(NSError **)error withPredicate:(NSString *) predicate, ... {
    va_list args;
    va_start(args, predicate);
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:name inManagedObjectContext:_managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:predicate arguments: args];
    fetchRequest.fetchLimit = 1;
    
    NSArray *result = [self executeFetchRequest:fetchRequest];
    
    if (result == nil) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(@"Operation was unsuccessful.", nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"The operation timed out.", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Have you tried turning it off and on again?", nil)
                                   };
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-57 userInfo:userInfo];
        return nil;
    } else {
        if ( [result count] > 0) {
            return [result objectAtIndex: 0];
        } else {
            return nil;
        }
    }
}

- (NSArray *)entitiesNamed:(NSString *)name fetchLimit:(NSInteger)fetchLimit sortedBy:(NSArray *)sortDescriptors withPredicate:(NSString *) predicate, ... {
    va_list args;
    va_start(args, predicate);
    
    return [self entitiesNamed:name fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate:predicate arguments:args];
}

- (NSArray *)allEntitiesNamed:(NSString *)name sortedBy:(NSArray *)sortDescriptors withPredicate:(NSString *) predicate, ... {
    va_list args;
    va_start(args, predicate);
    
    return [self entitiesNamed:name fetchLimit:0 sortedBy:sortDescriptors withPredicate:predicate arguments:args];
}

- (NSArray *)entitiesNamed:(NSString *)name fetchLimit:(NSInteger)fetchLimit sortedBy:(NSArray *)sortDescriptors withPredicate:(NSString *) predicate arguments:(va_list)args {
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:name inManagedObjectContext:_managedObjectContext];
    
    if (fetchLimit > 0) {
        fetchRequest.fetchLimit = fetchLimit;
    }
    
    if (predicate) {
        fetchRequest.predicate = [NSPredicate predicateWithFormat:predicate arguments: args];
    }
    
    if (sortDescriptors) {
        fetchRequest.sortDescriptors = sortDescriptors;
    }
    
    return [self executeFetchRequest:fetchRequest];
}

- (Tag *)tagForName:(NSString *)name {
    return [self singleEntityNamed:@"Tag" withPredicate:@"name == %@", name];
}

@end
