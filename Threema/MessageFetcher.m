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

#import "MessageFetcher.h"

#define CONVERSATION_PREDICATE [NSPredicate predicateWithFormat:@"conversation == %@", _conversation]
#define CONVERSATION_UNREAD_PREDICATE [NSPredicate predicateWithFormat:@"conversation == %@ AND read == false AND isOwn == false", _conversation]
#define CONVERSATION_MESSAGEID_PREDICATE [NSPredicate predicateWithFormat:@"conversation == %@ AND id == %@", _conversation, _messageId]

@interface MessageFetcher ()

@property Conversation *conversation;
@property NSData *messageId;
@property EntityFetcher *entityFetcher;
@property NSFetchRequest *countFetchRequest;
@property NSFetchRequest *messagesFetchRequest;
@property NSFetchRequest *unreadMessagesFetchRequest;
@property NSFetchRequest *messageIDFetchRequest;
@property NSFetchRequest *allMessagesFetchRequest;

@end

@implementation MessageFetcher

+(instancetype)messageFetcherFor:(Conversation *)conversation withEntityFetcher:(EntityFetcher *)entityFetcher {
    return [[MessageFetcher alloc] initWithConversation: conversation withEntityFetcher:entityFetcher];
}

- (instancetype)initWithConversation:(Conversation *)conversation withEntityFetcher:(EntityFetcher *)entityFetcher
{
    self = [super init];
    if (self) {
        _conversation = conversation;
        _entityFetcher = entityFetcher;
        
        _orderAscending = YES;
        [self setupFetchRequests];
    }
    return self;
}

- (NSArray *) sortDescriptorsAscending:(BOOL)ascending {
    return @[
             [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:ascending],
             [NSSortDescriptor sortDescriptorWithKey:@"remoteSentDate" ascending:ascending]
             ];
    
}

- (void)setupFetchRequests {
    _countFetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
    _countFetchRequest.predicate = CONVERSATION_PREDICATE;
    
    _messagesFetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
    _messagesFetchRequest.predicate = CONVERSATION_PREDICATE;
    _messagesFetchRequest.sortDescriptors = [self sortDescriptorsAscending:_orderAscending];
    
    _unreadMessagesFetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
    _unreadMessagesFetchRequest.predicate = CONVERSATION_UNREAD_PREDICATE;
    _unreadMessagesFetchRequest.sortDescriptors = [self sortDescriptorsAscending:NO];
    
    _allMessagesFetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
    _allMessagesFetchRequest.predicate = CONVERSATION_PREDICATE;
    _allMessagesFetchRequest.sortDescriptors = [self sortDescriptorsAscending:_orderAscending];
}

- (void)setOrderAscending:(BOOL)orderAscending {
    if (_orderAscending != orderAscending) {
        _orderAscending = orderAscending;
        [self setupFetchRequests];
    }
}

- (NSArray *)messagesAtOffset:(NSInteger)offset count:(NSInteger)count {
    _messagesFetchRequest.fetchOffset = offset;
    _messagesFetchRequest.fetchLimit = count;
    return [_entityFetcher executeFetchRequest: _messagesFetchRequest];
}

- (NSArray *)unreadMessages {
    return [_entityFetcher executeFetchRequest: _unreadMessagesFetchRequest];
}

- (NSInteger)count {
    return [_entityFetcher executeCountFetchRequest:_countFetchRequest];
}

- (NSUInteger)indexForMessage:(NSData *)messageId {
    _messageId = messageId;
    if (_messageIDFetchRequest == nil) {
        _messageIDFetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
        _messageIDFetchRequest.sortDescriptors = [self sortDescriptorsAscending:_orderAscending];
    }
    _messageIDFetchRequest.predicate = CONVERSATION_MESSAGEID_PREDICATE;
    
    NSArray *searchMessage = [_entityFetcher executeFetchRequest:_messageIDFetchRequest];
    if (searchMessage.count > 0) {
        NSArray *allMessages = [_entityFetcher executeFetchRequest:_allMessagesFetchRequest];
        return [allMessages indexOfObject:searchMessage.firstObject];
    }
    return 0;
}

- (BaseMessage *)lastMessage {
    NSFetchRequest *fetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
    fetchRequest.predicate = CONVERSATION_PREDICATE;
    fetchRequest.sortDescriptors = [self sortDescriptorsAscending:NO];
    fetchRequest.fetchLimit = 1;
    
    NSArray *result = [_entityFetcher executeFetchRequest:fetchRequest];
    
    if (result != nil && [result count] > 0) {
        return [result objectAtIndex: 0];
    } else {
        return nil;
    }
}

- (NSArray *)last20Messages {
    NSFetchRequest *fetchRequest = [_entityFetcher fetchRequestForEntity:@"Message"];
    fetchRequest.predicate = CONVERSATION_PREDICATE;
    fetchRequest.sortDescriptors = [self sortDescriptorsAscending:NO];
    fetchRequest.fetchLimit = 20;
    
    NSArray *result = [_entityFetcher executeFetchRequest:fetchRequest];
    
    if (result != nil && [result count] > 0) {
        return result;
    } else {
        return nil;
    }
}

@end
