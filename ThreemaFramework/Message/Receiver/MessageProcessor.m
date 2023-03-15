//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import <CoreData/CoreData.h>
#import "MessageProcessor.h"
#import "MessageDecoder.h"
#import "BoxTextMessage.h"
#import "BoxImageMessage.h"
#import "BoxVideoMessage.h"
#import "BoxLocationMessage.h"
#import "BoxAudioMessage.h"
#import "BoxedMessage.h"
#import "BoxVoIPCallOfferMessage.h"
#import "BoxVoIPCallAnswerMessage.h"
#import "DeliveryReceiptMessage.h"
#import "TypingIndicatorMessage.h"
#import "GroupCreateMessage.h"
#import "GroupLeaveMessage.h"
#import "GroupRenameMessage.h"
#import "GroupTextMessage.h"
#import "GroupLocationMessage.h"
#import "GroupVideoMessage.h"
#import "GroupImageMessage.h"
#import "GroupAudioMessage.h"
#import "GroupSetPhotoMessage.h"
#import "LocationMessage.h"
#import "TextMessage.h"
#import "ImageMessageEntity.h"
#import "VideoMessageEntity.h"
#import "AudioMessageEntity.h"
#import "BoxFileMessage.h"
#import "GroupFileMessage.h"
#import "ContactSetPhotoMessage.h"
#import "ContactDeletePhotoMessage.h"
#import "ContactRequestPhotoMessage.h"
#import "GroupDeletePhotoMessage.h"
#import "UnknownTypeMessage.h"
#import "ContactEntity.h"
#import "ContactStore.h"
#import "Conversation.h"
#import "ImageData.h"
#import "ThreemaUtilityObjC.h"
#import "ProtocolDefines.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import "AnimGifMessageLoader.h"
#import "ContactGroupPhotoLoader.h"
#import "ValidationLogger.h"
#import "BallotMessageDecoder.h"
#import "MessageSender.h"
#import "GroupMessageProcessor.h"
#import "ThreemaError.h"
#import "DatabaseManager.h"
#import "FileMessageDecoder.h"
#import "UTIConverter.h"
#import "BoxVoIPCallIceCandidatesMessage.h"
#import "BoxVoIPCallHangupMessage.h"
#import "BoxVoIPCallRingingMessage.h"
#import "NonceHasher.h"
#import "ServerConnector.h"
#import <PromiseKit/PromiseKit.h>
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "NSString+Hex.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation MessageProcessor {
    id<MessageProcessorDelegate> messageProcessorDelegate;
    int maxBytesToDecrypt;
    int timeoutDownloadThumbnail;
    EntityManager *entityManager;
    ForwardSecurityMessageProcessor *fsmp;
    NonceGuard *nonceGuard;
}

static dispatch_queue_t pendingGroupMessagesQueue;
static NSMutableOrderedSet *pendingGroupMessages;

- (instancetype)initWith:(id<MessageProcessorDelegate>)messageProcessorDelegate entityManager:(NSObject *)entityManagerObject fsmp:(NSObject*)fsmp {
    NSAssert([entityManagerObject isKindOfClass:[EntityManager class]], @"Object must be type of EntityManager");
    NSAssert([fsmp isKindOfClass:[ForwardSecurityMessageProcessor class]], @"Object must be type of ForwardSecurityMessageProcessor");

    self = [super init];
    if (self) {
        self->messageProcessorDelegate = messageProcessorDelegate;
        self->maxBytesToDecrypt = 0;
        self->timeoutDownloadThumbnail = 0;
        self->entityManager = (EntityManager*)entityManagerObject;
        self->fsmp = (ForwardSecurityMessageProcessor*)fsmp;
        self->nonceGuard = [[NonceGuard alloc] initWithEntityManager:self->entityManager];

        if (pendingGroupMessages == nil) {
            pendingGroupMessagesQueue = dispatch_queue_create("ch.threema.ServerConnector.pendingGroupMessagesQueue", NULL);
            pendingGroupMessages = [[NSMutableOrderedSet alloc] init];
        }
    }
    return self;
}

- (AnyPromise *)processIncomingMessage:(BoxedMessage*)boxmsg receivedAfterInitialQueueSend:(BOOL)receivedAfterInitialQueueSend maxBytesToDecrypt:(int)maxBytesToDecrypt timeoutDownloadThumbnail:(int)timeoutDownloadThumbnail {

    self->maxBytesToDecrypt = maxBytesToDecrypt;
    self->timeoutDownloadThumbnail = timeoutDownloadThumbnail;

    return [AnyPromise promiseWithAdapterBlock:^(PMKAdapter  _Nonnull adapter) {
        [messageProcessorDelegate beforeDecode];

        ContactAcquaintanceLevel acquaintanceLevel = boxmsg.flags & MESSAGE_FLAG_GROUP ? ContactAcquaintanceLevelGroup : ContactAcquaintanceLevelDirect;

        [[ContactStore sharedContactStore] fetchPublicKeyForIdentity:boxmsg.fromIdentity acquaintanceLevel:acquaintanceLevel entityManager:entityManager onCompletion:^(NSData *publicKey) {
            NSAssert(!([NSThread isMainThread] == YES), @"Should not running in main thread");

            [entityManager performBlock:^{
                AbstractMessage *amsg = [MessageDecoder decodeFromBoxed:boxmsg withPublicKey:publicKey];
                if (amsg == nil) {
                    // Can't process message at this time, try it later
                    [messageProcessorDelegate incomingMessageFailed:boxmsg];
                    adapter(nil, [ThreemaError threemaError:@"Bad message format or decryption error" withCode:kBadMessageErrorCode]);
                    return;
                }

                if ([amsg isKindOfClass: [UnknownTypeMessage class]]) {
                    // Can't process message at this time, try it later
                    [messageProcessorDelegate incomingMessageFailed:boxmsg];
                    adapter(nil, [ThreemaError threemaError:@"Unknown message type" withCode:kUnknownMessageTypeErrorCode]);
                    return;
                }

                /* blacklisted? */
                if ([self isBlacklisted:amsg]) {
                    DDLogWarn(@"Ignoring message from blocked ID %@", boxmsg.fromIdentity);

                    // Do not process message, send server ack
                    [messageProcessorDelegate incomingMessageFailed:boxmsg];
                    adapter(nil, nil);
                    return;
                }

                // Validation logging
                if ([amsg isContentValid] == NO) {
                    NSString *errorDescription = @"Ignore invalid content";
                    if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:errorDescription];
                    } else {
                        [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:errorDescription];
                    }

                    // Do not process message, send server ack
                    [messageProcessorDelegate incomingMessageFailed:boxmsg];
                    adapter(nil, nil);
                    return;
                } else {
                    if ([nonceGuard isProcessedWithMessage:amsg isReflected:NO]) {
                        NSString *errorDescription = @"Nonce already in database";
                        if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                            [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:errorDescription];
                        } else {
                            [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:errorDescription];
                        }

                        // Do not process message, send server ack
                        [messageProcessorDelegate incomingMessageFailed:boxmsg];
                        adapter(nil, nil);
                        return;
                    } else {
                        if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                            [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:nil];
                        } else {
                            [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:nil];
                        }
                    }
                }

                amsg.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend;

                [self processIncomingAbstractMessage:amsg onCompletion:^(AbstractMessage *processedMsg) {
                    // Message successfully processed
                    adapter(processedMsg, nil);
                } onError:^(NSError *error) {
                    // Failed to process message, try it later
                    adapter(nil, error);
                }];
            }];
        } onError:^(NSError *error) {
            [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"PublicKey from Threema-ID not found"];
            // Failed to process message, try it later
            adapter(nil, error);
        }];
    }];
}

- (void)processIncomingAbstractMessage:(AbstractMessage*)amsg onCompletion:(void(^)(AbstractMessage *processedMsg))onCompletion onError:(void(^)(NSError *err))onError {
    
    if ([amsg isContentValid] == NO) {
        DDLogInfo(@"Ignore invalid content, message ID %@ from %@", amsg.messageId, amsg.fromIdentity);
        onCompletion(nil);
        return;
    }
    
    if ([nonceGuard isProcessedWithMessage:amsg isReflected:NO]) {
        DDLogInfo(@"Message nonce for %@ already in database", amsg.messageId);
        onCompletion(nil);
        return;
    }
    
    /* Find contact for message */
    
    ContactEntity *contact = [entityManager.entityFetcher contactForId: amsg.fromIdentity];
    if (contact == nil) {
        /* This should never happen, as without an entry in the contacts database, we wouldn't have
         been able to decrypt this message in the first place (no sender public key) */
        DDLogWarn(@"Identity %@ not in local contacts database - cannot process message", amsg.fromIdentity);
        NSError *error = [ThreemaError threemaError:[NSString stringWithFormat:@"Identity %@ not in local contacts database - cannot process message", amsg.fromIdentity]];
        onError(error);
        return;
    }
    NSData *senderPublicKey = contact.publicKey;
    
    /* Update public nickname in contact, if necessary */
    [[ContactStore sharedContactStore] updateNickname:amsg.fromIdentity nickname:amsg.pushFromName shouldReflect:YES];

    DDLogVerbose(@"Process incoming message: %@", amsg);
    
    [messageProcessorDelegate incomingMessageStarted:amsg];
    
    void(^processAbstractMessageBlock)(AbstractMessage *) = ^void(AbstractMessage *amsg) {        
        [self processIncomingMessage:(AbstractMessage *)amsg onCompletion:^(id<MessageProcessorDelegate> _Nullable delegate) {
            if (!amsg.flagDontQueue) {
                [nonceGuard processedWithMessage:amsg isReflected:NO error:nil];
            }

            if (delegate) {
                [delegate incomingMessageFinished:amsg isPendingGroup:false];
            }
            else {
                [messageProcessorDelegate incomingMessageFinished:amsg isPendingGroup:false];
            }
            onCompletion(amsg);
        } onError:^(NSError *error) {
            [messageProcessorDelegate incomingMessageFinished:amsg isPendingGroup:false];
            onError(error);
        }];
    };
    
    @try {
        if ([amsg isKindOfClass:[ForwardSecurityEnvelopeMessage class]]) {
            if ([ThreemaUtility supportsForwardSecurity]) {
                [self processIncomingForwardSecurityMessage:(ForwardSecurityEnvelopeMessage*)amsg senderPublicKey:senderPublicKey onCompletion:^(AbstractMessage *unwrappedMessage) {
                    if (unwrappedMessage != nil) {
                        processAbstractMessageBlock(unwrappedMessage);
                    } else {
                        [messageProcessorDelegate incomingAbstractMessageFailed:amsg]; // Remove notification
                        onError(nil); // drop message
                    }
                } onError:^(NSError *error) {
                    if ([error.userInfo objectForKey:@"ShouldRetry"]) {
                        [messageProcessorDelegate incomingMessageFinished:amsg isPendingGroup:false];
                        onError(error);
                    } else {
                        [messageProcessorDelegate incomingAbstractMessageFailed:amsg]; // Remove notification
                        onError(nil); // drop message
                    }
                }];
            } else {
                // No FS support - reject message
                ForwardSecurityContact *fsContact = [[ForwardSecurityContact alloc] initWithIdentity:amsg.fromIdentity publicKey:senderPublicKey];
                [fsmp rejectEnvelopeMessageWithSender:fsContact envelopeMessage:(ForwardSecurityEnvelopeMessage*)amsg];
                [messageProcessorDelegate incomingAbstractMessageFailed:amsg]; // Remove notification
                onError(nil); // drop message
            }
        } else if ([amsg isKindOfClass:[AbstractGroupMessage class]]) {
            [self processIncomingGroupMessage:(AbstractGroupMessage *)amsg onCompletion:^{
                [nonceGuard processedWithMessage:amsg isReflected:NO error:nil];
                [messageProcessorDelegate incomingMessageFinished:amsg isPendingGroup:false];
                onCompletion(amsg);
            } onError:^(NSError *error) {
                [messageProcessorDelegate incomingMessageFinished:amsg isPendingGroup:[pendingGroupMessages containsObject:amsg] == true];
                onError(error);
            }];
        } else  {
            processAbstractMessageBlock(amsg);
        }
    } @catch (NSException *exception) {
        NSError *error = [ThreemaError threemaError:exception.description withCode:kMessageProcessingErrorCode];
        onError(error);
    } @catch (NSError *error) {
        onError(error);
    }
}

/**
Process incoming message.

@param amsg: Incoming Abstract Message
@param onCompletion: Completion handler with MessageProcessorDelegate, use it when calling MessageProcessorDelegate in completion block of processVoIPCall, to prevent blocking of dispatch queue 'ServerConnector.registerMessageProcessorDelegateQueue')
@param onError: Error handler
*/
- (void)processIncomingMessage:(AbstractMessage*)amsg onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nullable delegate))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {

    ContactEntity *sender;
    ContactEntity *receiver;
    __block Conversation *conversation = [entityManager existingConversationSenderReceiverFor:amsg sender:&sender receiver:&receiver];

    if (sender == nil) {
        onError([ThreemaError threemaError:@"Sender not found as contact"]);
        return;
    }

    if (conversation == nil) {
        [entityManager performSyncBlockAndSafe:^{
            conversation = [entityManager conversationForContact:sender createIfNotExisting:[amsg canCreateConversation]];
        }];
    }

    if ([amsg needsConversation] && conversation == nil) {
        onCompletion(nil);
        return;
    }

    if ([amsg isKindOfClass:[BoxTextMessage class]]) {
        TextMessage *message = (TextMessage *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
        if (message == nil) {
            onError([ThreemaError threemaError:@"Could not find/create text message"]);
            return;
        }

        [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg onCompletion:^{
            onCompletion(nil);
        }];
    } else if ([amsg isKindOfClass:[BoxImageMessage class]]) {
        [self processIncomingImageMessage:(BoxImageMessage *)amsg sender:sender conversation:conversation onCompletion:^{
            onCompletion(nil);
        } onError:onError];
    } else if ([amsg isKindOfClass:[BoxVideoMessage class]]) {
        [self processIncomingVideoMessage:(BoxVideoMessage*)amsg sender:sender conversation:conversation onCompletion:^{
            onCompletion(nil);
        } onError:onError];
    } else if ([amsg isKindOfClass:[BoxLocationMessage class]]) {
        LocationMessage *message = (LocationMessage *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
        if (message == nil) {
            onError([ThreemaError threemaError:@"Could not find/create location message"]);
            return;
        }

        [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg onCompletion:^{
            [self resolveAddressFor:message]
                .thenInBackground(^{
                onCompletion(nil);
            });
        }];
    } else if ([amsg isKindOfClass:[BoxAudioMessage class]]) {
        AudioMessageEntity *message = (AudioMessageEntity *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
        if (message == nil) {
            onError([ThreemaError threemaError:@"Could not find/create audio message"]);
            return;
        }

        [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg onCompletion:^{
            onCompletion(nil);
        }];
    } else if ([amsg isKindOfClass:[DeliveryReceiptMessage class]]) {
        [self processIncomingDeliveryReceipt:(DeliveryReceiptMessage*)amsg onCompletion:^{
            onCompletion(nil);
        }];
    } else if ([amsg isKindOfClass:[TypingIndicatorMessage class]]) {
        [self processIncomingTypingIndicator:(TypingIndicatorMessage*)amsg];
        onCompletion(nil);
    } else if ([amsg isKindOfClass:[BoxBallotCreateMessage class]]) {
        BallotMessageDecoder *decoder = [[BallotMessageDecoder alloc] initWith:entityManager];
        BallotMessage *ballotMessage = [decoder decodeCreateBallotFromBox:(BoxBallotCreateMessage *)amsg sender:sender conversation:conversation];
        if (ballotMessage == nil) {
            onError([ThreemaError threemaError:@"Could not find/create audio message"]);
            return;
        }

        [self finalizeMessage:ballotMessage inConversation:conversation fromBoxMessage:amsg onCompletion:^{
            onCompletion(nil);
        }];
    } else if ([amsg isKindOfClass:[BoxBallotVoteMessage class]]) {
        // TODO: This could be generate duplicate system messages, if message will processed multiple (race condition)
        [self processIncomingBallotVoteMessage:(BoxBallotVoteMessage*)amsg onCompletion:^{
            onCompletion(nil);
        } onError:onError];
    } else if ([amsg isKindOfClass:[BoxFileMessage class]]) {
        [FileMessageDecoder decodeMessageFromBox:(BoxFileMessage *)amsg sender:sender conversation:conversation isReflectedMessage:NO timeoutDownloadThumbnail:timeoutDownloadThumbnail entityManager:entityManager onCompletion:^(BaseMessage *message) {
            // Do not download blob when message will processed via Notification Extension,
            // to keep notifications fast and because option automatically save to photos gallery
            // doesn't work from Notification Extension
            if ([AppGroup getActiveType] != AppGroupTypeNotificationExtension) {
                [self conditionallyStartLoadingFileFromMessage:(FileMessageEntity *)message];
            }
            [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg onCompletion:^{
                onCompletion(nil);
            }];
        } onError:onError];
    } else if ([amsg isKindOfClass:[ContactSetPhotoMessage class]]) {
        [self processIncomingContactSetPhotoMessage:(ContactSetPhotoMessage *)amsg onCompletion:^{
            onCompletion(nil);
        } onError:onError];
    } else if ([amsg isKindOfClass:[ContactDeletePhotoMessage class]]) {
        [self processIncomingContactDeletePhotoMessage:(ContactDeletePhotoMessage *)amsg onCompletion:^{
            onCompletion(nil);
        } onError:onError];
    } else if ([amsg isKindOfClass:[ContactRequestPhotoMessage class]]) {
        [self processIncomingContactRequestPhotoMessage:(ContactRequestPhotoMessage *)amsg onCompletion:^{
            onCompletion(nil);
        }];
    } else if ([amsg isKindOfClass:[BoxVoIPCallOfferMessage class]]) {
        [self processIncomingVoIPCallOfferMessage:(BoxVoIPCallOfferMessage *)amsg onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallAnswerMessage class]]) {
        [self processIncomingVoIPCallAnswerMessage:(BoxVoIPCallAnswerMessage *)amsg onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallIceCandidatesMessage class]]) {
        [self processIncomingVoIPCallIceCandidatesMessage:(BoxVoIPCallIceCandidatesMessage *)amsg onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallHangupMessage class]]) {
        [self processIncomingVoIPCallHangupMessage:(BoxVoIPCallHangupMessage *)amsg onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallRingingMessage class]]) {
        [self processIncomingVoipCallRingingMessage:(BoxVoIPCallRingingMessage *)amsg onCompletion:onCompletion onError:onError];
    }
    else {
        // Do not Ack message, try process this message later because of protocol changes
        onError([ThreemaError threemaError:@"Invalid message class"]);
    }
}

- (void)processIncomingGroupMessage:(AbstractGroupMessage * _Nonnull)amsg onCompletion:(void(^ _Nonnull)(void))onCompletion onError:(void(^ _Nonnull)(NSError * error))onError {
    
    GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
    GroupMessageProcessor *groupProcessor = [[GroupMessageProcessor alloc] initWithMessage:amsg myIdentityStore:[MyIdentityStore sharedMyIdentityStore] userSettings:[UserSettings sharedUserSettings] groupManager:groupManager entityManager:entityManager];
    [groupProcessor handleMessageOnCompletion:^(BOOL didHandleMessage) {
        if (didHandleMessage) {
            if (groupProcessor.addToPendingMessages) {
                dispatch_sync(pendingGroupMessagesQueue, ^{
                    BOOL exists = NO;
                    for (AbstractGroupMessage *item in pendingGroupMessages) {
                        if ([item.messageId isEqualToData:amsg.messageId] && item.fromIdentity == amsg.fromIdentity) {
                            exists = YES;
                            break;
                        }
                    }
                    if (exists == NO) {
                        DDLogInfo(@"Pending group message add %@ %@", amsg.messageId, amsg.description);
                        [pendingGroupMessages addObject:amsg];
                    }
                });
                [messageProcessorDelegate pendingGroup:amsg];
                onError([ThreemaError threemaError:[NSString stringWithFormat:@"Group not found for this message %@", amsg.messageId]  withCode:kPendingGroupMessageErrorCode]);
                return;
            } else {
                if ([amsg isKindOfClass:[GroupCreateMessage class]]) {
                    /* process any pending group messages that could not be processed before this create */
                    [self processPendingGroupMessages:(GroupCreateMessage *)amsg];
                }
            }
            onCompletion();
            return;
        }

        // messages not handled by GroupProcessor, e.g. messages that can be processed after delayed group create
        ContactEntity *sender;
        ContactEntity *receiver;
        Conversation *conversation = [entityManager existingConversationSenderReceiverFor:amsg sender:&sender receiver:&receiver];

        if (sender == nil) {
            onError([ThreemaError threemaError:@"Sender not found as contact"]);
            return;
        }

        // Conversation must be there at this time, should be created with creation of the group
        if (conversation == nil) {
            onCompletion();
            return;
        }

        if ([amsg isKindOfClass:[GroupRenameMessage class]]) {
            GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
            [groupManager setNameObjcWithGroupID:amsg.groupId creator:amsg.groupCreator name:((GroupRenameMessage *)amsg).name systemMessageDate:amsg.date send:YES]
                .thenInBackground(^{
                    [self changedConversationAndGroupEntityWithGroupID:amsg.groupId groupCreatorIdentity:amsg.groupCreator];
                    onCompletion();
                }).catch(^(NSError *error){
                    onError(error);
                });
        } else if ([amsg isKindOfClass:[GroupSetPhotoMessage class]]) {
            [self processIncomingGroupSetPhotoMessage:(GroupSetPhotoMessage*)amsg onCompletion:onCompletion onError:onError];
        } else if ([amsg isKindOfClass:[GroupDeletePhotoMessage class]]) {
            GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
            [groupManager deletePhotoObjcWithGroupID:amsg.groupId creator:amsg.groupCreator sentDate:[amsg date] send:NO]
                .thenInBackground(^{
                    [self changedConversationAndGroupEntityWithGroupID:amsg.groupId groupCreatorIdentity:amsg.groupCreator];
                    onCompletion();
                })
                .catch(^(NSError *error){
                    onError(error);
                });
        } else if ([amsg isKindOfClass:[GroupTextMessage class]]) {
            TextMessage *message = (TextMessage *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
            if (message == nil) {
                onError([ThreemaError threemaError:@"Could not find/create text message"]);
                return;
            }

            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender onCompletion:onCompletion];
        } else if ([amsg isKindOfClass:[GroupLocationMessage class]]) {
            LocationMessage *message = (LocationMessage *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
            if (message == nil) {
                onError([ThreemaError threemaError:@"Could not find/create location message"]);
                return;
            }

            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender onCompletion:^{
                [self resolveAddressFor:message]
                    .thenInBackground(^{
                    onCompletion();
                });
            }];
        } else if ([amsg isKindOfClass:[GroupImageMessage class]]) {
            [self processIncomingImageMessage:(GroupImageMessage *)amsg sender:sender conversation:conversation onCompletion:onCompletion onError:onError];
        } else if ([amsg isKindOfClass:[GroupVideoMessage class]]) {
            [self processIncomingVideoMessage:(GroupVideoMessage*)amsg sender:sender conversation:conversation onCompletion:onCompletion onError:onError];
        } else if ([amsg isKindOfClass:[GroupAudioMessage class]]) {
            AudioMessageEntity *message = (AudioMessageEntity *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
            if (message == nil) {
                onError([ThreemaError threemaError:@"Could not find/create audio message"]);
                return;
            }

            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender onCompletion:onCompletion];
        } else if ([amsg isKindOfClass:[GroupBallotCreateMessage class]]) {
            BallotMessageDecoder *decoder = [[BallotMessageDecoder alloc] initWith:entityManager];
            BallotMessage *message = [decoder decodeCreateBallotFromGroupBox:(GroupBallotCreateMessage *)amsg sender:sender conversation:conversation];
            if (message == nil) {
                onError([ThreemaError threemaError:@"Could not find/create ballot message"]);
                return;
            }
            
            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender onCompletion:onCompletion];
        } else if ([amsg isKindOfClass:[GroupBallotVoteMessage class]]) {
            // TODO: This could be generate duplicate system messages, if message will processed multiple (race condition)
            [self processIncomingGroupBallotVoteMessage:(GroupBallotVoteMessage*)amsg onCompletion:onCompletion onError:onError];
        } else if ([amsg isKindOfClass:[GroupFileMessage class]]) {
            [FileMessageDecoder decodeGroupMessageFromBox:(GroupFileMessage *)amsg sender:sender conversation:conversation isReflectedMessage:NO timeoutDownloadThumbnail:timeoutDownloadThumbnail entityManager:entityManager onCompletion:^(BaseMessage *message) {
                [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender onCompletion:onCompletion];
            } onError:^(NSError *err) {
                onError(err);
            }];
        } else if ([amsg isKindOfClass:[GroupDeliveryReceiptMessage class]]) {
            [self processIncomingGroupDeliveryReceipt:(GroupDeliveryReceiptMessage*)amsg onCompletion:onCompletion];
        } else {
            onError([ThreemaError threemaError:@"Invalid message class"]);
        }
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (void)processIncomingForwardSecurityMessage:(ForwardSecurityEnvelopeMessage * _Nonnull)amsg senderPublicKey:(NSData*)senderPublicKey onCompletion:(void(^ _Nonnull)(AbstractMessage *unwrappedMessage))onCompletion onError:(void(^ _Nonnull)(NSError * error))onError {
    NSError *error = nil;
    ForwardSecurityContact *fsContact = [[ForwardSecurityContact alloc] initWithIdentity:amsg.fromIdentity publicKey:senderPublicKey];
    AbstractMessage *unwrappedMessage = [fsmp processEnvelopeMessageObjcWithSender:fsContact envelopeMessage:amsg errorP:&error];
    if (error != nil) {
        DDLogError(@"Processing forward security message failed: %@", error);
        onError(error);
        return;
    }
    onCompletion(unwrappedMessage);
}

- (void)finalizeMessage:(BaseMessage*)message inConversation:(Conversation*)conversation fromBoxMessage:(AbstractMessage*)boxMessage onCompletion:(void(^_Nonnull)(void))onCompletion {
    if ([ThreemaUtility supportsForwardSecurity]) {
        int systemMessageType = 0;
        NSNumber *contactForwardSecurityState = @0;

        if (message.forwardSecurityMode.intValue == kForwardSecurityModeNone &&
            conversation.contact.forwardSecurityState.intValue == kForwardSecurityStateOn) {
            // Contact has sent FS messages before, but this is not an FS message. Warn the user.
            systemMessageType = kSystemMessageFsMessageWithoutForwardSecurity;
            contactForwardSecurityState = [NSNumber numberWithInt:kForwardSecurityStateOff];
        } else if (message.forwardSecurityMode.intValue == kForwardSecurityModeFourDH &&
                   conversation.contact.forwardSecurityState.intValue == kForwardSecurityStateOff) {
            // Contact has sent the first 4DH message
            systemMessageType = conversation.contact.forwardSecurityEnabled.boolValue ? kSystemMessageFsSessionEstablished : kSystemMessageFsSessionEstablishedRcvd;
            contactForwardSecurityState = [NSNumber numberWithInt:kForwardSecurityStateOn];
        }

        if (systemMessageType != 0) {
            [entityManager performSyncBlockAndSafe:^{
                conversation.contact.forwardSecurityState = contactForwardSecurityState;

                SystemMessage *systemMessage = [entityManager.entityCreator systemMessageForConversation:conversation];
                systemMessage.type = [NSNumber numberWithInt:systemMessageType];
                systemMessage.remoteSentDate = [NSDate date];
                conversation.lastMessage = systemMessage;
                conversation.lastUpdate = [NSDate date];
            }];
        }
    }

    [messageProcessorDelegate incomingMessageChanged:message fromIdentity:boxMessage.fromIdentity];
    onCompletion();
}

- (void)finalizeGroupMessage:(BaseMessage*)message inConversation:(Conversation*)conversation fromBoxMessage:(AbstractGroupMessage*)boxMessage sender:(ContactEntity *)sender onCompletion:(void(^_Nonnull)(void))onCompletion {
    [messageProcessorDelegate incomingMessageChanged:message fromIdentity:boxMessage.fromIdentity];
    onCompletion();
}

- (void)conditionallyStartLoadingFileFromMessage:(FileMessageEntity*)message {
    BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
    [manager autoSyncBlobsFor:message.objectID];
}

- (void)processIncomingImageMessage:(nonnull AbstractMessage *)amsg sender:(nonnull ContactEntity *)sender conversation:(nonnull Conversation *)conversation onCompletion:(void(^ _Nonnull)(void))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    
    NSAssert([amsg isKindOfClass:[BoxImageMessage class]] || [amsg isKindOfClass:[GroupImageMessage class]], @"Abstract message type should be BoxImageMessage or GroupImageMessage");
    
    if ([amsg isKindOfClass:[BoxImageMessage class]] == NO && [amsg isKindOfClass:[GroupImageMessage class]] == NO) {
        onError([ThreemaError threemaError:@"Wrong message type, must be BoxImageMessage or GroupImageMessage"]);
        return;
    }

    BOOL isGroupMessage = [amsg isKindOfClass:[GroupImageMessage class]];

    ImageMessageEntity *msg = (ImageMessageEntity *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:nil];
    if (msg == nil) {
        onError([ThreemaError threemaError:@"Create image message failed"]);
        return;
    }

    if (conversation == nil) {
        onError([ThreemaError threemaError:@"Parameter 'conversation' should be not nil"]);
        return;
    }

    [messageProcessorDelegate incomingMessageChanged:msg fromIdentity:[sender identity]];

    dispatch_queue_t downloadQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    // An ImageMessage never has a local blob because all note group cabable devices send everything as FileMessage
    BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings] queue:downloadQueue];
    BlobDownloader *blobDownloader = [[BlobDownloader alloc] initWithBlobURL:blobUrl queue:downloadQueue];
    ImageMessageProcessor *processor = [[ImageMessageProcessor alloc] initWithBlobDownloader:blobDownloader serverConnector:[ServerConnector sharedServerConnector] myIdentityStore:[MyIdentityStore sharedMyIdentityStore] userSettings:[UserSettings sharedUserSettings] entityManager:entityManager];
    [processor downloadImageWithImageMessageID:msg.id in:conversation.objectID imageBlobID:msg.imageBlobId origin:BlobOriginPublic imageBlobEncryptionKey:msg.encryptionKey imageBlobNonce:msg.imageNonce senderPublicKey:sender.publicKey maxBytesToDecrypt:self->maxBytesToDecrypt timeoutDownloadThumbnail:timeoutDownloadThumbnail completion:^(NSError *error) {

        if (error != nil) {
            DDLogError(@"Could not process image message %@", error);
        }

        if (isGroupMessage == NO) {
            [self finalizeMessage:msg inConversation:conversation fromBoxMessage:amsg onCompletion:onCompletion];
        }
        else {
            [self finalizeGroupMessage:msg inConversation:conversation fromBoxMessage:(AbstractGroupMessage *)amsg sender:sender onCompletion:onCompletion];
        }
    }];
}

- (void)processIncomingVideoMessage:(nonnull AbstractMessage *)amsg sender:(nonnull ContactEntity *)sender conversation:(nonnull Conversation *)conversation onCompletion:(void(^ _Nonnull)(void))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    
    NSAssert([amsg isKindOfClass:[BoxVideoMessage class]] || [amsg isKindOfClass:[GroupVideoMessage class]], @"Abstract message type should be BoxVideoMessage or GroupVideoMessage");
    
    if ([amsg isKindOfClass:[BoxVideoMessage class]] == NO && [amsg isKindOfClass:[GroupVideoMessage class]] == NO) {
        onError([ThreemaError threemaError:@"Wrong message type, must be BoxVideoMessage or GroupVideoMessage"]);
        return;
    }

    if (conversation == nil) {
        onError([ThreemaError threemaError:@"Parameter 'conversation' should be not nil"]);
        return;
    }
    
    VideoMessageEntity *msg = (VideoMessageEntity *)[entityManager getOrCreateMessageFor:amsg sender:sender conversation:conversation thumbnail:[UIImage imageNamed:@"Video"]];
    if (msg == nil) {
        onError([ThreemaError threemaError:@"Create video message failed"]);
        return;
    }

    [messageProcessorDelegate incomingMessageChanged:msg fromIdentity:[sender identity]];

    BOOL isGroupMessage = [amsg isKindOfClass:[GroupVideoMessage class]];

    NSData *thumbnailBlobId;
    if (isGroupMessage == NO) {
        BoxVideoMessage *videoMessage = (BoxVideoMessage *)amsg;
        thumbnailBlobId = [videoMessage thumbnailBlobId];
    }
    else {
        GroupVideoMessage *videoMessage = (GroupVideoMessage *)amsg;
        thumbnailBlobId = [videoMessage thumbnailBlobId];
    }

    dispatch_queue_t downloadQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    // A VideoMessage never has a local blob because all note group capable devices send everything as FileMessage
    BlobURL *blobUrl = [[BlobURL alloc] initWithServerConnector:[ServerConnector sharedServerConnector] userSettings:[UserSettings sharedUserSettings] queue:downloadQueue];
    BlobDownloader *blobDownloader = [[BlobDownloader alloc] initWithBlobURL:blobUrl queue:downloadQueue];
    VideoMessageProcessor *processor = [[VideoMessageProcessor alloc] initWithBlobDownloader:blobDownloader serverConnector:[ServerConnector sharedServerConnector] entityManager:entityManager];
    [processor downloadVideoThumbnailWithVideoMessageID:msg.id in:conversation.objectID thumbnailBlobID:thumbnailBlobId origin:BlobOriginPublic maxBytesToDecrypt:self->maxBytesToDecrypt timeoutDownloadThumbnail:self->timeoutDownloadThumbnail completion:^(NSError *error) {

        if (error != nil) {
            DDLogError(@"Error while downloading video thumbnail: %@", error);
        }

        if (isGroupMessage == NO) {
            [self finalizeMessage:msg inConversation:conversation fromBoxMessage:amsg onCompletion:onCompletion];
        }
        else {
            [self finalizeGroupMessage:msg inConversation:conversation fromBoxMessage:(AbstractGroupMessage *)amsg sender:sender onCompletion:onCompletion];
        }
    }];
}

- (AnyPromise*)resolveAddressFor:(LocationMessage*)message {
    // Reverse geocoding (only necessary if there is no POI adress) /
    if (message.poiAddress != nil) {
        return [AnyPromise promiseWithResolverBlock:^(PMKResolver _Nonnull resolver) {
            resolver(nil);
        }];
    }

    // It should not result in a different address if we initialize the location with accuracies or not
    __block CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(message.latitude.doubleValue, message.longitude.doubleValue) altitude:0 horizontalAccuracy:message.accuracy.doubleValue verticalAccuracy:-1 timestamp:[NSDate date]];

    return [ThreemaUtility fetchAddressObjcFor:location]
        .thenInBackground(^(NSString *address){
            [entityManager performSyncBlockAndSafe:^{
                if ([message wasDeleted]) {
                    return;
                }

                message.poiAddress = address;
            }];
        });
}

- (void)processIncomingDeliveryReceipt:(DeliveryReceiptMessage*)msg onCompletion:(void(^ _Nonnull)(void))onCompletion {
    [entityManager performAsyncBlockAndSafe:^{
        for (NSData *receiptMessageId in msg.receiptMessageIds) {
            /* Fetch message from DB */
            BaseMessage *dbmsg = [entityManager.entityFetcher ownMessageWithId: receiptMessageId];
            if (dbmsg == nil) {
                /* This can happen if the user deletes the message before the receipt comes in */
                DDLogWarn(@"Cannot find message ID %@ (delivery receipt from %@)", receiptMessageId, msg.fromIdentity);
                continue;
            }
            
            if (msg.receiptType == DELIVERYRECEIPT_MSGRECEIVED) {
                DDLogWarn(@"Message ID %@ has been received by recipient", [NSString stringWithHexData:receiptMessageId]);
                dbmsg.deliveryDate = msg.date;
                dbmsg.delivered = [NSNumber numberWithBool:YES];
            } else if (msg.receiptType == DELIVERYRECEIPT_MSGREAD) {
                DDLogWarn(@"Message ID %@ has been read by recipient", [NSString stringWithHexData:receiptMessageId]);
                if (!dbmsg.delivered)
                    dbmsg.delivered = [NSNumber numberWithBool:YES];
                dbmsg.readDate = msg.date;
                dbmsg.read = [NSNumber numberWithBool:YES];
            } else if (msg.receiptType == DELIVERYRECEIPT_MSGUSERACK) {
                DDLogWarn(@"Message ID %@ has been user acknowledged by recipient", [NSString stringWithHexData:receiptMessageId]);
                dbmsg.userackDate = msg.date;
                dbmsg.userack = [NSNumber numberWithBool:YES];
            } else if (msg.receiptType == DELIVERYRECEIPT_MSGUSERDECLINE) {
                DDLogWarn(@"Message ID %@ has been user declined by recipient", [NSString stringWithHexData:receiptMessageId]);
                dbmsg.userackDate = msg.date;
                dbmsg.userack = [NSNumber numberWithBool:NO];
            } else {
                DDLogWarn(@"Unknown delivery receipt type %d with message ID %@", msg.receiptType, [NSString stringWithHexData:receiptMessageId]);
            }

            [messageProcessorDelegate changedManagedObjectID:dbmsg.objectID];
        }
        
        onCompletion();
    }];
}

- (void)processIncomingGroupDeliveryReceipt:(GroupDeliveryReceiptMessage*)msg onCompletion:(void(^ _Nonnull)(void))onCompletion {
    [entityManager performAsyncBlockAndSafe:^{
        for (NSData *receiptMessageId in msg.receiptMessageIds) {
            /* Fetch message from DB */
            Conversation *conversation = [entityManager.entityFetcher conversationForGroupId:msg.groupId creator:msg.groupCreator];
            if (conversation == nil) {
                DDLogWarn(@"Cannot find conversation for message ID %@ (group delivery receipt from %@)", receiptMessageId, msg.fromIdentity);
                continue;
            }
            
            BaseMessage *dbmsg = [entityManager.entityFetcher messageWithId:receiptMessageId conversation:conversation];
            if (dbmsg == nil) {
                /* This can happen if the user deletes the message before the receipt comes in */
                DDLogWarn(@"Cannot find message ID %@ (delivery receipt from %@)", receiptMessageId, msg.fromIdentity);
                continue;
            }
            
            if (msg.receiptType == GROUPDELIVERYRECEIPT_MSGUSERACK) {
                GroupDeliveryReceipt *groupDeliveryReceipt = [[GroupDeliveryReceipt alloc] initWithIdentity:msg.fromIdentity deliveryReceiptType:DeliveryReceiptTypeAcknowledged date:msg.date];
                [dbmsg addWithGroupDeliveryReceipt:groupDeliveryReceipt];
                DDLogWarn(@"Message ID %@ has been user acknowledged by %@", [NSString stringWithHexData:receiptMessageId], msg.fromIdentity);
            }
            else if (msg.receiptType == GROUPDELIVERYRECEIPT_MSGUSERDECLINE) {
                GroupDeliveryReceipt *groupDeliveryReceipt = [[GroupDeliveryReceipt alloc] initWithIdentity:msg.fromIdentity deliveryReceiptType:DeliveryReceiptTypeDeclined date:msg.date];
                [dbmsg addWithGroupDeliveryReceipt:groupDeliveryReceipt];
                DDLogWarn(@"Message ID %@ has been user declined by %@", [NSString stringWithHexData:receiptMessageId], msg.fromIdentity);
            }
            else {
                DDLogWarn(@"Unknown group delivery receipt type %d with message ID %@", msg.receiptType, [NSString stringWithHexData:receiptMessageId]);
            }
            
            [messageProcessorDelegate changedManagedObjectID:dbmsg.objectID];
        }
        
        onCompletion();
    }];
}

- (void)processIncomingTypingIndicator:(TypingIndicatorMessage*)msg {
    [messageProcessorDelegate processTypingIndicator:msg]; 
}

- (void)processIncomingGroupSetPhotoMessage:(GroupSetPhotoMessage*)msg onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
    Group *group = [groupManager getGroup:msg.groupId creator:msg.groupCreator];
    if (group == nil) {
        DDLogInfo(@"Group ID %@ from %@ not found", msg.groupId, msg.groupCreator);
        onCompletion();
        return;
    } else {
        /* Start loading image */
        ContactGroupPhotoLoader *loader = [[ContactGroupPhotoLoader alloc] init];
        [loader startWithBlobId:msg.blobId encryptionKey:msg.encryptionKey origin:BlobOriginPublic onCompletion:^(NSData *imageData) {
            DDLogInfo(@"Group photo blob load completed");

            // Initialize new GroupManager with EntityManager on main context, becaus this completion handler runs on main queue
            GroupManager *grpManager = [[GroupManager alloc] initWithEntityManager:[[EntityManager alloc] init]];
            [grpManager setPhotoObjcWithGroupID:msg.groupId creator:msg.groupCreator imageData:imageData sentDate:msg.date send:NO]
                .thenInBackground(^{
                    [self changedConversationAndGroupEntityWithGroupID:msg.groupId groupCreatorIdentity:msg.groupCreator];
                    onCompletion();
                }).catch(^(NSError *error){
                    onError(error);
            });
        } onError:^(NSError *err) {
            DDLogError(@"Group photo blob load failed with error: %@", err);
            onError(err);
        }];
    }
}

- (void)processIncomingGroupBallotVoteMessage:(GroupBallotVoteMessage*)msg onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    /* Create Message in DB */
    BallotMessageDecoder *decoder = [[BallotMessageDecoder alloc] initWith:entityManager];
    if ([decoder decodeVoteFromGroupBox: msg] == NO) {
        onError([ThreemaError threemaError:@"Error processing ballot vote"]);
        return;
    }
    
    //persist decoded data
    [entityManager performAsyncBlockAndSafe:nil];
    
    [self changedBallotWithID:msg.ballotId];

    onCompletion();
}

- (void)processIncomingBallotVoteMessage:(BoxBallotVoteMessage*)msg onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    /* Create Message in DB */
    BallotMessageDecoder *decoder = [[BallotMessageDecoder alloc] initWith:entityManager];
    if ([decoder decodeVoteFromBox: msg] == NO) {
        onError([ThreemaError threemaError:@"Error parsing json for ballot vote"]);
        return;
    }
    
    //persist decoded data
    [entityManager performSyncBlockAndSafe:nil];

    [self changedBallotWithID:msg.ballotId];

    onCompletion();
}

- (void)processPendingGroupMessages:(GroupCreateMessage *)groupCreateMessage {
    DDLogVerbose(@"Processing pending group messages");
    __block NSArray *messages;

    dispatch_sync(pendingGroupMessagesQueue, ^{
        messages = [pendingGroupMessages array];
    });

    if (messages != nil) {
        DDLogInfo(@"[Push] Pending group count: %lu", [messages count]);

        for (AbstractGroupMessage *msg in messages) {
            if ([msg.groupId isEqualToData:groupCreateMessage.groupId] && [msg.groupCreator isEqualToString:groupCreateMessage.groupCreator]) {
                if ([[groupCreateMessage groupMembers] containsObject:[[MyIdentityStore sharedMyIdentityStore] identity]]) {
                    DDLogInfo(@"[Push] Pending group message process %@ %@", msg.messageId, msg.description);
                    [self processIncomingAbstractMessage:msg onCompletion:^(AbstractMessage *amsg) {
                        if (amsg != nil) {
                            // Successfully processed ack message
                            [[ServerConnector sharedServerConnector] completedProcessingAbstractMessage:amsg];
                        }

                        dispatch_sync(pendingGroupMessagesQueue, ^{
                            DDLogInfo(@"[Push] Pending group message remove %@ %@", msg.messageId, msg.description);
                            [pendingGroupMessages removeObject:msg];
                        });
                    } onError:^(NSError *err) {
                        DDLogWarn(@"Processing pending group message failed: %@", err);
                    }];
                }
                else {
                    // I am not in the group ack message
                    [[ServerConnector sharedServerConnector] completedProcessingAbstractMessage:msg];

                    dispatch_sync(pendingGroupMessagesQueue, ^{
                        DDLogInfo(@"[Push] Pending group message remove %@ %@", msg.messageId, msg.description);
                        [pendingGroupMessages removeObject:msg];
                    });
                }
            }
        }
    }
}

- (void)processIncomingContactSetPhotoMessage:(ContactSetPhotoMessage *)msg onCompletion:(void(^ _Nonnull)(void))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    /* Start loading image */
    ContactGroupPhotoLoader *loader = [[ContactGroupPhotoLoader alloc] init];
    
    [loader startWithBlobId:msg.blobId encryptionKey:msg.encryptionKey origin:BlobOriginPublic onCompletion:^(NSData *imageData) {
        DDLogInfo(@"contact photo blob load completed");

        // TODO call completion handler if async update profile pic is finished
        NSError *error;
        [[ContactStore sharedContactStore] updateProfilePicture:msg.fromIdentity imageData:imageData shouldReflect:YES didFailWithError:&error];
        
        if (error != nil) {
            onError(error);
            return;
        }

        [self changedContactWithIdentity:msg.fromIdentity];

        onCompletion();
    } onError:^(NSError *err) {
        DDLogError(@"Contact photo blob load failed with error: %@", err);
        if (err.code == 404)
            onCompletion();
        onError(err);
    }];
}

- (void)processIncomingContactDeletePhotoMessage:(ContactDeletePhotoMessage *)msg onCompletion:(void(^ _Nonnull)(void))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    [[ContactStore sharedContactStore] deleteProfilePicture:msg.fromIdentity shouldReflect:NO];
    [self changedContactWithIdentity:msg.fromIdentity];
    onCompletion();
}

- (void)processIncomingContactRequestPhotoMessage:(ContactRequestPhotoMessage *)msg onCompletion:(void(^ _Nonnull)(void))onCompletion {
    [[ContactStore sharedContactStore] removeProfilePictureFlagForIdentity:msg.fromIdentity];
    onCompletion();
}


- (void)processIncomingVoIPCallOfferMessage:(BoxVoIPCallOfferMessage *)msg onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nullable delegate))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    VoIPCallOfferMessage *message = [VoIPCallMessageDecoder decodeVoIPCallOfferFrom:msg];
    if (message == nil) {
        onError([ThreemaError threemaError:@"Error parsing json for voip call offer"]);
        return;
    }
    
    [messageProcessorDelegate processVoIPCall:message identity:msg.fromIdentity onCompletion:^(id<MessageProcessorDelegate>  _Nonnull delegate) {
        onCompletion(delegate);
    }];
}

- (void)processIncomingVoIPCallAnswerMessage:(BoxVoIPCallAnswerMessage *)msg onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nullable delegate))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    VoIPCallAnswerMessage *message = [VoIPCallMessageDecoder decodeVoIPCallAnswerFrom:msg];
    if (message == nil) {
        onError([ThreemaError threemaError:@"Error parsing json for ballot vote"]);
        return;
    }

    [messageProcessorDelegate processVoIPCall:message identity:msg.fromIdentity onCompletion:^(id<MessageProcessorDelegate>  _Nonnull delegate) {
        onCompletion(delegate);
    }];
}

- (void)processIncomingVoIPCallIceCandidatesMessage:(BoxVoIPCallIceCandidatesMessage *)msg onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nullable delegate))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    VoIPCallIceCandidatesMessage *message = [VoIPCallMessageDecoder decodeVoIPCallIceCandidatesFrom:msg];
    if (message == nil) {
        onError([ThreemaError threemaError:@"Error parsing json for ice candidates"]);
        return;
    }

    [messageProcessorDelegate processVoIPCall:message identity:msg.fromIdentity onCompletion:^(id<MessageProcessorDelegate>  _Nonnull delegate) {
        onCompletion(delegate);
    }];
}

- (void)processIncomingVoIPCallHangupMessage:(BoxVoIPCallHangupMessage *)msg onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nullable delegate))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    VoIPCallHangupMessage *message = [VoIPCallMessageDecoder decodeVoIPCallHangupFrom:msg contactIdentity:msg.fromIdentity];
    
    if (message == nil) {
        onError([ThreemaError threemaError:@"Error parsing json for hangup"]);
        return;
    }
    
    [messageProcessorDelegate processVoIPCall:message identity:nil onCompletion:^(id<MessageProcessorDelegate>  _Nullable delegate) {
        onCompletion(delegate);
    }];
}

- (void)processIncomingVoipCallRingingMessage:(BoxVoIPCallRingingMessage *)msg onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nullable delegate))onCompletion onError:(void(^ _Nonnull)(NSError *err))onError {
    VoIPCallRingingMessage *message = [VoIPCallMessageDecoder decodeVoIPCallRingingFrom:msg contactIdentity:msg.fromIdentity];

    if (message == nil) {
        onError([ThreemaError threemaError:@"Error parsing json for ringing"]);
        return;
    }
    
    [messageProcessorDelegate processVoIPCall:message identity:nil onCompletion:^(id<MessageProcessorDelegate>  _Nonnull delegate) {
        onCompletion(delegate);
    }];
}


#pragma private methods

/// Check is the sender in the black list. If it's a group control message and the sender is on the black list, we will process the message if the group is still active on the receiver side
/// @param amsg Decoded abstract message
- (BOOL)isBlacklisted:(AbstractMessage *)amsg {
    if ([[UserSettings sharedUserSettings].blacklist containsObject:amsg.fromIdentity]) {
        if ([amsg isKindOfClass:[AbstractGroupMessage class]]) {
            AbstractGroupMessage *groupMessage = (AbstractGroupMessage *)amsg;
            GroupManager *groupManager = [[GroupManager alloc] initWithEntityManager:entityManager];
            Group *group = [groupManager getGroup:groupMessage.groupId creator:groupMessage.groupCreator];
            
            // If this group is active and the message is a group control message (create, leave, requestSync, Rename, SetPhoto, DeletePhoto)
            if (group.isSelfMember && [groupMessage isGroupControlMessage]) {
                    return false;
            }
        }
        
        return true;
    }
    return false;
}

-  (void)changedBallotWithID:(NSData * _Nonnull)ID {
    [entityManager performBlockAndWait:^{
        Ballot *ballot = [[entityManager entityFetcher] ballotForBallotId:ID];
        if (ballot) {
            [messageProcessorDelegate changedManagedObjectID:ballot.objectID];
        }
    }];
}

- (void)changedContactWithIdentity:(NSString * _Nonnull)identity {
    [entityManager performBlockAndWait:^{
        ContactEntity *contact = [entityManager.entityFetcher contactForId:identity];
        if (contact) {
            [messageProcessorDelegate changedManagedObjectID:contact.objectID];
        }
    }];
}

- (void)changedConversationAndGroupEntityWithGroupID:(NSData * _Nonnull)groupID groupCreatorIdentity:(NSString * _Nonnull)groupCreatorIdentity {
    [entityManager performBlockAndWait:^{
        Conversation *conversation = [entityManager.entityFetcher conversationForGroupId:groupID creator:groupCreatorIdentity];
        if (conversation) {
            [messageProcessorDelegate changedManagedObjectID:conversation.objectID];

            GroupEntity *groupEntity = [[entityManager entityFetcher] groupEntityForConversation:conversation];
            if (groupEntity) {
                [messageProcessorDelegate changedManagedObjectID:groupEntity.objectID];
            }
        }
    }];
}

@end
