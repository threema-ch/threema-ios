//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2020 Threema GmbH
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

#import "ConversationUtils.h"
#import "EntityManager.h"
#import "AppDelegate.h"
#import "MessageSender.h"
#import "NotificationManager.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif


@implementation ConversationUtils

+ (void)unreadConversation:(Conversation *)conversation {
    if (conversation == nil)
        return;
    
    NSNumber *unreadValue;
    
    if (conversation.unreadMessageCount.intValue > 0) {
        [ConversationUtils readMessagesQueue:conversation];
    }
    
    if (conversation.unreadMessageCount.intValue == 0) {
        unreadValue = @-1;
    } else {
        unreadValue = @0;
    }
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        conversation.unreadMessageCount = unreadValue;
    }];
    
    [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
}

+ (void)readMessagesQueue:(Conversation *)conversation {
    NSMutableArray *readReceiptQueue = [NSMutableArray new];
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSArray *messages = conversation.messages.allObjects;
    
    if (conversation.groupId != nil) {
        for (int i = 0; i < [messages count]; i++) {
            BaseMessage *curMessage = [messages objectAtIndex:i];
            if (!curMessage.isOwn.boolValue && !curMessage.read.boolValue) {
                [readReceiptQueue addObject:curMessage];
            }
        }
        
        [entityManager performSyncBlockAndSafe:^{
            for (BaseMessage *message in readReceiptQueue) {
                @try {
                    message.read = [NSNumber numberWithBool:YES];
                    message.readDate = [NSDate date];
                }
                @catch (NSException *exception) {
                    // intended to catch NSObjectInaccessibleException, which may happen
                    // if the message has been deleted in the meantime
                    DDLogError(@"Exception while marking message as read: %@", exception);
                }
            }
        }];
        [readReceiptQueue removeAllObjects];
        return;
    } else {
        for (int i = 0; i < [messages count]; i++) {
            BaseMessage *curMessage = [messages objectAtIndex:i];
            if (!curMessage.isOwn.boolValue && !curMessage.read.boolValue) {
                [readReceiptQueue addObject:curMessage];
            }
        }
    }
    
    /* do not send read receipts while app is in the background */
    if (![AppDelegate sharedAppDelegate].active)
        return;
    
    if (readReceiptQueue.count > 0) {
        [MessageSender sendReadReceiptForMessages:readReceiptQueue toIdentity:conversation.contact.identity async:YES quickReply:NO];
        
        [entityManager performSyncBlockAndSafe:^{
            for (BaseMessage *message in readReceiptQueue) {
                @try {
                    message.read = [NSNumber numberWithBool:YES];
                    message.readDate = [NSDate date];
                }
                @catch (NSException *exception) {
                    // intended to catch NSObjectInaccessibleException, which may happen
                    // if the message has been deleted in the meantime
                    DDLogError(@"Exception while marking message as read: %@", exception);
                }
            }
        }];
        
        [readReceiptQueue removeAllObjects];
    }
}

+ (void)markConversation:(Conversation *)conversation {
    if (conversation == nil)
        return;
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    
    [entityManager performSyncBlockAndSafe:^{
        conversation.marked = [NSNumber numberWithBool:YES];
    }];
}

+ (void)unmarkConversation:(Conversation *)conversation {
    if (conversation == nil)
        return;
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    
    [entityManager performSyncBlockAndSafe:^{
        conversation.marked = [NSNumber numberWithBool:NO];
    }];
}

/**
 If unread message count of conversation less 0, then set to 0 and set marked to true.
*/
+ (void)resetUnreadMessageCount {
    EntityManager *entityManager = [[EntityManager alloc] init];
    NSArray *conversations = [entityManager.entityFetcher conversationsWithNegativeUnreadMessageCount];
    for (Conversation *conversation in conversations) {
        [entityManager performSyncBlockAndSafe:^{
            conversation.unreadMessageCount = [NSNumber numberWithInt:0];
            conversation.marked = [NSNumber numberWithBool:YES];
        }];
    }
}

@end
