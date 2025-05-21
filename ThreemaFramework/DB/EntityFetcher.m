//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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
#import "UserSettings.h"
#import "BundleUtil.h"
#import "LicenseStore.h"
#import "NonceHasher.h"
#import "UTIConverter.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface EntityFetcher ()

@end

@implementation EntityFetcher {
    id<MyIdentityStoreProtocol> myIdentityStore;
}

- (instancetype)initWith:(NSManagedObjectContext *) managedObjectContext myIdentityStore:(id<MyIdentityStoreProtocol>)myIdentityStore {
    self = [super init];
    if (self) {
        _managedObjectContext = managedObjectContext;
        self->myIdentityStore = myIdentityStore;
    }
    return self;
}

- (__kindof NSManagedObject *)getManagedObjectById:(NSManagedObjectID *)objectID {
    return [_managedObjectContext objectWithID: objectID];
}

- (__kindof NSManagedObject *)existingObjectWithID:(nonnull NSManagedObjectID *)objectID {
    NSError *error;
    
    NSManagedObject *managedObject = [_managedObjectContext existingObjectWithID:objectID error:&error];
    
    if (error != nil) {
        DDLogError(@"Unable to load existing object: %@", error.localizedDescription);
        return nil;
    }
    
    return managedObject;
}

- (__kindof NSManagedObject *)existingObjectWithIDString:(NSString *)objectIDString {
    NSError *error;
    
    NSURL *url = [NSURL URLWithString:objectIDString];
    NSManagedObjectID *objectID = [[_managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:url];
    NSManagedObject *managedObject = [_managedObjectContext existingObjectWithID:objectID error:&error];
    
    if (error != nil) {
        DDLogError(@"Unable to load existing object: %@", error.localizedDescription);
        return nil;
    }
    
    return managedObject;
}

- (BaseMessageEntity *)ownMessageWithId:(NSData *)messageId conversationEntity:(ConversationEntity *)conversation {
    return [self singleEntityNamed:@"Message" withPredicate: @"id == %@ AND conversation == %@ AND isOwn == YES", messageId, conversation];
}

- (BaseMessageEntity *)messageWithId:(NSData *)messageId conversationEntity:(ConversationEntity *)conversation {
    return [self singleEntityNamed:@"Message" withPredicate: @"id == %@ AND conversation == %@", messageId, conversation];
}

- (NSArray *)quoteMessagesContaining:(NSString *)searchText message:(BaseMessageEntity *)message inConversationEntity:(ConversationEntity *)conversation {
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

/// Returns all text, ballot, location and file messages containing the text in search text.
/// Check the exact implementation on how text is matched for ballot and file messages
///
/// This might have room for optimization when sorting items since we have three already sorted arrays we should be able to "simply" combine them instead of sorting them again.
/// We might additionally be able to fetch the three kinds of times in parallel since these are independent fetch requests.
/// - Parameters:
///   - searchText: The text to search for
///   - conversation: The conversation to search in
///   - fetchLimit: The maximum number of items to fetch for each kind of item. This currently results in |{textMessages U ballotMessages U fileMessages}| items, i.e. no more than 3 times the fetchLimit.
- (NSArray *)messagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *textMessages = [self textMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    NSArray *ballotMessages = [self ballotMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    NSArray *fileMessages = [self fileMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    NSArray *locationMessages = [self locationMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    
    if ([ballotMessages count] > 0 || [fileMessages count] > 0 || [locationMessages count] > 0) {
        NSMutableArray *allMessages = [NSMutableArray arrayWithArray:textMessages];
        [allMessages addObjectsFromArray:ballotMessages];
        [allMessages addObjectsFromArray:fileMessages];
        [allMessages addObjectsFromArray:locationMessages];
        
        NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
        [allMessages sortUsingDescriptors:(NSArray *)sortDescriptors];
        return allMessages;
    } else {
        return textMessages;
    }
}

- (NSArray *)textMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"text contains[cd] %@ && conversation.category != %d", searchText, ConversationCategoryPrivate];
        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"TextMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }
    return [self entitiesNamed:@"TextMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"text contains[cd] %@ AND conversation == %@", searchText, conversation];
}

- (NSArray *)ballotMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ballot.title contains[cd] %@ && conversation.category != %d", searchText, ConversationCategoryPrivate];
        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"BallotMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }
    return [self entitiesNamed:@"BallotMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"ballot.title contains[cd] %@ AND conversation == %@", searchText, conversation];
}

- (NSArray *)fileMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileName contains[cd] %@ || caption contains[cd] %@) && conversation.category != %d", searchText, searchText, ConversationCategoryPrivate];

        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"FileMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }
    return [self entitiesNamed:@"FileMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"(fileName contains[cd] %@ || caption contains[cd] %@) AND conversation == %@", searchText, searchText, conversation];
}

- (NSArray *)locationMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(poiName contains[cd] %@ || poiAddress contains[cd] %@) && conversation.category != %d", searchText, searchText, ConversationCategoryPrivate];

        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"LocationMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }
    return [self entitiesNamed:@"LocationMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"(poiName contains[cd] %@ || poiAddress contains[cd] %@) AND conversation == %@", searchText, searchText, conversation];
}


/// Returns all text, ballot, location and file messages containing the text in search text that are starred.
/// Check the exact implementation on how text is matched for ballot and file messages
///
/// This might have room for optimization when sorting items since we have three already sorted arrays we should be able to "simply" combine them instead of sorting them again.
/// We might additionally be able to fetch the three kinds of times in parallel since these are independent fetch requests.
/// - Parameters:
///   - searchText: The text to search for
///   - conversation: The conversation to search in
///   - fetchLimit: The maximum number of items to fetch for each kind of item. This currently results in |{textMessages U ballotMessages U fileMessages}| items, i.e. no more than 3 times the fetchLimit.
- (NSArray *)starredMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *textMessages = [self starredTextMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    NSArray *ballotMessages = [self starredBallotMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    NSArray *fileMessages = [self starredFileMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    NSArray *locationMessages = [self starredLocationMessagesContaining:searchText inConversationEntity:conversation filterPredicate:filterPredicate fetchLimit:fetchLimit];
    
    if ([ballotMessages count] > 0 || [fileMessages count] > 0 || [locationMessages count] > 0) {
        NSMutableArray *allMessages = [NSMutableArray arrayWithArray:textMessages];
        [allMessages addObjectsFromArray:ballotMessages];
        [allMessages addObjectsFromArray:fileMessages];
        [allMessages addObjectsFromArray:locationMessages];
        
        NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
        [allMessages sortUsingDescriptors:(NSArray *)sortDescriptors];
        return allMessages;
    } else {
        return textMessages;
    }
}

- (NSArray *)starredTextMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"text contains[cd] %@ && conversation.category != %d", searchText, ConversationCategoryPrivate];
        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"TextMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }
    if (searchText.length == 0) {
        return [self entitiesNamed:@"TextMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"conversation == %@ AND messageMarkers.star == 1", conversation];
    }
    else {
        return [self entitiesNamed:@"TextMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"text contains[cd] %@ AND conversation == %@ AND messageMarkers.star == 1", searchText, conversation];
    }
}

- (NSArray *)starredBallotMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ballot.title contains[cd] %@ && conversation.category != %d", searchText, ConversationCategoryPrivate];
        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"BallotMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }

    if (searchText.length == 0) {
        return [self entitiesNamed:@"BallotMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"conversation == %@ AND messageMarkers.star == 1", conversation];
    }
    else {
        return [self entitiesNamed:@"BallotMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"ballot.title contains[cd] %@ AND conversation == %@ AND messageMarkers.star == 1", searchText, conversation];
    }
}

- (NSArray *)starredFileMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(fileName contains[cd] %@ || caption contains[cd] %@) && conversation.category != %d", searchText, searchText, ConversationCategoryPrivate];

        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"FileMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }

    if (searchText.length == 0) {
        return [self entitiesNamed:@"FileMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"conversation == %@ AND messageMarkers.star == 1", conversation];}
    else {
        return [self entitiesNamed:@"FileMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"(fileName contains[cd] %@ || caption contains[cd] %@) AND conversation == %@ AND messageMarkers.star == 1", searchText, searchText, conversation];
    }
}

- (NSArray *)starredLocationMessagesContaining:(NSString *)searchText inConversationEntity:(ConversationEntity *)conversation filterPredicate:(NSPredicate *)filterPredicate fetchLimit:(NSInteger)fetchLimit {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]];
    
    if (conversation == nil) {
        // Used for global search. Do not search in private chats
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(poiName contains[cd] %@ || poiAddress contains[cd] %@) && conversation.category != %d", searchText, searchText, ConversationCategoryPrivate];

        NSPredicate *compoundPredicate = filterPredicate == nil ? predicate : [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, filterPredicate]];
        return [self entitiesNamed:@"LocationMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: compoundPredicate.predicateFormat];
    }

    if (searchText.length == 0) {
        return [self entitiesNamed:@"LocationMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"conversation == %@ AND messageMarkers.star == 1", conversation];}
    else {
        return [self entitiesNamed:@"LocationMessage" fetchLimit:fetchLimit sortedBy:sortDescriptors withPredicate: @"(poiName contains[cd] %@ || poiAddress contains[cd] %@) AND conversation == %@ AND messageMarkers.star == 1", searchText, conversation];
    }
}

- (ConversationEntity *)conversationEntityForContact:(ContactEntity *)contact {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"contact == %@ AND groupId == nil", contact];
}

- (ConversationEntity *)conversationEntityForIdentity:(NSString *)identity {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"contact.identity == %@ AND groupId == nil", identity];
}

- (ConversationEntity *)conversationEntityForDistributionList:(DistributionListEntity *)distributionList {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"distributionList.distributionListID == %@", distributionList.distributionListIDObjC];
}

- (NSArray *)conversationsForMember:(ContactEntity *)contact {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate: @"%@ IN members", contact];
}

- (ConversationEntity *)conversationEntityForGroupMessage:(AbstractGroupMessage *)message {
    /* is this a group that we started? */
    return [self conversationEntityForGroupId:message.groupId creator:message.groupCreator];
}

- (ConversationEntity *)conversationEntityForGroupId:(NSData *)groupId creator:(NSString *)creator {
    if ([creator isEqualToString:[self->myIdentityStore identity]]) {
        return [self singleEntityNamed:@"Conversation" withPredicate: @"contact == nil AND groupId == %@", groupId];
    } else {
        return [self singleEntityNamed:@"Conversation" withPredicate: @"contact.identity == %@ AND groupId == %@", creator, groupId];
    }
}

- (ConversationEntity *)conversationEntityForDistributionListID:(NSNumber *)distributionListID  {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"distributionList.distributionListID == %@", distributionListID];
}

- (ContactEntity *)contactForId:(NSString *)identity {
    return [self singleEntityNamed:@"Contact" withPredicate: @"identity == %@", identity];
}

- (ContactEntity *)contactForId:(NSString *)identity error:(NSError **)error {
    NSError *err;
    ContactEntity *contact = [self singleEntityNamed:@"Contact" error:&err withPredicate:@"identity == %@", identity];
    if (err) {
        *error = err;
        return nil;
    } else {
        return contact;
    }
}

- (NSArray *)allContactsForID:(NSString *)identity {
    return [self allEntitiesNamed:@"Contact" sortedBy: nil withPredicate: @"identity == %@", identity];
}

- (NSArray *)allContacts {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate:nil];
}

// This is about 3x faster than loading all contacts and then getting their identities
- (nonnull NSSet<NSString *> *)allContactIdentities {
    NSString *entityName = @"Contact";
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];

    NSString *propertyKey = @"identity";
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.propertiesToFetch = [NSArray arrayWithObject:[[entity propertiesByName] objectForKey:propertyKey]];
    fetchRequest.returnsDistinctResults = YES;
    
    NSArray *fetchedIdentities = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    NSMutableSet *allIdentities = [[NSMutableSet alloc] initWithCapacity:fetchedIdentities.count];
    for (NSDictionary<NSString *, NSString *> *fetchedIdentity in fetchedIdentities) {
        [allIdentities addObject:fetchedIdentity[propertyKey]];
    }
    
    return allIdentities;
}

// This implements the following protocol specification which are part of the _Application Setup Steps_:
// 1. If the `contact`'s activity state is _invalid_ (i.e. it does not
//    exist or has been revoked), remove `contact` from the list.
// 2. If `contact` is part of a group that is not marked as _left_, add
//    `contact` to the list and abort these sub-steps.
// 3. Lookup the 1:1 conversation with `contact` and let `last-update`
//    be the associated _last update_ timestamp.
// 4. If `last-update` is defined, add `contact` to the list and abort
//    these sub-steps.
// 5. Remove `contact` from the list.
//
// We need multiple and complex queries because there's a to many relation ship between `Contact`s `conversations` & 
// `Conversation` and because there is no CD relation between `Group` and `Conversation`
// (see `allActiveGroupConversations` for details).
//
// If this doesn't perform well:
// 1. Check query plans using the CD debug flags and see if a query can be optimized or a Fetch Index added (there is
//    already one)
// 2. Try loading all valid contacts and filtering them by iterating over them. Idea: Use a set of already matched
//    identities and add all group members if you fetch an active group. Then you can skip contacts already in there to 
//    prevent some CD fetches.
// 3. Get creative...
- (nonnull NSSet<NSString *> *)allSolicitedContactIdentities {
    // Fetch relevant conversations
    NSArray *nonGroupConversationsWithLastUpdate = [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:@"groupId == nil AND lastUpdate != nil"];
    NSArray<ConversationEntity *> *allActiveGroupConversations = [self allActiveGroupConversations];

    // Prepare predicates
    
    NSPredicate *validContactsOnly = [NSPredicate predicateWithFormat:@"state != %d", ContactStateInvalid];
    
    NSPredicate *contactsWithActiveOneToOneConversation = [NSPredicate predicateWithFormat:@"SUBQUERY(conversations, $conversation, $conversation IN %@).@count > 0", nonGroupConversationsWithLastUpdate];
    NSPredicate *contactsWithActiveGroupConversation = [NSPredicate predicateWithFormat:@"SUBQUERY(groupConversations, $conversation, $conversation IN %@).@count > 0", allActiveGroupConversations];
    
    NSCompoundPredicate *conversationsPredicates = [NSCompoundPredicate orPredicateWithSubpredicates:@[contactsWithActiveOneToOneConversation, contactsWithActiveGroupConversation]];
    
    // Prepare contact fetch request
        
    NSString *entityName = @"Contact";
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[validContactsOnly, conversationsPredicates]];
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.managedObjectContext];
    
    NSString *propertyKey = @"identity";
    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.propertiesToFetch = [NSArray arrayWithObject:[[entity propertiesByName] objectForKey:propertyKey]];
    fetchRequest.returnsDistinctResults = YES;
    
    // Fetch!
    
    NSArray *fetchedIdentities = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    
    // Map
    
    NSMutableSet *allIdentities = [[NSMutableSet alloc] initWithCapacity:fetchedIdentities.count];
    for (NSDictionary<NSString *, NSString *> *fetchedIdentity in fetchedIdentities) {
        [allIdentities addObject:fetchedIdentity[propertyKey]];
    }
    
    return allIdentities;
}

// Private workaround to get all active group conversations
//
// Because there is no relationship between `Conversation` and `Group` and the group `state` is part of `Group` we have 
// to load all active groups and group conversations and then match them against each other.
//
// This is private for now, but might be made public in the future if it is needed in another place.
- (nonnull NSArray<ConversationEntity *> *)allActiveGroupConversations {
    NSArray *allActiveGroups = [self allActiveGroups];

    if (allActiveGroups.count == 0) {
        return [[NSArray alloc] init];
    }
    
    NSString *groupIdentityFormatString = @"%@-%@";
    
    NSMutableSet<NSString *> *allActiveGroupIDsAndCreators = [[NSMutableSet alloc] initWithCapacity:allActiveGroups.count];
    for (GroupEntity *group in allActiveGroups) {
        NSString *idAndCreator = nil;
        if (group.groupCreator != nil) {
            idAndCreator = [NSString stringWithFormat:groupIdentityFormatString, group.groupId, group.groupCreator];
        }
        else {
            idAndCreator = [NSString stringWithFormat:groupIdentityFormatString, group.groupId, myIdentityStore.identity];
        }
        
        [allActiveGroupIDsAndCreators addObject:idAndCreator];
    }
    
    // All group conversations
    NSArray *allGroupConversations = [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:@"groupId != nil"];
    
    if (allGroupConversations == nil || allGroupConversations.count == 0) {
        return [[NSArray alloc] init];
    }
    
    NSMutableArray<ConversationEntity *> *allActiveGroupConversations = [[NSMutableArray alloc] initWithCapacity:allActiveGroupIDsAndCreators.count];
    for (ConversationEntity *conversation in allGroupConversations) {
        NSString *idAndCreator = nil;
        if (conversation.contact != nil) {
            idAndCreator = [NSString stringWithFormat:groupIdentityFormatString, conversation.groupId, conversation.contact.identity];
        }
        else {
            idAndCreator = [NSString stringWithFormat:groupIdentityFormatString, conversation.groupId, myIdentityStore.identity];
        }
        
        if ([allActiveGroupIDsAndCreators containsObject:idAndCreator]) {
            [allActiveGroupConversations addObject:conversation];
        }
    }
    
    return allActiveGroupConversations;
}

- (NSArray *)allGatewayContacts {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: @"identity beginswith '*'"];
}

- (NSArray *)contactsWithVerificationLevel:(NSInteger)verificationLevel {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: @"verificationLevel == %@", [NSNumber numberWithInteger:verificationLevel]];
}

- (NSArray<ContactEntity *> *)contactsWithFeatureMaskNil {
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: @"featureMask == nil"];
}
    
- (NSArray *)contactsWithCustomReadReceipt {
    NSString *predicate = [NSString stringWithFormat:@"readReceipts != %ld", (long)ReadReceiptDefault];
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: predicate];
}

- (NSArray *)contactsWithCustomTypingIndicator {
    NSString *predicate = [NSString stringWithFormat:@"typingIndicators != %ld", (long)ReadReceiptDefault];
    return [self allEntitiesNamed:@"Contact" sortedBy:nil withPredicate: predicate];
}


- (NSArray *)contactsFilteredByWords:(NSArray *)searchWords forContactTypes:(ContactTypes)types list:(ContactList)contactList members:(NSMutableSet *)members {
    NSMutableArray *predicates = [NSMutableArray array];
    [predicates addObject:[NSPredicate predicateWithFormat:@"hidden == nil OR hidden == 0"]];

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
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state == %d", ContactStateActive];
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
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"firstName contains[cd] %@ or lastName contains[cd] %@ or identity contains[c] %@ or publicNickname contains[cd] %@ or jobTitle contains[cd] %@ or department contains[cd] %@", searchWord, searchWord, searchWord, searchWord, searchWord, searchWord];
            [predicates addObject:predicate];
        }
    }
    
    NSMutableArray *allPredicates = [NSMutableArray array];
    [allPredicates addObject:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        if (members.count > 0) {
            for (ContactEntity *contact in members) {
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

- (ContactEntity *)contactsContainOwnIdentity {
    id result;
    
    result = [self singleEntityNamed:@"Contact" withPredicate:@"identity == %@", myIdentityStore.identity];
    
    return result;
}

- (BOOL)hasDuplicateContactsWithDuplicateIdentities:(NSSet **)duplicateIdentities {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Contact" inManagedObjectContext:self.managedObjectContext];

    fetchRequest.resultType = NSDictionaryResultType;
    fetchRequest.propertiesToFetch = [NSArray arrayWithObject:[[entity propertiesByName] objectForKey:@"identity"]];

    fetchRequest.returnsDistinctResults = NO;
    NSArray *allIdentities = [self.managedObjectContext executeFetchRequest:fetchRequest error:nil];
    NSSet *distinctIdentities = [[NSSet alloc] initWithArray:allIdentities];

    if (allIdentities.count != distinctIdentities.count) {
        NSMutableSet *duplicates = [NSMutableSet set];
        for (NSString *identity in distinctIdentities) {
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF = %@", identity];
            if ([allIdentities filteredArrayUsingPredicate:predicate].count > 1) {
                [duplicates addObject:[identity valueForKey:@"identity"]];
            }
        }
        *duplicateIdentities = duplicates;

        return YES;
    }
    else {
        return NO;
    }
}

- (NSArray *)allGroupConversations {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"groupName" ascending:YES]];
    
    return [self allEntitiesNamed:@"Conversation" sortedBy:sortDescriptors withPredicate:@"groupId != nil"];
}

- (nonnull NSArray<GroupEntity *> *)allActiveGroups {
    NSArray *allActiveGroups = [self allEntitiesNamed:@"Group" sortedBy:nil withPredicate:@"NOT (state == %ld OR state == %ld)", GroupStateLeft, GroupStateForcedLeft];

    if (allActiveGroups == nil) {
        return [[NSArray alloc] init];
    }
    
    return allActiveGroups;
}

- (NSArray *)groupConversationsForContact:(ContactEntity *)contact {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%@ IN members", contact];
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

- (NSArray *)distributionListsFilteredByWords:(NSArray *)searchWords {
    NSMutableArray *predicates = [NSMutableArray array];
    
    for (NSString *searchWord in searchWords) {
        if (searchWord.length > 0) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name contains[cd] %@", searchWord];
            [predicates addObject:predicate];
        }
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"DistributionList"];
    [fetchRequest setFetchBatchSize:100];
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    return [self executeFetchRequest:fetchRequest];
}

- (NSArray *)allConversations {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:nil];
}

- (NSArray *)conversationsWithPredicate:(NSString *)predicate {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:predicate];
}

- (NSArray *)notArchivedConversations {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:@"visibility != %@", [NSNumber numberWithInt:ConversationVisibilityArchived]];
}

- (NSArray *)allMessages {
    return [self allEntitiesNamed:@"Message" sortedBy:nil withPredicate:nil];
}

- (NSArray *)allConversationsSorted {
    return [self allConversationsSortedUnarchivedOnly:false];
}

- (NSArray *)allUnarchivedConversationsSorted {
    return [self allConversationsSortedUnarchivedOnly:true];
}

- (NSArray *)allConversationsSortedUnarchivedOnly:(BOOL)unarchivedOnly {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"visibility" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"lastUpdate" ascending:NO],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastMessage.date" ascending:NO]];
    
    
    if (unarchivedOnly) {
        // fetch only unarchived
        NSString *predicate = [NSString stringWithFormat:@"visibility != %@", [NSNumber numberWithInt:ConversationVisibilityArchived]];
        return [self allEntitiesNamed:@"Conversation" sortedBy:sortDescriptors withPredicate:predicate];
    }
    
    return [self allEntitiesNamed:@"Conversation" sortedBy:sortDescriptors withPredicate:nil];
}

- (NSArray *)conversationsWithNegativeUnreadMessageCount {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:@"unreadMessageCount == %@", [NSNumber numberWithInt:-1]];
}

- (NSArray *)privateConversations {
    return [self allEntitiesNamed:@"Conversation" sortedBy:nil withPredicate:@"category == %@", [NSNumber numberWithInt:ConversationCategoryPrivate]];
}

- (NSString *)displayNameForContactId:(NSString *)identity {
    /* Is this our own identity? */
    if ([identity isEqual:[self->myIdentityStore identity]])
        return [BundleUtil localizedStringForKey:@"me"];
    
    ContactEntity *contact = [self contactForId:identity];
    if (contact == nil) {
        return identity;
    }
    
    return contact.displayName;
}

- (BallotEntity *)ballotEntityForBallotId:(NSData *)ballotId {
    return [self singleEntityNamed:@"Ballot" withPredicate: @"id == %@", ballotId];
}

- (NSInteger)countBallotsForConversationEntity:(ConversationEntity *)conversation {
    return [self countEntityNamed:@"Ballot" withPredicate:@"conversation == %@", conversation];
}

- (NSInteger)countOpenBallotsForConversationEntity:(ConversationEntity *)conversation {
    return [self countEntityNamed:@"Ballot" withPredicate:@"conversation == %@ && state == %d", conversation, BallotStateOpen];
}

- (NSInteger)countMediaMessagesForConversationEntity:(ConversationEntity *)conversation {
    NSInteger numImages = [self countEntityNamed:@"ImageMessage" withPredicate:@"conversation == %@", conversation];
    NSInteger numVideos = [self countEntityNamed:@"VideoMessage" withPredicate:@"conversation == %@", conversation];
    NSInteger numFiles = [self countEntityNamed:@"FileMessage" withPredicate:@"conversation == %@", conversation];

    return numImages + numVideos + numFiles;
}

- (NSInteger)countStarredMessagesInConversationEntity:(ConversationEntity *)conversation {
    return [self countEntityNamed:@"Message" withPredicate:@"conversation == %@ AND messageMarkers.star == 1", conversation];
}

- (NSInteger)countUnreadMessagesForConversationEntity:(ConversationEntity *)conversation {
    return [self countEntityNamed:@"Message" withPredicate:@"isOwn == NO AND read == NO AND conversation == %@ ", conversation];
}

- (NSInteger)countMessagesForContactWithIdentity:(nonnull NSString *)identity {
    return [self countEntityNamed:@"Message" withPredicate:@"sender.identity == %@", identity];
}

- (NSInteger)countMessagesForContact:(nonnull ContactEntity *)contact {
    return [self countEntityNamed:@"Message" withPredicate:@"sender == %@", contact];
}

- (NSInteger)countMessagesForContactEntity:(nonnull ContactEntity *)contact inConversationEntity:(ConversationEntity *)conversation {
    return [self countEntityNamed:@"Message" withPredicate:@"sender == %@ AND conversation == %@", contact, conversation];
}

- (NSArray *)textMessagesForConversationEntity:(ConversationEntity *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"TextMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@", conversation];
}

- (NSArray *)imageMessagesForConversationEntity:(ConversationEntity *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"ImageMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@ AND image.data != nil", conversation];
}

- (NSArray *)videoMessagesForConversationEntity:(ConversationEntity *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"VideoMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@ AND video.data != nil", conversation];
}

- (NSArray *)fileMessagesForConversationEntity:(ConversationEntity *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"FileMessage" sortedBy:sortDescriptors withPredicate:@"conversation == %@", conversation];
}

- (NSArray *)filesMessagesFilteredForPhotoBrowserForConversationEntity:(ConversationEntity *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    
    NSString *gifMimeType = [UTIConverter mimeTypeFromUTI:UTTYPE_GIF_IMAGE];
    NSArray *renderingAudioMimetypes = [UTIConverter renderingAudioMimetypes];
    
    NSMutableArray *filteredMimeTypes = [NSMutableArray arrayWithArray:renderingAudioMimetypes];
    [filteredMimeTypes addObject:gifMimeType];
    
    return [self allEntitiesNamed:@"FileMessage" sortedBy:sortDescriptors withPredicate:@"(conversation == %@) AND (type != 2) AND !(mimeType IN %@) AND data.data != nil", conversation, filteredMimeTypes];
}

- (NSArray *)unreadMessagesForConversationEntity:(ConversationEntity *)conversation {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"Message" sortedBy:sortDescriptors withPredicate:@"isOwn == NO AND read == NO AND conversation == %@ ", conversation];
}

- (BallotChoiceEntity *)ballotChoiceForBallotId:(NSData *)ballotId choiceId:(NSNumber *)choiceId {
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

- (NSArray<NonceEntity *> *)allNonceEntities {
    return [self allEntitiesNamed:@"Nonce" sortedBy:nil withPredicate:nil];
}

- (BOOL)isNonceAlreadyInDB:(NSData *)nonce {
    id result;
    
    NSData *hashedNonce = [NonceHasher hashedNonce:nonce myIdentityStore:myIdentityStore];
    
    if (hashedNonce == nil) {
        // We throw away messages with duplicate nonces and we don't want this to happen whenever hashing fails. Thus
        // we will return false in these cases.
        return false;
    }
    
    result = [self singleEntityNamed:@"Nonce" withPredicate:@"nonce == %@", hashedNonce];
    
    return result != nil;
}

/**
 @param groupId: ID of the group
 @returns All group entities for given groupID
 */
- (NSArray<GroupEntity*> *)groupEntitiesForGroupId:(NSData *)groupId {
    return [self allEntitiesNamed:@"Group" sortedBy:nil withPredicate:@"groupId == %@", groupId];
}

/**
 @param groupId: ID of the group
 @param creator: Creator of the group, is the creator myself then nil
 */
- (GroupEntity *)groupEntityForGroupId:(NSData *)groupId groupCreator:(NSString *)groupCreator {
    if (![groupCreator isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        return [self singleEntityNamed:@"Group" withPredicate: @"groupId == %@ AND groupCreator == %@", groupId, groupCreator];
    } else {
        return [self singleEntityNamed:@"Group" withPredicate: @"groupId == %@ AND groupCreator == nil", groupId];
    }
}

- (GroupEntity *)groupEntityForConversationEntity:(ConversationEntity *)conversation {
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

- (DistributionListEntity *) distributionListEntityForConversationEntity:(ConversationEntity *)conversation {
    return [self singleEntityNamed:@"DistributionList" withPredicate: @"conversation == %@", conversation];
}

- (DistributionListEntity *) distributionListEntityForDistributionListID:(NSNumber *)distributionListID {
    return [self singleEntityNamed:@"DistributionList" withPredicate: @"distributionListID == %@", distributionListID];
}

- (nullable NSArray<MessageReactionEntity *> *) messageReactionEntitiesForMessage:(nonnull BaseMessageEntity *)message creator:(nullable ContactEntity *)creator {
    return [self allEntitiesNamed:@"MessageReaction" sortedBy:nil withPredicate:@"message == %@ AND creator == %@", message, creator];
    
}

- (nullable NSArray<MessageReactionEntity *> *) messageReactionEntitiesForMessage:(nonnull BaseMessageEntity *)message {
    return [self allEntitiesNamed:@"MessageReaction" sortedBy:nil withPredicate:@"message == %@", message];
}

- (nullable MessageReactionEntity *) messageReactionEntityForMessageID:(nonnull NSData *)messageID creator:(nullable ContactEntity *)creator reaction:(nullable NSString *)reaction {
    return [self singleEntityNamed:@"MessageReaction" withPredicate:@"message.id == %@ AND creator == %@ AND reaction = %@", messageID, creator, reaction];

}
- (LastGroupSyncRequestEntity *)lastGroupSyncRequestFor:(NSData *)groupId groupCreator:(NSString *)groupCreator sinceDate:(NSDate *)sinceDate {
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

- (void)executeCountFetchRequest:(NSFetchRequest *)fetchRequest onCompletion:(void(^)(NSUInteger count))onCompletion onError:(void(^)(NSError *))onError {
    __block NSError *error;
    [_managedObjectContext performBlock:^{
        NSUInteger count = 0;
        count = [_managedObjectContext countForFetchRequest:fetchRequest error:&error];
        if (error && onError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onError(error);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                onCompletion(count);
            });
        }
    }];
}

- (NSBatchUpdateResult *)executeBatchUpdateRequest:(NSBatchUpdateRequest *)batchUpdateRequest {
    NSError *error;
    NSBatchUpdateResult *result;
    result = [_managedObjectContext executeRequest:batchUpdateRequest error:&error];
    
    if (error != nil) {
        DDLogError(@"Executing update batch request failed: %@, %@", error, [error userInfo]);
        return nil;
    } else {
        return result;
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
    
    if (members != nil) {
        NSMutableArray *memberIds = [NSMutableArray arrayWithCapacity:[members count]];
        [members enumerateObjectsUsingBlock:^(ContactEntity *contactEntity, BOOL *stop) {
            [memberIds addObject:contactEntity.identity];
        }];
        
        [predicates addObject:[NSPredicate predicateWithFormat:@"(hidden == nil OR hidden == 0) OR (hidden == 1 AND identity IN %@)", memberIds]];
    }
    else {
        [predicates addObject:[NSPredicate predicateWithFormat:@"hidden == nil OR hidden == 0"]];
    }

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
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state == %d", ContactStateActive];
        [predicates addObject:predicate];
    }
    
    if (contactList == ContactListWork) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"workContact == %@ ", @1];
        [predicates addObject:predicate];
    } else {
        if (contactList == ContactListContactsAndWork) {
            // do not predicate for work contacts
        } else {
            if (TargetManagerObjc.isBusinessApp) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"workContact == %@ ", @0];
                [predicates addObject:predicate];
            }
        }
    }
    
    NSMutableArray *allPredicates = [NSMutableArray array];
    [allPredicates addObject:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    
    if ([UserSettings sharedUserSettings].hideStaleContacts) {
        if (members.count > 0) {
            for (ContactEntity *contact in members) {
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

- (NSFetchedResultsController *)fetchedResultsControllerForDistributionLists {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DistributionList" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    return fetchedResultsController;
}

- (NSFetchedResultsController *)fetchedResultsControllerForConversations {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.relationshipKeyPathsForPrefetching = @[@"members"];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    NSMutableArray *predicates = [NSMutableArray array];
    
    // fetch only unarchived
    NSPredicate *notArchived = [NSPredicate predicateWithFormat:@"visibility != %@", [NSNumber numberWithInt:ConversationVisibilityArchived]];
    [predicates addObject: notArchived];
    
    // Fetch only chats where lastUpdate is not null to avoid showing chats that only contain system messages
    // This is documented in confluence
    NSPredicate *notNullLastUpdateDate = [NSPredicate predicateWithFormat:@"lastUpdate != nil"];
    [predicates addObject: notNullLastUpdateDate];
    
    // check if hide private chats is enabled
    if ([UserSettings sharedUserSettings].hidePrivateChats){
        NSPredicate *notPrivate = [NSPredicate predicateWithFormat:@"category != %@", [NSNumber numberWithInt:ConversationCategoryPrivate]];
        [predicates addObject: notPrivate];
    }
    // create AND predicate
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"visibility" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"lastUpdate" ascending:NO],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastMessage.date" ascending:NO]];
    [fetchRequest setSortDescriptors:sortDescriptors];
        
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];

    return fetchedResultsController;
}

- (NSFetchedResultsController *)fetchedResultsControllerForArchivedConversations {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.relationshipKeyPathsForPrefetching = @[@"members"];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    NSMutableArray *predicates = [NSMutableArray array];
    
    // only archived
    NSPredicate *archived = [NSPredicate predicateWithFormat:@"visibility == %@", [NSNumber numberWithInt:ConversationVisibilityArchived]];
    [predicates addObject: archived];
    
    // Fetch only chats where lastUpdate is not null to avoid showing chats that only contain system messages
    // This is documented in confluence
    NSPredicate *notNullLastUpdateDate = [NSPredicate predicateWithFormat:@"lastUpdate != nil"];
    [predicates addObject: notNullLastUpdateDate];
    
    // check if hide private chats is enabled
    if ([UserSettings sharedUserSettings].hidePrivateChats){
        NSPredicate *notPrivate = [NSPredicate predicateWithFormat:@"category != %@", [NSNumber numberWithInt:ConversationCategoryPrivate]];
        [predicates addObject:notPrivate];
    }
    
    // create AND predicate
    [fetchRequest setPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicates]];
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"visibility" ascending:NO], [NSSortDescriptor sortDescriptorWithKey:@"lastUpdate" ascending:NO],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastMessage.date" ascending:NO]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];

    return fetchedResultsController;
}

- (NSInteger)countArchivedConversations {
    return [self countEntityNamed:@"Conversation" withPredicate:[NSString stringWithFormat:@"visibility == %@", [NSNumber numberWithInt:ConversationVisibilityArchived]], [NSString stringWithFormat:@"lastUpdate != nil"]];
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

- (WebClientSessionEntity *)webClientSessionEntityForInitiatorPermanentPublicKeyHash:(NSString *)hash {
    return [self singleEntityNamed:@"WebClientSession" withPredicate:@"initiatorPermanentPublicKeyHash == %@", hash];
}

- (WebClientSessionEntity *)webClientSessionEntityForPrivateKey:(NSData *)privateKey {
    return [self singleEntityNamed:@"WebClientSession" withPredicate:@"privateKey == %@", privateKey];
}

- (WebClientSessionEntity *)activeWebClientSessionEntity {
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

- (NSArray *)allLastGroupSyncRequests {
    return [self allEntitiesNamed:@"LastGroupSyncRequest" sortedBy:nil withPredicate:nil];
}

- (NSArray *)allCallsWith:(NSString *)identity callID:(uint32_t)callID {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    NSDate *twoWeeksAgo = [[NSDate alloc] initWithTimeIntervalSinceNow:- 60 * 60 * 24 * 14];
    return [self allEntitiesNamed:@"Call" sortedBy:sortDescriptors withPredicate:@"contact.identity == %@ AND callID == %u AND date > %@", identity, callID, twoWeeksAgo];
}

- (NSArray<GroupCallEntity *> *)allGroupCallEntities {
    return [self allEntitiesNamed:@"GroupCallEntity" sortedBy:nil withPredicate:nil];
}

- (NSArray *)allFileMessagesWithJsonCaptionButEmptyCaption {
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    return [self allEntitiesNamed:@"FileMessage" sortedBy:sortDescriptors withPredicate:@"caption == nil && json contains[cd] %@", @"\"d\":\""];
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
                                   NSLocalizedDescriptionKey: [BundleUtil localizedStringForKey:@"Operation was unsuccessful."],
                                   NSLocalizedFailureReasonErrorKey: [BundleUtil localizedStringForKey:@"The operation timed out."],
                                   NSLocalizedRecoverySuggestionErrorKey: [BundleUtil localizedStringForKey:@"Have you tried turning it off and on again?"]
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

- (ConversationEntity *)legacyConversationForGroupId:(NSData *)groupId {
    return [self singleEntityNamed:@"Conversation" withPredicate: @"groupId == %@", groupId];
}

- (NSInteger)countFileMessagesWithNoMIMEType {
    return [self countEntityNamed:@"FileMessage" withPredicate:@"mimeType == nil"];
}

@end
