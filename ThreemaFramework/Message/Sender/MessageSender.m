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

#import "MessageSender.h"
#import "Conversation.h"
#import "BoxTextMessage.h"
#import "BoxLocationMessage.h"
#import "DeliveryReceiptMessage.h"
#import "GroupDeliveryReceiptMessage.h"
#import "TypingIndicatorMessage.h"
#import "GroupCreateMessage.h"
#import "GroupLeaveMessage.h"
#import "GroupRenameMessage.h"
#import "GroupTextMessage.h"
#import "GroupLocationMessage.h"
#import "Contact.h"
#import "ContactStore.h"
#import "TextMessage.h"
#import "LocationMessage.h"
#import "SystemMessage.h"
#import "ThreemaError.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import "DatabaseManager.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NSString+Hex.h"
#import "BallotMessageEncoder.h"
#import "Ballot.h"
#import "GroupBallotCreateMessage.h"
#import "GroupBallotVoteMessage.h"
#import "ThreemaUtilityObjC.h"
#import "BundleUtil.h"
#import "PinnedHTTPSURLLoader.h"
#import "QuoteUtil.h"
#import "ServerConnector.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

/// MARK: - Refactoring notes:
/// It possibly makes sense to integrate the MessageForwarder into this class upon rewriting it.
/// Also create a function that takes a LocationMessage as input for forwarding.

@implementation MessageSender {
    id<TaskManagerProtocolObjc> taskManager;
}

- (instancetype _Nonnull)initWith:(nonnull NSObject *)taskManagerObject {
    NSAssert([taskManagerObject isKindOfClass:[TaskManager class]], @"Object must be type of TaskManager");

    self = [super init];
    if (self) {
        self->taskManager = (id<TaskManagerProtocolObjc>)taskManagerObject;
    }
    return self;
}

- (AnyPromise *)sendDeliveryReceiptForAbstractMessage:(AbstractMessage* _Nonnull)message {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolve) {
        NSString *messageId = [message getMessageIdString];
        if (message.noDeliveryReceiptFlagSet) {
            DDLogVerbose(@"Do not send delivery receipt (noDeliveryReceiptFlagSet) for message ID: %@", messageId);

            resolve(nil);
        } else {
            DDLogVerbose(@"Sending delivery receipt for message ID: %@", messageId);
            DeliveryReceiptMessage *deliveryReceipt = [[DeliveryReceiptMessage alloc] init];
            deliveryReceipt.receiptType = DELIVERYRECEIPT_MSGRECEIVED;
            deliveryReceipt.receiptMessageIds = @[message.messageId];
            deliveryReceipt.fromIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
            deliveryReceipt.toIdentity = message.fromIdentity;

            TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:deliveryReceipt];
            [taskManager addObjcWithTaskDefinition:task completionHandler:^(__unused TaskDefinition * _Nonnull taskDefinition, NSError * _Nullable error) {
                if (error) {
                    resolve(error);
                }
                else {
                    resolve(nil);
                }
            }];
        }
    }];
}

+ (void)sendMessage:(NSString* _Nullable)message inConversation:(Conversation* _Nonnull)conversation quickReply:(BOOL)quickReply requestId:(NSString * _Nullable)requestId onCompletion:(void(^)(BaseMessage* _Nonnull message))onCompletion {
    
    __block Conversation *conversationOwnContext;
    __block TextMessage *newMessage;
    __block NSString *remainingBody;
    NSData *quoteMessageId = [QuoteUtil parseQuoteV2FromMessage:message remainingBody:&remainingBody];
    
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
        
    Group *group = [self groupForConversation:conversation withEntityManager:entityManager];

    TaskDefinitionSendBaseMessage *task = [[TaskDefinitionSendBaseMessage alloc] initWithMessage:newMessage group:group sendContactProfilePicture:(quickReply != YES)];

    TaskManager *tm = [[TaskManager alloc] init];
    if (onCompletion == nil) {
        [tm addObjcWithTaskDefinition:task];
    } else {
        [tm addObjcWithTaskDefinition:task completionHandler:^(TaskDefinition * _Nonnull task, NSError * _Nullable error) {
            if (error) {
                DDLogError(@"Error while sending message %@", error);
            }

            if ([task isKindOfClass:[TaskDefinitionSendBaseMessage class]] == YES) {
                BaseMessage *msg = [[entityManager entityFetcher] messageWithId:[(TaskDefinitionSendBaseMessage *)task messageID]];
                onCompletion(msg);
            }
            else {
                onCompletion(nil);
            }
        }];
    }
    
    [MessageSender donateInteractionForOutgoingMessageIn:conversation];
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
        newMessage.poiAddress = poiAddress;
    }];
    
    Group *group = [self groupForConversation:conversation withEntityManager:entityManager];
        
    // We replace \n with \\n to conform to specs
    NSString *formattedAddress = nil;
    formattedAddress = [newMessage.poiAddress stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];

    TaskDefinitionSendLocationMessage *task = [[TaskDefinitionSendLocationMessage alloc] initWithPoiAddress:formattedAddress message:newMessage group:group sendContactProfilePicture:YES];

    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task completionHandler:^(TaskDefinition * _Nullable taskDefinition, NSError * _Nullable error) {
        if (error) {
            DDLogError(@"Error while sending message %@", error);
        }

        if ([taskDefinition isKindOfClass:TaskDefinitionSendLocationMessage.class]) {
            TaskDefinitionSendLocationMessage *locationTaskDef = (TaskDefinitionSendLocationMessage *) taskDefinition;

            LocationMessage *message = (LocationMessage *)[[entityManager entityFetcher] messageWithId:[locationTaskDef messageID]];
            if (message != nil) {
                onCompletion(locationTaskDef.messageID);
            }
        }
    }];
    
    [MessageSender donateInteractionForOutgoingMessageIn:conversation];
}

+ (void)sendMessage:(AbstractMessage *)message isPersistent:(BOOL)isPersistent onCompletion:(void (^)(void))onCompletion {
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition: [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:message doOnlyReflect:NO isPersistent:isPersistent] completionHandler:^(__unused TaskDefinition * task, __unused NSError * error) {
        if (onCompletion != nil) {
            onCompletion();
        }
    }];
}

+ (void)sendReadReceiptForMessages:(NSArray*)messages toIdentity:(NSString*)identity onCompletion:(void(^)(void))onCompletion {
    EntityManager *em = [[EntityManager alloc]init];
    Contact *contact = [em.entityFetcher contactForId:identity];
    
    if (![MessageSender sendReadReceiptWithContact:contact]) {
        if (onCompletion) {
            onCompletion();
        }
        return;
    }
    
    [self sendReceiptForMessages:messages toIdentity:identity receiptType:DELIVERYRECEIPT_MSGREAD onCompletion:onCompletion];
}

+ (void)sendUserAckForMessages:(NSArray*)messages toIdentity:(NSString*)identity group:(Group *)group onCompletion:(void(^)(void))onCompletion {
    if (group == nil) {
        [self sendReceiptForMessages:messages toIdentity:identity receiptType:DELIVERYRECEIPT_MSGUSERACK onCompletion:onCompletion];
    }
    else {
        [self sendReceiptForGroupMessages:messages group:group receiptType:GROUPDELIVERYRECEIPT_MSGUSERACK onCompletion:onCompletion];
    }
}

+ (void)sendUserDeclineForMessages:(NSArray*)messages toIdentity:(NSString*)identity group:(Group *)group onCompletion:(void(^)(void))onCompletion {
    if (group == nil) {
        [self sendReceiptForMessages:messages toIdentity:identity receiptType:DELIVERYRECEIPT_MSGUSERDECLINE onCompletion:onCompletion];
    }
    else {
        [self sendReceiptForGroupMessages:messages group:group receiptType:GROUPDELIVERYRECEIPT_MSGUSERDECLINE onCompletion:onCompletion];
    }
}

+ (void)sendReceiptForMessages:(NSArray*)messages toIdentity:(NSString*)identity receiptType:(uint8_t)receiptType onCompletion:(void(^)(void))onCompletion {
    if ([messages count] == 0) {
        return;
    }

    // Chunks messages to max count of 800 ID's per delivery message receipt task, so that not exceeds max message size.
    NSArray *chunks = [messages chunkedInto:800];
    for (NSArray *chunk in chunks) {
        NSMutableArray *receiptMessageIds = [NSMutableArray arrayWithCapacity:messages.count];
        for (BaseMessage *message in chunk) {
            @try {
                if (![identity isEqualToString:message.conversation.contact.identity]) {
                    DDLogError(@"Bad from identity encountered while sending read receipt");
                    return;
                }

                if (receiptType == DELIVERYRECEIPT_MSGREAD && message.noDeliveryReceiptFlagSet) {
                    DDLogVerbose(@"Do not send read receipt (noDeliveryReceiptFlagSet) for message ID: %@", message.id);
                } else {
                    [receiptMessageIds addObject:message.id];
                }

            }
            @catch (NSException *exception) {
                DDLogError(@"Exception while marking message as read: %@", exception);
            }
        }

        if (receiptMessageIds.count > 0) {
            DDLogVerbose(@"Sending read receipt for message IDs: %@", receiptMessageIds);

            DeliveryReceiptMessage *deliveryReceipt = [[DeliveryReceiptMessage alloc] init];
            deliveryReceipt.receiptType = receiptType;
            deliveryReceipt.receiptMessageIds = receiptMessageIds;
            deliveryReceipt.fromIdentity = [[MyIdentityStore sharedMyIdentityStore] identity];
            deliveryReceipt.toIdentity = identity;

            TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:deliveryReceipt];
            TaskManager *tm = [[TaskManager alloc] init];
            [tm addObjcWithTaskDefinition:task completionHandler:^(__unused TaskDefinition * _Nonnull taskDefinition, __unused NSError * _Nullable err) {
                if (err == nil && onCompletion) {
                    onCompletion();
                }
            }];
        }
        else if (onCompletion) {
            onCompletion();
        }
    }
}

+ (void)sendReceiptForGroupMessages:(NSArray*)messages group:(Group *)group receiptType:(uint8_t)receiptType onCompletion:(void(^)(void))onCompletion {
    if ([messages count] == 0) {
        return;
    }
    
    if (receiptType == DELIVERYRECEIPT_MSGREAD || receiptType == DELIVERYRECEIPT_MSGRECEIVED) {
        // do not send received or read to group members
        return;
    }

    // Chunks messages to max count of 800 ID's per delivery message receipt task, so that not exceeds max message size.
    NSArray *chunks = [messages chunkedInto:800];
    for (NSArray *chunk in chunks) {
        NSMutableArray *receiptMessageIds = [NSMutableArray arrayWithCapacity:messages.count];
        for (BaseMessage *message in chunk) {
            @try {
                if (receiptType == DELIVERYRECEIPT_MSGREAD && message.noDeliveryReceiptFlagSet) {
                    DDLogVerbose(@"Do not send group read receipt (noDeliveryReceiptFlagSet) for message ID: %@", message.id);
                } else {
                    [receiptMessageIds addObject:message.id];
                }

            }
            @catch (NSException *exception) {
                DDLogError(@"Exception while marking message as read: %@", exception);
            }
        }

        if (receiptMessageIds.count > 0) {
            DDLogVerbose(@"Sending group read receipt for message IDs: %@", receiptMessageIds);
            
            TaskDefinitionSendGroupDeliveryReceiptsMessage *task = [[TaskDefinitionSendGroupDeliveryReceiptsMessage alloc] initWithGroup:group from:[[MyIdentityStore sharedMyIdentityStore] identity] to:group.allMemberIdentities.allObjects receiptType:receiptType receiptMessageIDs:receiptMessageIds sendContactProfilePicture:NO];

            TaskManager *tm = [[TaskManager alloc] init];
            [tm addObjcWithTaskDefinition:task completionHandler:^(TaskDefinition * _Nullable taskDefinition, NSError * _Nullable error) {
                if (error) {
                    DDLogError(@"Error while sending group delivery receipts message %@", error);
                }

                if ([taskDefinition isKindOfClass:TaskDefinitionSendGroupDeliveryReceiptsMessage.class]) {
                    TaskDefinitionSendGroupDeliveryReceiptsMessage *groupDeliveryReceiptsTaskDef = (TaskDefinitionSendGroupDeliveryReceiptsMessage *) taskDefinition;

                    onCompletion();
                }
            }];
        }
        else {
            onCompletion();
        }
    }
}

+ (void)sendTypingIndicatorMessage:(BOOL)typing toIdentity:(NSString*)identity {
    EntityManager *em = [[EntityManager alloc]init];
    Contact *contact = [em.entityFetcher contactForId:identity];

    if (![MessageSender sendTypingIndicatorWithContact:contact]) {
        return;
    }

    DDLogVerbose(@"Sending typing indicator %@ to %@", typing ? @"on" : @"off", identity);
    
    TypingIndicatorMessage *typingIndicatorMessage = [[TypingIndicatorMessage alloc] init];
    typingIndicatorMessage.typing = typing;
    typingIndicatorMessage.toIdentity = identity;
    
    TaskDefinitionSendAbstractMessage *task = [[TaskDefinitionSendAbstractMessage alloc] initWithMessage:typingIndicatorMessage doOnlyReflect:NO isPersistent:NO];
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
}

+ (void)markBlobAsDoneWithBlobID:(NSData* _Nonnull)blobID origin:(BlobOrigin)origin {
    BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings]];
    [blobUrl doneWithBlobID:blobID origin:origin completionHandler:^(NSURL * _Nullable doneUrl, NSError * _Nullable error) {
        if (doneUrl == nil) {
            DDLogWarn(@"Error marking blob ID %@ as done: %@", [NSString stringWithHexData:blobID], error);
            return;
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:doneUrl cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kBlobLoadTimeout];
        request.HTTPMethod = @"POST";
        
        PinnedHTTPSURLLoader *loader = [[PinnedHTTPSURLLoader alloc] init];
        [loader startWithURLRequest:request onCompletion:^(NSData *data) {
            DDLogInfo(@"Blob ID %@ marked as done", [NSString stringWithHexData:blobID]);
        } onError:^(NSError *error) {
            DDLogWarn(@"Error marking blob ID %@ as done: %@", [NSString stringWithHexData:blobID], error);
        }];
    }];
}

+ (void)sendCreateMessageForBallot:(Ballot *)ballot {
    if (![BallotMessageEncoder passesSanityCheck:ballot]) {
        DDLogError(@"Ballot did not pass sanity check. Do not send.");
        return;
    }
    
    __block Ballot *ballotOwnContext;
    __block Conversation *conversation;
    __block BallotMessage *newMessage;
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        ballotOwnContext = (Ballot *)[entityManager.entityFetcher getManagedObjectById:ballot.objectID];
        
        conversation = ballotOwnContext.conversation;
        newMessage = [entityManager.entityCreator ballotMessageForConversation:conversation];
        newMessage.ballot = ballotOwnContext;
        newMessage.conversation.lastMessage = newMessage;
    }];
    
    Group *group = [self groupForConversation:ballot.conversation withEntityManager:entityManager];

    TaskDefinitionSendBaseMessage *task = [[TaskDefinitionSendBaseMessage alloc] initWithMessage:newMessage group:group sendContactProfilePicture:NO];

    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
    
    [MessageSender donateInteractionForOutgoingMessageIn:ballot.conversation];
}

+ (void)sendBallotVoteMessage:(Ballot *)ballot {
    if (![BallotMessageEncoder passesSanityCheck:ballot]) {
        DDLogError(@"Ballot did not pass sanity check. Do not send.");
        return;
    }

    EntityManager *entityManager = [[EntityManager alloc] init];
    Group *group = [self groupForConversation:ballot.conversation withEntityManager:entityManager];
    
    TaskDefinitionSendBallotVoteMessage *task = [[TaskDefinitionSendBallotVoteMessage alloc] initWithBallot:ballot group:group sendContactProfilePicture:NO];

    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
    
    [MessageSender donateInteractionForOutgoingMessageIn:ballot.conversation];
}

/// Get `Group` if `conversation` is a group
///
/// This also does a periodic group sync if needed.
///
/// @param conversation Conversation to get `Group` for
/// @param entityManager Manager used for lookup
/// @return `Group` if `conversation` is a group, `nil` otherwise
+ (nullable Group *)groupForConversation:(Conversation *)conversation withEntityManager:(EntityManager *)entityManager {
    GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
    
    Group *group = [groupManager getGroupWithConversation:conversation];
    if (group != nil) {
        [groupManager periodicSyncIfNeededFor:group];
    }
    
    return group;
}

+ (void)sendBaseMessage:(BaseMessage *)baseMessage {
    TaskDefinitionSendBaseMessage *task = [[TaskDefinitionSendBaseMessage alloc] initWithMessage:baseMessage group:nil sendContactProfilePicture:false];
    
    TaskManager *tm = [[TaskManager alloc] init];
    [tm addObjcWithTaskDefinition:task];
}

@end
