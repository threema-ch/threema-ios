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

#import "MessageSender.h"

#import "Conversation.h"

#import "BoxTextMessage.h"
#import "BoxLocationMessage.h"
#import "DeliveryReceiptMessage.h"
#import "TypingIndicatorMessage.h"
#import "GroupCreateMessage.h"
#import "GroupLeaveMessage.h"
#import "GroupRenameMessage.h"
#import "GroupTextMessage.h"
#import "GroupLocationMessage.h"
#import "GroupRequestSyncMessage.h"
#import "Contact.h"
#import "ContactStore.h"
#import "TextMessage.h"
#import "LocationMessage.h"
#import "MessageQueue.h"
#import "SystemMessage.h"
#import "ThreemaError.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import "DatabaseManager.h"
#import "EntityManager.h"
#import "NSString+Hex.h"
#import "BallotMessageEncoder.h"
#import "Ballot.h"
#import "GroupBallotCreateMessage.h"
#import "GroupBallotVoteMessage.h"
#import "Utils.h"
#import "BundleUtil.h"
#import "ContactSetPhotoMessage.h"
#import "ContactPhotoSender.h"
#import "BackgroundTaskManagerProxy.h"
#import "PinnedHTTPSURLLoader.h"
#import "QuoteParser.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation MessageSender

+ (void)sendDeliveryReceiptForMessage:(BaseMessage*)message fromIdentity:(NSString*)identity {
    DDLogVerbose(@"Sending delivery receipt for message ID: %@", message.id);
    DeliveryReceiptMessage *deliveryReceipt = [[DeliveryReceiptMessage alloc] init];
    deliveryReceipt.receiptType = DELIVERYRECEIPT_MSGRECEIVED;
    deliveryReceipt.receiptMessageIds = @[message.id];
    deliveryReceipt.toIdentity = identity;
    [[MessageQueue sharedMessageQueue] enqueue:deliveryReceipt];
}

+ (void)sendDeliveryReceiptForAbstractMessage:(AbstractMessage*)message fromIdentity:(NSString*)identity {
    NSString *messageId = [NSString stringWithHexData:message.messageId];
    DDLogVerbose(@"Sending delivery receipt for notification extension message ID: %@", messageId);
    DeliveryReceiptMessage *deliveryReceipt = [[DeliveryReceiptMessage alloc] init];
    deliveryReceipt.receiptType = DELIVERYRECEIPT_MSGRECEIVED;
    deliveryReceipt.receiptMessageIds = @[message.messageId];
    deliveryReceipt.toIdentity = identity;
    [[MessageQueue sharedMessageQueue] enqueueWait:deliveryReceipt];
}

+ (void)sendGroupCreateMessageForGroup:(GroupProxy*)group toMember:(Contact*)toMember {
    
    NSArray *groupMembers = nil;
    if ([group.activeMemberIds containsObject:toMember.identity]) {
        groupMembers = [group.activeMemberIds allObjects];
    } else {
        groupMembers = @[group.conversation.groupMyIdentity];
    }
    
    GroupCreateMessage *createMessage = [[GroupCreateMessage alloc] init];
    createMessage.toIdentity = toMember.identity;
    createMessage.groupId = group.groupId;
    createMessage.groupMembers = groupMembers;
    [[MessageQueue sharedMessageQueue] enqueue:createMessage];
}

+ (void)sendGroupSharedMessagesForConversation:(Conversation*)groupConversation toMember:(Contact *)newMember {
    // send own open ballots to all members
    for (Ballot *ballot in groupConversation.ballots) {
        if (ballot.isOwn && [ballot isClosed] == NO) {
            [self sendCreateMessageForBallot:ballot toContact:newMember];
            
            if (ballot.isIntermediate) {
                [self sendBallotVoteMessage:ballot toContact:newMember];
            }
        }
    }
}

+ (void)sendGroupRenameMessageForConversation:(Conversation*)conversation addSystemMessage:(BOOL)addSystemMessage {
    
    if (conversation.groupName.length == 0) {
        return;
    }
    
    /* send rename message to all members */
    for (Contact *member in conversation.members) {
        [self sendGroupRenameMessageForConversation:conversation toMember:member addSystemMessage:addSystemMessage];
    }
    
    if (addSystemMessage) {
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            Conversation *conversationOwnContext = (Conversation *)[entityManager.entityFetcher getManagedObjectById:conversation.objectID];
            
            /* Insert system message to document this change */
            SystemMessage *systemMessage = [entityManager.entityCreator systemMessageForConversation:conversationOwnContext];
            systemMessage.type = [NSNumber numberWithInt:kSystemMessageRenameGroup];
            systemMessage.arg = [conversationOwnContext.groupName dataUsingEncoding:NSUTF8StringEncoding];
        }];
    }
}

+ (void)sendGroupRenameMessageForConversation:(Conversation *)groupConversation toMember:(Contact*)member addSystemMessage:(BOOL)addSystemMessage {
    
    if (groupConversation.groupName.length == 0)
        return;
    
    GroupRenameMessage *renameMessage = [[GroupRenameMessage alloc] init];
    renameMessage.toIdentity = member.identity;
    renameMessage.groupId = groupConversation.groupId;
    renameMessage.name = groupConversation.groupName;
    [[MessageQueue sharedMessageQueue] enqueue:renameMessage];
}

+ (void)sendGroupLeaveMessageForConversation:(Conversation*)groupConversation {
    
    NSString *creator;
    
    if (groupConversation.contact == nil)
        creator = [MyIdentityStore sharedMyIdentityStore].identity;
    else
        creator = groupConversation.contact.identity;
    
    /* send leave message to all members */
    for (Contact *member in groupConversation.members) {
        [self sendGroupLeaveMessageForCreator:creator groupId:groupConversation.groupId toIdentity:member.identity];
    }
}

+ (void)sendGroupLeaveMessageForCreator:(NSString*)creator groupId:(NSData*)groupId toIdentity:(NSString*)toIdentity {
    GroupLeaveMessage *leaveMessage = [[GroupLeaveMessage alloc] init];
    leaveMessage.toIdentity = toIdentity;
    leaveMessage.groupCreator = creator;
    leaveMessage.groupId = groupId;
    [[MessageQueue sharedMessageQueue] enqueue:leaveMessage];
}

+ (void)sendGroupRequestSyncMessageForCreatorContact:(Contact*)creatorContact groupId:(NSData*)groupId {
    GroupRequestSyncMessage *requestSyncMessage = [[GroupRequestSyncMessage alloc] init];
    requestSyncMessage.toIdentity = creatorContact.identity;
    requestSyncMessage.groupId = groupId;
    [[MessageQueue sharedMessageQueue] enqueue:requestSyncMessage];
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          creatorContact, kKeyContact,
                          nil];
    EntityManager *entityManager = [[EntityManager alloc] init];
    Group *group = [entityManager.entityFetcher groupForGroupId:groupId groupCreator:creatorContact.identity];
    if (group == nil) {
        if(![[UserSettings sharedUserSettings].blacklist containsObject:creatorContact.identity]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationErrorUnknownGroup object:nil userInfo:info];
        }
    }
}

+ (void)sendMessage:(NSString*)message inConversation:(Conversation*)conversation async:(BOOL)async quickReply:(BOOL)quickReply requestId:(NSString *)requestId onCompletion:(void(^)(TextMessage *message, Conversation *conv))onCompletion {
    
    __block Conversation *conversationOwnContext;
    __block TextMessage *newMessage;
    __block NSString *remainingBody;
    NSData *quoteMessageId = [QuoteParser parseQuoteV2FromMessage:message remainingBody:&remainingBody];
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        conversationOwnContext = (Conversation *)[entityManager.entityFetcher getManagedObjectById:conversation.objectID];
        newMessage = [entityManager.entityCreator textMessageForConversation:conversationOwnContext];
        
        if (quoteMessageId != nil) {
            newMessage.quotedMessageId = quoteMessageId;
            newMessage.text = remainingBody;
        } else {
            newMessage.text = message;
        }
        
        if (requestId != nil) {
            newMessage.webRequestId = requestId;
        }
    }];
    
    if (conversationOwnContext.groupId != nil) {
        /* send to each group member */
        for (Contact *member in conversationOwnContext.members) {
            DDLogVerbose(@"Sending group message to %@", member.identity);
            GroupTextMessage *msg = [[GroupTextMessage alloc] init];
            msg.messageId = newMessage.id;
            msg.date = newMessage.date;
            msg.text = message;
            msg.groupId = conversationOwnContext.groupId;
            
            if (conversationOwnContext.contact == nil)
                msg.groupCreator = [MyIdentityStore sharedMyIdentityStore].identity;
            else
                msg.groupCreator = conversationOwnContext.contact.identity;
            
            msg.toIdentity = member.identity;
            if (async) {
                [[MessageQueue sharedMessageQueue] enqueue:msg];
            } else {
                [[MessageQueue sharedMessageQueue] enqueueWait:msg];
            }
            if (!quickReply) {
                [ContactPhotoSender sendProfilePicture:msg];
            }
        }
    } else {
        BoxTextMessage *msg = [[BoxTextMessage alloc] init];
        msg.messageId = newMessage.id;
        msg.date = newMessage.date;
        msg.text = message;
        msg.toIdentity = conversationOwnContext.contact.identity;

        if (quickReply) {
            [[MessageQueue sharedMessageQueue] enqueueWaitForQuickReply:msg];
        } else {
            if (async) {
                [[MessageQueue sharedMessageQueue] enqueue:msg];
            } else {
                [[MessageQueue sharedMessageQueue] enqueueWait:msg];
            }
            if (!quickReply) {
                [ContactPhotoSender sendProfilePicture:msg];
            }
        }
    }
    
    onCompletion(newMessage, conversationOwnContext);
}

+ (void)sendLocation:(CLLocationCoordinate2D)coordinates accuracy:(CLLocationAccuracy)accuracy poiName:(NSString*)poiName poiAddress:(NSString*)poiAddress inConversation:(Conversation*)conversation onCompletion:(void(^)(NSData *messageId))onCompletion {
    
    __block Conversation *conversationOwnContext;
    __block LocationMessage *newMessage;
    
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        
        conversationOwnContext = (Conversation *)[entityManager.entityFetcher getManagedObjectById:conversation.objectID];
        
        newMessage = [entityManager.entityCreator locationMessageForConversation:conversationOwnContext];
        newMessage.latitude = [NSNumber numberWithDouble:coordinates.latitude];
        newMessage.longitude = [NSNumber numberWithDouble:coordinates.longitude];
        newMessage.accuracy = [NSNumber numberWithDouble:accuracy];
        newMessage.poiName = poiName;
        if (poiAddress != nil) {
            newMessage.poiName = [NSString stringWithFormat:@"%@\n%@", poiName, poiAddress];
        } else {
            newMessage.poiName = poiName;
        }
    }];
    
    if (conversationOwnContext.groupId != nil) {
        /* send to each group member */
        for (Contact *member in conversationOwnContext.members) {
            DDLogVerbose(@"Sending group location message to %@", member.identity);
            GroupLocationMessage *msg = [[GroupLocationMessage alloc] init];
            msg.messageId = newMessage.id;
            msg.date = newMessage.date;
            msg.latitude = coordinates.latitude;
            msg.longitude = coordinates.longitude;
            msg.accuracy = accuracy;
            msg.poiName = poiName;
            msg.poiAddress = poiAddress;
            msg.groupId = conversationOwnContext.groupId;
            
            if (conversationOwnContext.contact == nil)
                msg.groupCreator = [MyIdentityStore sharedMyIdentityStore].identity;
            else
                msg.groupCreator = conversationOwnContext.contact.identity;
            
            msg.toIdentity = member.identity;
            [[MessageQueue sharedMessageQueue] enqueue:msg];
            [ContactPhotoSender sendProfilePicture:msg];
        }
    } else {
        BoxLocationMessage *msg = [[BoxLocationMessage alloc] init];
        msg.messageId = newMessage.id;
        msg.date = newMessage.date;
        msg.latitude = coordinates.latitude;
        msg.longitude = coordinates.longitude;
        msg.accuracy = accuracy;
        msg.poiName = poiName;
        msg.poiAddress = poiAddress;
        msg.toIdentity = conversationOwnContext.contact.identity;
        [[MessageQueue sharedMessageQueue] enqueue:msg];
        [ContactPhotoSender sendProfilePicture:msg];
    }
    
    if (poiName == nil) {
        [Utils reverseGeocodeNearLatitude:coordinates.latitude longitude:coordinates.longitude accuracy:accuracy completion:^(NSString *label) {
            if ([newMessage wasDeleted]) {
                return;
            }
            
            [entityManager performSyncBlockAndSafe:^{
                newMessage.reverseGeocodingResult = label;
            }];
        } onError:^(NSError *error) {
            DDLogWarn(@"Reverse geocoding failed: %@", error);
            if ([newMessage wasDeleted]) {
                return;
            }
            
            [entityManager performSyncBlockAndSafe:^{
                newMessage.reverseGeocodingResult = NSLocalizedString(@"unknown_location", nil);
            }];
        }];
    }
    
    onCompletion(newMessage.id);
}

+ (void)markMessageAsSent:(NSData*)messageId {
    /* Fetch message from DB */
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performAsyncBlockAndSafe:^{
        BaseMessage *dbmsg = [entityManager.entityFetcher ownMessageWithId: messageId];
        if (dbmsg == nil) {
            /* This can happen normally, e.g. for outgoing delivery receipts that we don't store in the DB */
            return;
        }
        
        if (dbmsg.sent == nil || dbmsg.sent.boolValue == NO) {
            dbmsg.sent = [NSNumber numberWithBool:YES];
        }
    }];
}

+ (void)sendReadReceiptForMessages:(NSArray*)messages toIdentity:(NSString*)identity async:(BOOL)async quickReply:(BOOL)quickReply {
    if (![UserSettings sharedUserSettings].sendReadReceipts)
        return;
    [self sendReceiptForMessages:messages toIdentity:identity receiptType:DELIVERYRECEIPT_MSGREAD async:async quickReply:quickReply];
}

+ (void)sendUserAckForMessages:(NSArray*)messages toIdentity:(NSString*)identity async:(BOOL)async quickReply:(BOOL)quickReply {
    [self sendReceiptForMessages:messages toIdentity:identity receiptType:DELIVERYRECEIPT_MSGUSERACK async:async quickReply:quickReply];
}

+ (void)sendUserDeclineForMessages:(NSArray*)messages toIdentity:(NSString*)identity async:(BOOL)async quickReply:(BOOL)quickReply {
    [self sendReceiptForMessages:messages toIdentity:identity receiptType:DELIVERYRECEIPT_MSGUSERDECLINE async:async quickReply:quickReply];
}

+ (void)sendReceiptForMessages:(NSArray*)messages toIdentity:(NSString*)identity receiptType:(uint8_t)receiptType async:(BOOL)async quickReply:(BOOL)quickReply {
    
    NSMutableArray *receiptMessageIds = [NSMutableArray arrayWithCapacity:messages.count];
    for (BaseMessage *message in messages) {
        @try {
            if (![identity isEqualToString:message.conversation.contact.identity]) {
                DDLogError(@"Bad from identity encountered while sending read receipt");
                return;
            }
            
            [receiptMessageIds addObject:message.id];
        }
        @catch (NSException *exception) {
            DDLogError(@"Exception while marking message as read: %@", exception);
        }
    }
    
    DDLogVerbose(@"Sending read receipt for message IDs: %@", receiptMessageIds);
    
    DeliveryReceiptMessage *deliveryReceipt = [[DeliveryReceiptMessage alloc] init];
    deliveryReceipt.receiptType = receiptType;
    deliveryReceipt.receiptMessageIds = receiptMessageIds;
    deliveryReceipt.toIdentity = identity;
    if (quickReply) {
        [[MessageQueue sharedMessageQueue] enqueueWaitForQuickReply:deliveryReceipt];
    } else {
        if (async) {
            [[MessageQueue sharedMessageQueue] enqueue:deliveryReceipt];
        } else {
            [[MessageQueue sharedMessageQueue] enqueueWait:deliveryReceipt];
        }
    }
}

+ (void)sendTypingIndicatorMessage:(BOOL)typing toIdentity:(NSString*)identity {
    if (![UserSettings sharedUserSettings].sendTypingIndicator) {
        return;
    }
    
    DDLogVerbose(@"Sending typing indicator %@ to %@", typing ? @"on" : @"off", identity);
    
    TypingIndicatorMessage *typingIndicatorMessage = [[TypingIndicatorMessage alloc] init];
    typingIndicatorMessage.typing = typing;
    typingIndicatorMessage.toIdentity = identity;
    [[MessageQueue sharedMessageQueue] enqueue:typingIndicatorMessage];
}

+ (void)markBlobAsDone:(NSData *)blobId {
    NSString *blobIdHex = [NSString stringWithHexData:blobId];
    NSString *blobFirstByteHex = [blobIdHex substringWithRange:NSMakeRange(0, 2)];
    NSURL *blobUrl;
    
    if ([UserSettings sharedUserSettings].enableIPv6) {
        blobUrl = [NSURL URLWithString:[NSString stringWithFormat:[BundleUtil objectForInfoDictionaryKey:@"ThreemaBlobDoneURLv6"], blobFirstByteHex, blobIdHex]];
    } else {
        blobUrl = [NSURL URLWithString:[NSString stringWithFormat:[BundleUtil objectForInfoDictionaryKey:@"ThreemaBlobDoneURL"], blobFirstByteHex, blobIdHex]];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:blobUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobLoadTimeout];
    request.HTTPMethod = @"POST";
    
    PinnedHTTPSURLLoader *loader = [[PinnedHTTPSURLLoader alloc] init];
    [loader startWithURLRequest:request onCompletion:^(NSData *data) {
        DDLogInfo(@"Blob ID %@ marked as done", blobIdHex);
    } onError:^(NSError *error) {
        DDLogWarn(@"Error marking blob ID %@ as done: %@", blobIdHex, error);
    }];
}

+ (void)sendCreateMessageForBallot:(Ballot *)ballot toContact:(Contact *)contact {
    EntityManager *entityManager = [[EntityManager alloc] init];
    
    Ballot *ballotOwnContext = (Ballot *)[entityManager.entityFetcher getManagedObjectById:ballot.objectID];
    Conversation *conversation = ballotOwnContext.conversation;
    
    BoxBallotCreateMessage *boxMessage = [BallotMessageEncoder encodeCreateMessageForBallot: ballot];
    boxMessage.messageId = [AbstractMessage randomMessageId];
    
    GroupBallotCreateMessage *msg = [BallotMessageEncoder groupBallotCreateMessageFrom:boxMessage forConversation:conversation];
    msg.toIdentity = contact.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

+ (void)sendCreateMessageForBallot:(Ballot *)ballot {
    
    __block Ballot *ballotOwnContext;
    __block Conversation *conversation;
    __block BallotMessage *message;
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        ballotOwnContext = (Ballot *)[entityManager.entityFetcher getManagedObjectById:ballot.objectID];
        
        conversation = ballotOwnContext.conversation;
        message = [entityManager.entityCreator ballotMessageForConversation:conversation];
        message.ballot = ballotOwnContext;
        message.conversation.lastMessage = message;
    }];
    
    BoxBallotCreateMessage *boxMessage = [BallotMessageEncoder encodeCreateMessageForBallot: ballot];
    boxMessage.messageId = message.id;
    
    if (conversation.groupId != nil) {
        /* send to each group member */
        for (Contact *member in conversation.members) {
            DDLogVerbose(@"Sending ballot create message to %@", member.identity);
            
            GroupBallotCreateMessage *msg = [BallotMessageEncoder groupBallotCreateMessageFrom:boxMessage forConversation:conversation];
            
            msg.toIdentity = member.identity;
            [[MessageQueue sharedMessageQueue] enqueue:msg];
        }
    } else {
        boxMessage.toIdentity = conversation.contact.identity;
        [[MessageQueue sharedMessageQueue] enqueue:boxMessage];
    }
}

+ (void)sendBallotVoteMessage:(Ballot *)ballot toContact:(Contact *) contact {
    EntityManager *entityManager = [[EntityManager alloc] init];
    
    Ballot *ballotOwnContext = (Ballot *)[entityManager.entityFetcher getManagedObjectById:ballot.objectID];
    Conversation *conversation = ballotOwnContext.conversation;
    
    BoxBallotVoteMessage *boxMessage = [BallotMessageEncoder encodeVoteMessageForBallot: ballot];
    boxMessage.messageId = [AbstractMessage randomMessageId];
    
    GroupBallotVoteMessage *msg = [BallotMessageEncoder groupBallotVoteMessageFrom:boxMessage forConversation:conversation];
    msg.toIdentity = contact.identity;
    [[MessageQueue sharedMessageQueue] enqueue:msg];
}

+ (void)sendBallotVoteMessage:(Ballot *)ballot {
    Conversation *conversation = ballot.conversation;
    BoxBallotVoteMessage *boxMessage = [BallotMessageEncoder encodeVoteMessageForBallot: ballot];
    
    if (conversation.groupId != nil) {
        /* send to each group member */
        for (Contact *member in conversation.members) {
            DDLogVerbose(@"Sending ballot vote message to %@", member.identity);
            
            GroupBallotVoteMessage *msg = [BallotMessageEncoder groupBallotVoteMessageFrom:boxMessage forConversation:conversation];
            
            msg.toIdentity = member.identity;
            [[MessageQueue sharedMessageQueue] enqueue:msg];
        }
    } else {
        boxMessage.toIdentity = conversation.contact.identity;
        [[MessageQueue sharedMessageQueue] enqueue:boxMessage];
    }
}

@end
