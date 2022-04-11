//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import "Threema-Swift.h"

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
#import "GroupRequestSyncMessage.h"
#import "LocationMessage.h"
#import "TextMessage.h"
#import "ImageMessage.h"
#import "VideoMessage.h"
#import "AudioMessage.h"
#import "BoxFileMessage.h"
#import "GroupFileMessage.h"
#import "ContactSetPhotoMessage.h"
#import "ContactDeletePhotoMessage.h"
#import "ContactRequestPhotoMessage.h"
#import "GroupDeletePhotoMessage.h"

#import "UnknownTypeMessage.h"

#import "Contact.h"
#import "Conversation.h"
#import "ImageData.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "ProtocolDefines.h"
#import "UserSettings.h"
#import "TypingIndicatorManager.h"
#import "MyIdentityStore.h"
#import "NSString+Hex.h"
#import "ImageMessageLoader.h"
#import "AnimGifMessageLoader.h"
#import "ContactGroupPhotoLoader.h"
#import "NaClCrypto.h"
#import "PinnedHTTPSURLLoader.h"
#import "ValidationLogger.h"
#import "BallotMessageDecoder.h"
#import "BlobUtil.h"
#import "GroupProxy.h"
#import "EntityManager.h"
#import "MessageSender.h"
#import "GroupMessageProcessor.h"
#import "ThreemaError.h"
#import "DatabaseManager.h"
#import "FileMessageDecoder.h"
#import "UTIConverter.h"
#import "DocumentManager.h"
#import "VoIPCallMessageDecoder.h"
#import "BoxVoIPCallIceCandidatesMessage.h"
#import "BoxVoIPCallHangupMessage.h"
#import "BoxVoIPCallRingingMessage.h"
#import "NotificationManager.h"
#import "PushSetting.h"
#import "NonceHasher.h"

#import "UIDefines.h"

#import "ServerConnector.h"
#import "AppGroup.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface MessageProcessor () <GroupMessageProcessorDelegate>

@property EntityManager *entityManager;

@property NSMutableOrderedSet *pendingGroupMessages;

@end

@implementation MessageProcessor

+ (MessageProcessor*)sharedMessageProcessor {
    static MessageProcessor *instance;
    
    @synchronized (self) {
        if (!instance) {
            instance = [[MessageProcessor alloc] init];
        }
    }
    
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pendingGroupMessages = [[NSMutableOrderedSet alloc] init];
        
        _entityManager = [[EntityManager alloc] init];
    }
    return self;
}

- (void)processIncomingMessage:(BoxedMessage*)boxmsg receivedAfterInitialQueueSend:(BOOL)receivedAfterInitialQueueSend onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    /* blacklisted? */
    if ([[UserSettings sharedUserSettings].blacklist containsObject:boxmsg.fromIdentity]) {
        DDLogWarn(@"Ignoring message from blocked ID %@", boxmsg.fromIdentity);
        onError([ThreemaError threemaError:@"Message received from blocked contact" withCode:kBlockUnknownContactErrorCode]);
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[ValidationLogger sharedValidationLogger] logString:@"Threema Web: processIncomingMessage --> connect all running sessions"];
        [[WCSessionManager shared] connectAllRunningSessions];
        [MessageDecoder decodeFromBoxed:boxmsg isIncomming:YES onCompletion:^(AbstractMessage *amsg) {
            if (amsg == nil) {
                onError([ThreemaError threemaError:@"Bad message format or decryption error" withCode:kBadMessageErrorCode]);
                return;
            }
            
            if ([amsg isKindOfClass: [UnknownTypeMessage class]]) {
                onError([ThreemaError threemaError:@"Unknown message type" withCode:kUnknownMessageTypeErrorCode]);
                return;
            }
            
            // Validation logging
            if ([amsg isContentValid] == NO) {
                if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                    [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Ignore invalid content"];
                } else {
                    [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:@"Ignore invalid content"];
                }
            } else {
                if ([_entityManager.entityFetcher isMessageAlreadyInDb:amsg]) {
                    if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                        [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Message already in database"];
                    } else {
                        [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:@"Message already in database"];
                    }
                } else {
                    if ([_entityManager.entityFetcher isNonceAlreadyInDb:amsg]) {
                        if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                            [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:@"Nonce already in database"];
                        } else {
                            [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:@"Nonce already in database"];
                        }
                    } else {
                        if ([amsg isKindOfClass:[BoxTextMessage class]] || [amsg isKindOfClass:[GroupTextMessage class]]) {
                            [[ValidationLogger sharedValidationLogger] logBoxedMessage:boxmsg isIncoming:YES description:nil];
                        } else {
                            [[ValidationLogger sharedValidationLogger] logSimpleMessage:amsg isIncoming:YES description:nil];
                        }
                    }
                }
            }
            
            amsg.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend;
            
            [self processIncomingAbstractMessage:amsg onCompletion:onCompletion onError:onError];
        } onError:^(NSError *err) {
            onError(err);
        }];
    });
}

- (void)processIncomingAbstractMessage:(AbstractMessage*)amsg onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    if ([amsg isContentValid] == NO) {
        DDLogInfo(@"Ignore invalid content, message ID %@ from %@", amsg.messageId, amsg.fromIdentity);
        onCompletion();
        return;
    }
    
    if ([_entityManager.entityFetcher isMessageAlreadyInDb:amsg]) {
        DDLogInfo(@"Message ID %@ from %@ already in database", amsg.messageId, amsg.fromIdentity);
        onCompletion();
        return;
    }
    
    if ([_entityManager.entityFetcher isNonceAlreadyInDb:amsg]) {
        DDLogInfo(@"Message nonce from %@ already in database", amsg.fromIdentity);
        onCompletion();
        return;
    }
    
    /* Find contact for message */
    Contact *contact = [_entityManager.entityFetcher contactForId: amsg.fromIdentity];
    if (contact == nil) {
        /* This should never happen, as without an entry in the contacts database, we wouldn't have
         been able to decrypt this message in the first place (no sender public key) */
        DDLogWarn(@"Identity %@ not in local contacts database - cannot process message", amsg.fromIdentity);
        NSError *error = [ThreemaError threemaError:[NSString stringWithFormat:@"Identity %@ not in local contacts database - cannot process message", amsg.fromIdentity]];
        onError(error);
        return;
    }
    
    /* Update public nickname in contact, if necessary */
    if (amsg.pushFromName.length > 0 && ![contact.identity isEqualToString:amsg.pushFromName] && ![contact.publicNickname isEqualToString:amsg.pushFromName]) {
        contact.publicNickname = amsg.pushFromName;
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationRefreshContactSortIndices object:nil];
    }
    
    DDLogVerbose(@"processIncomingMessage: %@", amsg);
    
    [[PendingMessagesManager shared] pendingMessageWithSenderId:nil messageId:nil abstractMessage:amsg threemaDict:nil completion:^(PendingMessage *pendingMessage) {
        @try {
            pendingMessage.isPendingGroupMessages = false;
            if ([amsg isKindOfClass:[AbstractGroupMessage class]]) {
                [self processIncomingGroupMessage:(AbstractGroupMessage *)amsg pendingMessage:pendingMessage onCompletion:^{
                    [_entityManager performSyncBlockAndSafe:^{
                        [_entityManager.entityCreator nonceWithData:[NonceHasher hashedNonce:amsg.nonce]];
                    }];
                    onCompletion();
                } onError:onError];
            } else  {
                [self processIncomingMessage:(AbstractMessage *)amsg pendingMessage:pendingMessage onCompletion:^{
                    if (!amsg.immediate) {
                        [_entityManager performSyncBlockAndSafe:^{
                            [_entityManager.entityCreator nonceWithData:[NonceHasher hashedNonce:amsg.nonce]];
                        }];
                    }
                    onCompletion();
                } onError:onError];
            }
        } @catch (NSException *exception) {
            NSError *error = [ThreemaError threemaError:exception.description withCode:kMessageProcessingErrorCode];
            onError(error);
        } @catch (NSError *error) {
            onError(error);
        }
    }];
}

- (void)processIncomingMessage:(AbstractMessage*)amsg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    Conversation *conversation = [self preprocessStorableMessage:amsg];
    if ([amsg needsConversation] && conversation == nil) {
        [pendingMessage finishedProcessing];
        onCompletion();
        
        return;
    }
    
    
    BOOL ackNow = YES;
    
    if ([amsg isKindOfClass:[BoxTextMessage class]]) {
        TextMessage *message = [_entityManager.entityCreator textMessageFromBox: amsg];
        [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:nil];
    } else if ([amsg isKindOfClass:[BoxImageMessage class]]) {
        ImageMessage *message = [_entityManager.entityCreator imageMessageFromBox:(BoxImageMessage*)amsg];
        
        NSData *fileData = nil;
        NSData *decryptedData = nil;
        NSString *filePath = [self filePath:amsg];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            fileData = [[NSFileManager defaultManager] contentsAtPath:filePath];
        }
        
        if (fileData) {
            if ([message wasDeleted]) {
                [pendingMessage finishedProcessing];
                return;
            }
            message.conversation = conversation;
            
            [self decryptImageFile:fileData message:message onCompletion:^(NSData *decrypted) {
                NSError *error;
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
                
                [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:^{
                    if (!decrypted)
                        [self startLoadingImageFromMessage:message boxMessage:amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
                }];
            }];
        } else {
            [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:^{
                if (!decryptedData)
                    [self startLoadingImageFromMessage:message boxMessage:amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
            }];
        }
    } else if ([amsg isKindOfClass:[BoxVideoMessage class]]) {
        [self processIncomingVideoMessage:(BoxVideoMessage*)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
        ackNow = NO; // Only ACK video message once thumbnail has been downloaded, otherwise a failed blob download will lead to a missing message
        
    } else if ([amsg isKindOfClass:[BoxLocationMessage class]]) {
        LocationMessage *message = [_entityManager.entityCreator locationMessageFromBox:(BoxLocationMessage*)amsg];
        [self startReverserGeocodingForMessage:message];
        [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:nil];
        
    } else if ([amsg isKindOfClass:[BoxAudioMessage class]]) {
        AudioMessage *message = [_entityManager.entityCreator audioMessageFromBox:(BoxAudioMessage*) amsg];
        [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:nil];
        
    } else if ([amsg isKindOfClass:[DeliveryReceiptMessage class]]) {
        [self processIncomingDeliveryReceipt:(DeliveryReceiptMessage*)amsg pendingMessage:pendingMessage];
        
    } else if ([amsg isKindOfClass:[TypingIndicatorMessage class]]) {
        [self processIncomingTypingIndicator:(TypingIndicatorMessage*)amsg];
        [pendingMessage finishedProcessing];
    } else if ([amsg isKindOfClass:[BoxBallotCreateMessage class]]) {
        BallotMessageDecoder *decoder = [BallotMessageDecoder messageDecoder];
        BallotMessage *ballotMessage = [decoder decodeCreateBallotFromBox:(BoxBallotCreateMessage *)amsg forConversation:conversation];
        if (ballotMessage == nil) {
            NSError *error = [ThreemaError threemaError:@"Error parsing json for ballot create"];
            [pendingMessage finishedProcessing];
            onError(error);
            return;
        }
        
        [self finalizeMessage:ballotMessage inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:nil];
    } else if ([amsg isKindOfClass:[BoxBallotVoteMessage class]]) {
        [self processIncomingBallotVoteMessage:(BoxBallotVoteMessage*)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
        ackNow = NO;
        
    } else if ([amsg isKindOfClass:[BoxFileMessage class]]) {
        [FileMessageDecoder decodeMessageFromBox:(BoxFileMessage *)amsg forConversation:conversation onCompletion:^(BaseMessage *message) {
            [self conditionallyStartLoadingFileFromMessage:(FileMessage *)message];
            [self finalizeMessage:message inConversation:conversation fromBoxMessage:amsg pendingMessage:pendingMessage finalizeCompletion:nil];
        } onError:^(NSError *err) {
            [pendingMessage finishedProcessing];
            onError(err);
        }];
    } else if ([amsg isKindOfClass:[ContactSetPhotoMessage class]]) {
        [self processIncomingContactSetPhotoMessage:(ContactSetPhotoMessage *)amsg conversation:(Conversation *)conversation pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
        ackNow = NO; // Only ACK message (not blob) once contact photo has been downloaded, otherwise a failed blob download will lead to a missing message
    } else if ([amsg isKindOfClass:[ContactDeletePhotoMessage class]]) {
        [self processIncomingContactDeletePhotoMessage:(ContactDeletePhotoMessage *)amsg conversation:(Conversation *)conversation pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[ContactRequestPhotoMessage class]]) {
        [self processIncomingContactRequestPhotoMessage:(ContactRequestPhotoMessage *)amsg pendingMessage:pendingMessage onCompletion:onCompletion];
    } else if ([amsg isKindOfClass:[BoxVoIPCallOfferMessage class]]) {
        [self processIncomingVoIPCallOfferMessage:(BoxVoIPCallOfferMessage *)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallAnswerMessage class]]) {
        [self processIncomingVoIPCallAnswerMessage:(BoxVoIPCallAnswerMessage *)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallIceCandidatesMessage class]]) {
        [self processIncomingVoIPCallIceCandidatesMessage:(BoxVoIPCallIceCandidatesMessage *)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallHangupMessage class]]) {
        [self processIncomingVoIPCallHangupMessage:(BoxVoIPCallHangupMessage *)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
    } else if ([amsg isKindOfClass:[BoxVoIPCallRingingMessage class]]) {
        [self processIncomingVoipCallRingingMessage:(BoxVoIPCallRingingMessage *)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
    }
    else {
        DDLogError(@"Invalid message class");
        [pendingMessage finishedProcessing];
        return;
    }
    
    if (ackNow) {
        onCompletion();
    }
}

- (Conversation*)preprocessStorableMessage:(AbstractMessage*)msg {
    Contact *contact = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
    
    /* Try to find an existing Conversation for the same contact */
    // check if type allow to create the conversation
    Conversation *conversation = [_entityManager conversationForContact: contact createIfNotExisting:[msg canCreateConversation]];
    
    return conversation;
}


- (void)processIncomingGroupMessage:(AbstractGroupMessage*)amsg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    GroupMessageProcessor *groupProcessor = [GroupMessageProcessor groupMessageProcessorForMessage:amsg];
    groupProcessor.delegate = self;
    [groupProcessor handleMessageOnCompletion:^(BOOL didHandleMessage) {
        if (didHandleMessage) {
            Conversation *conversation = [_entityManager.entityFetcher conversationForGroupMessage:amsg];
            if (groupProcessor.addToPendingMessages) {
                [_pendingGroupMessages addObject:amsg];
                pendingMessage.isPendingGroupMessages = true;
                [pendingMessage finishedProcessing];
                [[NotificationManager sharedInstance] updateUnreadMessagesCount:NO];
                onError(nil);
                return;
            } else {
                if (groupProcessor.rejectMessage) {
                    [pendingMessage finishedProcessingWithRejected:true];
                    onCompletion();
                    return;
                } else {
                    if (groupProcessor.isNewGroup || !conversation) {
                        /* process any pending group messages that could not be processed before this create */
                        [self processPendingGroupMessages];
                    }
                }
            }

            // Do only show a notification, if there a group and i'm not left
            GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
            if (group && group.didLeaveGroup == NO) {
                [pendingMessage finishedProcessing];
            }
            else {
                [pendingMessage finishedProcessingWithRejected:YES];
            }
            onCompletion();
            return;
        }
        // messages not handled by GroupProcessor, e.g. messages that can be processed after delayed group create
        Conversation *conversation = groupProcessor.conversation;

        if (conversation == nil) {
            [pendingMessage finishedProcessing];
            onCompletion();
            return;
        }
        
        Contact *sender = [_entityManager.entityFetcher contactForId: amsg.fromIdentity];
        
        BOOL ackNow = YES;
        if ([amsg isKindOfClass:[GroupRenameMessage class]]) {
            GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
            [group setName: ((GroupRenameMessage *)amsg).name remoteSentDate:amsg.date];
            [pendingMessage finishedProcessing];
        } else if ([amsg isKindOfClass:[GroupSetPhotoMessage class]]) {
            [self processIncomingGroupSetPhotoMessage:(GroupSetPhotoMessage*)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
            ackNow = NO; // Only ACK message once group photo has been downloaded, otherwise a failed blob download will lead to a missing message
        } else if ([amsg isKindOfClass:[GroupDeletePhotoMessage class]]) {
            [self processIncomingGroupDeletePhotoMessage:(GroupDeletePhotoMessage*)amsg pendingMessage:pendingMessage onCompletion:onCompletion];
        } else if ([amsg isKindOfClass:[GroupTextMessage class]]) {
            TextMessage *message = [_entityManager.entityCreator textMessageFromGroupBox: (GroupTextMessage *)amsg];
            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:nil];
            
        } else if ([amsg isKindOfClass:[GroupLocationMessage class]]) {
            LocationMessage *message = [_entityManager.entityCreator locationMessageFromGroupBox:(GroupLocationMessage *)amsg];
            [self startReverserGeocodingForMessage:message];
            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:nil];
            
        } else if ([amsg isKindOfClass:[GroupImageMessage class]]) {
            ImageMessage *message = [_entityManager.entityCreator imageMessageFromGroupBox:(GroupImageMessage *)amsg];
            NSData *fileData = nil;
            NSData *decryptedData = nil;
            NSString *filePath = [self filePath:amsg];
            if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                fileData = [[NSFileManager defaultManager] contentsAtPath:filePath];
            }
            
            if (fileData) {
                if ([message wasDeleted]) {
                    return;
                }
                message.conversation = conversation;
                
                [self decryptImageFile:fileData message:message onCompletion:^(NSData *decrypted) {
                    NSError *error;
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
                    
                    [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:^{
                        if (!decrypted)
                            [self startLoadingImageFromMessage:message boxMessage:amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
                    }];
                }];
            } else {
                [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:^{
                    if (!decryptedData)
                        [self startLoadingImageFromMessage:message boxMessage:amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
                }];
            }
        } else if ([amsg isKindOfClass:[GroupVideoMessage class]]) {
            [self processIncomingGroupVideoMessage:(GroupVideoMessage*)amsg conversation:conversation pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
            ackNow = NO; // Only ACK video message once thumbnail has been downloaded, otherwise a failed blob download will lead to a missing message
            
        } else if ([amsg isKindOfClass:[GroupAudioMessage class]]) {
            AudioMessage *message = [_entityManager.entityCreator audioMessageFromGroupBox:(GroupAudioMessage *)amsg];
            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:nil];
            
        } else if ([amsg isKindOfClass:[GroupBallotCreateMessage class]]) {
            BallotMessageDecoder *decoder = [BallotMessageDecoder messageDecoder];
            BallotMessage *message = [decoder decodeCreateBallotFromGroupBox:(GroupBallotCreateMessage *)amsg forConversation:conversation];
            if (message == nil) {
                NSError *error = [ThreemaError threemaError:@"Error parsing json for ballot create"];
                [pendingMessage finishedProcessing];
                onError(error);
                return;
            }
            
            [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:nil];
        } else if ([amsg isKindOfClass:[GroupBallotVoteMessage class]]) {
            [self processIncomingGroupBallotVoteMessage:(GroupBallotVoteMessage*)amsg pendingMessage:pendingMessage onCompletion:onCompletion onError:onError];
            ackNow = NO;
            
        } else if ([amsg isKindOfClass:[GroupFileMessage class]]) {
            [FileMessageDecoder decodeGroupMessageFromBox:(GroupFileMessage *)amsg forConversation:conversation onCompletion:^(BaseMessage *message) {
                [self conditionallyStartLoadingFileFromMessage:(FileMessage *)message];
                [self finalizeGroupMessage:message inConversation:conversation fromBoxMessage:amsg sender:sender pendingMessage:pendingMessage finalizeCompletion:nil];
            } onError:^(NSError *err) {
                [pendingMessage finishedProcessing];
                onError(err);
            }];
        } else {
            DDLogError(@"Invalid message class");
            [pendingMessage finishedProcessing];
        }
        
        if (ackNow) {
            onCompletion();
        }
    } onError:^(NSError *error) {
        onError(error);
    }];
}

- (void)appendNewMessage:(BaseMessage *)message toConversation:(Conversation *)conversation {
    [_entityManager performSyncBlockAndSafe:^{
        message.conversation = conversation;
        if (message != nil) {
            conversation.lastMessage = message;
        }
        [self increateUnreadMessageCount:conversation];
    }];
}

- (void)finalizeMessage:(BaseMessage*)message inConversation:(Conversation*)conversation fromBoxMessage:(AbstractMessage*)boxMessage pendingMessage:(PendingMessage *)pendingMessage finalizeCompletion:(void (^) (void))finalizeCompletion {
    
    if (boxMessage.delivered && boxMessage.deliveryDate != nil) {
        message.delivered = boxMessage.delivered;
        message.deliveryDate = boxMessage.deliveryDate;
    } else {
        /* Send delivery receipt */
        message.delivered = [NSNumber numberWithBool:YES];
        message.deliveryDate = [NSDate date];
        [MessageSender sendDeliveryReceiptForMessage:message fromIdentity:boxMessage.fromIdentity];
    }
    
    [self appendNewMessage:message toConversation:conversation];
    [pendingMessage addBaseMessageWithMessage:message];
    
    if (boxMessage.userAck && boxMessage.sendUserAck) {
        if (message.userackDate == nil || message.userack.boolValue != boxMessage.userAck.boolValue) {
            [_entityManager performSyncBlockAndSafe:^{
                @try {
                    message.read = [NSNumber numberWithBool:YES];
                    message.readDate = [NSDate date];
                    message.conversation.unreadMessageCount = [NSNumber numberWithInt:[[message.conversation unreadMessageCount] intValue] - 1];
                }
                @catch (NSException *exception) {
                    // intended to catch NSObjectInaccessibleException, which may happen
                    // if the message has been deleted in the meantime
                    DDLogError(@"Exception while marking message as read: %@", exception);
                }
            }];
            
            if ([ServerConnector sharedServerConnector].connectionState == ConnectionStateLoggedIn) {
                [MessageSender sendReadReceiptForMessages:@[message] toIdentity:message.conversation.contact.identity async:NO quickReply:NO];
            }
            
            [_entityManager performSyncBlockAndSafe:^{
                if (boxMessage.userAck.boolValue) {
                    [MessageSender sendUserAckForMessages:@[message] toIdentity:message.conversation.contact.identity async:NO quickReply:YES];
                    message.userack = [NSNumber numberWithBool:YES];
                } else {
                    [MessageSender sendUserDeclineForMessages:@[message] toIdentity:message.conversation.contact.identity async:NO quickReply:YES];
                    message.userack = [NSNumber numberWithBool:NO];
                }
                
                message.userackDate = [NSDate date];
            }];
        }
    }
    if (![message isKindOfClass:[ImageMessage class]] && ![message isKindOfClass:[VideoMessage class]]) {
        [pendingMessage finishedProcessing];
    }
    
    if (finalizeCompletion != nil) {
        finalizeCompletion();
    }
}

- (void)finalizeGroupMessage:(BaseMessage*)message inConversation:(Conversation*)conversation fromBoxMessage:(AbstractGroupMessage*)boxMessage sender:(Contact *)sender pendingMessage:(PendingMessage *)pendingMessage finalizeCompletion:(void (^) (void))finalizeCompletion {
    message.sender = sender;
    [self appendNewMessage:message toConversation:conversation];
    [pendingMessage addBaseMessageWithMessage:message];

    if (![message isKindOfClass:[ImageMessage class]] && ![message isKindOfClass:[VideoMessage class]]) {
        [pendingMessage finishedProcessing];
    }
    
    if (finalizeCompletion != nil) {
        finalizeCompletion();
    }
}

- (void)startLoadingImageFromMessage:(ImageMessage*)message boxMessage:(AbstractMessage*)boxMessage pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    /* Start loading image */
    
    ImageMessageLoader *loader = [[ImageMessageLoader alloc] init];
    dispatch_async(dispatch_get_main_queue(), ^{
        [loader startWithMessage:message onCompletion:^(BaseMessage *message) {
            [pendingMessage addBaseMessageWithMessage:message];
            DDLogInfo(@"Image message blob load completed");
            if (boxMessage) {
                [pendingMessage finishedProcessing];
            }
            onCompletion();
        } onError:^(NSError *error) {
            DDLogError(@"Image message blob load failed with error: %@", error);
            if (boxMessage) {
                [pendingMessage finishedProcessing];
            }
            onError(error);
        }];
    });
}

- (void)conditionallyStartLoadingFileFromMessage:(FileMessage*)message {
    if ([UTIConverter isGifMimeType:message.mimeType] == YES) {
        // only load if not too big
        if (message.fileSize.floatValue > 1*1024*1024) {
            return;
        }
        
        AnimGifMessageLoader *loader = [[AnimGifMessageLoader alloc] init];
        [loader startWithMessage:message onCompletion:^(BaseMessage *message) {
            DDLogInfo(@"File message blob load completed");
        } onError:^(NSError *error) {
            DDLogError(@"File message blob load failed with error: %@", error);
        }];
    } else {
        if ([message renderFileImageMessage] == true || [message renderFileAudioMessage] == true) {
            BlobMessageLoader *loader = [[BlobMessageLoader alloc] init];
            [loader startWithMessage:message onCompletion:^(BaseMessage *message) {
                DDLogInfo(@"File message blob load completed");
            } onError:^(NSError *error) {
                DDLogError(@"File message blob load failed with error: %@", error);
            }];            
        }
    }
}

- (void)processIncomingVideoMessage:(BoxVideoMessage*)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    __block Conversation *conversation = [self preprocessStorableMessage:msg];
    if (conversation == nil) {
        [pendingMessage finishedProcessing];
        onCompletion();
        return;
    }
    
    NSData *fileData = nil;
    NSString *filePath = [self filePath:msg];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        fileData = [[NSFileManager defaultManager] contentsAtPath:filePath];
    }
    
    /* Conversation deleted in the meantime? */
    if ([conversation wasDeleted]) {
        /* Make a new one */
        conversation = [self preprocessStorableMessage:msg];
        if (conversation == nil) {
            [pendingMessage finishedProcessing];
            onError([ThreemaError threemaError:@"Cannot get replacement for deleted conversation"]);
            return;
        }
    }
    
    if (fileData) {
        /* Decrypt the box */
        NSData *thumbnailData = [[NaClCrypto sharedCrypto] symmetricDecryptData:fileData withKey:msg.encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
        
        if (thumbnailData == nil) {
            [pendingMessage finishedProcessing];
            onError([ThreemaError threemaError:@"Video thumbnail blob decryption failed"]);
            return;
        }
        
        /* Make thumbnail */
        UIImage *thumbnail = [UIImage imageWithData:thumbnailData];
        if (thumbnail == nil) {
            [pendingMessage finishedProcessing];
            onError([ThreemaError threemaError:@"Video thumbnail decoding failed"]);
            return;
        }
        
        __block VideoMessage *message;
        [_entityManager performSyncBlockAndSafe:^{
            ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
            dbThumbnail.data = thumbnailData;
            dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
            
            /* Create Message in DB */
            message = [_entityManager.entityCreator videoMessageFromBox:msg];
            message.thumbnail = dbThumbnail;
            message.duration = [NSNumber numberWithInt:msg.duration];
            message.videoSize = [NSNumber numberWithInt:msg.videoSize];
            message.videoBlobId = msg.videoBlobId;
            message.encryptionKey = msg.encryptionKey;
            message.conversation = conversation;
            
            conversation.lastMessage = message;
            [self increateUnreadMessageCount:conversation];
        }];
        [pendingMessage addBaseMessageWithMessage:message];
        
        /* Delete thumbnail blob on server */
        [MessageSender markBlobAsDone:msg.thumbnailBlobId];
        
        /* Delete file from push */
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        [pendingMessage finishedProcessing];
        onCompletion();
    } else {
        __block UIImage *videoPlaceholderImage = [UIImage imageNamed:@"Video"];
        __block NSData *videoPlaceholderImageData = UIImageJPEGRepresentation(videoPlaceholderImage, 1.0);
        __block VideoMessage *message;
        [_entityManager performSyncBlockAndSafe:^{
            
            ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
            dbThumbnail.data = videoPlaceholderImageData;
            dbThumbnail.width = [NSNumber numberWithInt:videoPlaceholderImage.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:videoPlaceholderImage.size.height];
            /* Create Message in DB */
            message = [_entityManager.entityCreator videoMessageFromBox:msg];
            message.duration = [NSNumber numberWithInt:msg.duration];
            message.videoSize = [NSNumber numberWithInt:msg.videoSize];
            message.videoBlobId = msg.videoBlobId;
            message.encryptionKey = msg.encryptionKey;
            message.conversation = conversation;
            message.thumbnail = dbThumbnail;
            conversation.lastMessage = message;
            [self increateUnreadMessageCount:conversation];
        }];
        [pendingMessage addBaseMessageWithMessage:message];
        /* Send delivery receipt */
        [MessageSender sendDeliveryReceiptForMessage:message fromIdentity:msg.fromIdentity];
               
        /* Fetch video thumbnail */
        NSURLRequest *request = [BlobUtil urlRequestForBlobId:msg.thumbnailBlobId];
        
        PinnedHTTPSURLLoader *thumbnailLoader = [[PinnedHTTPSURLLoader alloc] init];
        [thumbnailLoader startWithURLRequest:request onCompletion:^(NSData *data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                                
                /* Decrypt the box */
                NSData *thumbnailData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:msg.encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
                
                if (thumbnailData == nil) {
                    [pendingMessage finishedProcessing];
                    onError([ThreemaError threemaError:@"Video thumbnail blob decryption failed"]);
                    return;
                }
                
                /* Make thumbnail */
                UIImage *thumbnail = [UIImage imageWithData:thumbnailData];
                if (thumbnail == nil) {
                    [pendingMessage finishedProcessing];
                    onError([ThreemaError threemaError:@"Video thumbnail decoding failed"]);
                    return;
                }
                
                [_entityManager performSyncBlockAndSafe:^{
                    ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
                    dbThumbnail.data = thumbnailData;
                    dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
                    dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
                    
                    /* Create Message in DB */
                    message.thumbnail = dbThumbnail;
                    conversation.lastMessage = message;
                }];
                [pendingMessage addBaseMessageWithMessage:message];
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                      conversation.objectID, kKeyObjectID,
                                      nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDBRefreshedDirtyObject object:self userInfo:info];
                /* Delete thumbnail blob on server */
                [MessageSender markBlobAsDone:msg.thumbnailBlobId];
                [pendingMessage finishedProcessing];
                onCompletion();
            });
        } onError:^(NSError *error) {
            [pendingMessage finishedProcessing];
            DDLogError(@"Blob load failed: %@", error);
            onError(error);
        }];
    }
}

- (void)startReverserGeocodingForMessage:(LocationMessage*)message {
    /* Reverse geocoding (only necessary if there is no POI name) */
    if (message.poiName == nil) {
        double latitude = message.latitude.doubleValue;
        double longitude = message.longitude.doubleValue;
        double accuracy = message.accuracy.doubleValue;
        
        [Utils reverseGeocodeNearLatitude:latitude longitude:longitude accuracy:accuracy completion:^(NSString *label) {
            if ([message wasDeleted]) {
                return;
            }
            
            [_entityManager performAsyncBlockAndSafe:^{
                message.reverseGeocodingResult = label;
            }];
        } onError:^(NSError *error) {
            DDLogWarn(@"Reverse geocoding failed: %@", error);
            if ([message wasDeleted]) {
                return;
            }
            
            [_entityManager performAsyncBlockAndSafe:^{
                message.reverseGeocodingResult = [NSString stringWithFormat:@"%.5f°, %.5f°", latitude, longitude];
            }];
        }];
    }
}


- (void)processIncomingDeliveryReceipt:(DeliveryReceiptMessage*)msg pendingMessage:(PendingMessage *)pendingMessage {
    [_entityManager performAsyncBlockAndSafe:^{
        for (NSData *receiptMessageId in msg.receiptMessageIds) {
            /* Fetch message from DB */
            BaseMessage *dbmsg = [_entityManager.entityFetcher ownMessageWithId: receiptMessageId];
            if (dbmsg == nil) {
                /* This can happen if the user deletes the message before the receipt comes in */
                DDLogInfo(@"Cannot find message ID %@ (delivery receipt from %@)", receiptMessageId, msg.fromIdentity);
                continue;
            }
            
            if (msg.receiptType == DELIVERYRECEIPT_MSGRECEIVED) {
                DDLogVerbose(@"Message ID %@ has been received by recipient", receiptMessageId);
                dbmsg.deliveryDate = msg.date;
                dbmsg.delivered = [NSNumber numberWithBool:YES];
            } else if (msg.receiptType == DELIVERYRECEIPT_MSGREAD) {
                DDLogVerbose(@"Message ID %@ has been read by recipient", receiptMessageId);
                if (!dbmsg.delivered)
                    dbmsg.delivered = [NSNumber numberWithBool:YES];
                dbmsg.readDate = msg.date;
                dbmsg.read = [NSNumber numberWithBool:YES];
            } else if (msg.receiptType == DELIVERYRECEIPT_MSGUSERACK) {
                DDLogVerbose(@"Message ID %@ has been user acknowledged by recipient", receiptMessageId);
                dbmsg.userackDate = msg.date;
                dbmsg.userack = [NSNumber numberWithBool:YES];
            } else if (msg.receiptType == DELIVERYRECEIPT_MSGUSERDECLINE) {
                DDLogVerbose(@"Message ID %@ has been user declined by recipient", receiptMessageId);
                dbmsg.userackDate = msg.date;
                dbmsg.userack = [NSNumber numberWithBool:NO];
            } else {
                DDLogWarn(@"Unknown delivery receipt type %d", msg.receiptType);
            }
        }
        [pendingMessage finishedProcessing];
    }];
}

- (void)processIncomingTypingIndicator:(TypingIndicatorMessage*)msg {
    [[TypingIndicatorManager sharedInstance] setTypingIndicatorForIdentity:msg.fromIdentity typing:msg.typing];
}

- (void)processIncomingGroupSetPhotoMessage:(GroupSetPhotoMessage*)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    Conversation *conversation = [_entityManager.entityFetcher conversationForGroupMessage:msg];
    if (conversation == nil) {
        DDLogInfo(@"Group ID %@ from %@ not found", msg.groupId, msg.groupCreator);
        [pendingMessage finishedProcessing];
        onCompletion();
        return;
    } else {
        /* Start loading image */
        ContactGroupPhotoLoader *loader = [[ContactGroupPhotoLoader alloc] init];
        [loader startWithBlobId:msg.blobId encryptionKey:msg.encryptionKey onCompletion:^(NSData *imageData) {
            DDLogInfo(@"Group photo blob load completed");
            if (conversation.managedObjectContext != nil) {
                /* Check if this message is older than the last set date. This ensures that we're using
                 the latest image in case multiple images arrive for the same conversation in short succession.
                 Must do the check here (main thread) to avoid race condition. */
                if (conversation.groupImageSetDate != nil && [conversation.groupImageSetDate compare:msg.date] == NSOrderedDescending) {
                    DDLogInfo(@"Ignoring older group set photo message");
                    [pendingMessage finishedProcessing];
                    onCompletion();
                    return;
                }
                
                UIImage *image = [UIImage imageWithData:imageData];
                if (image == nil) {
                    onError([ThreemaError threemaError:@"Image decoding failed"]);
                    [pendingMessage finishedProcessing];
                    return;
                }
                
                [_entityManager performSyncBlockAndSafe:^{
                    ImageData *dbImage = [_entityManager.entityCreator imageData];
                    dbImage.data = imageData;
                    dbImage.width = [NSNumber numberWithInt:image.size.width];
                    dbImage.height = [NSNumber numberWithInt:image.size.height];
                    
                    conversation.groupImage = dbImage;
                    conversation.groupImageSetDate = msg.date;
                }];
                [pendingMessage finishedProcessing];
                onCompletion();
            }
        } onError:^(NSError *err) {
            DDLogError(@"Group photo blob load failed with error: %@", err);
            [pendingMessage finishedProcessing];
            onError(err);
        }];
    }
}

- (void)processIncomingGroupDeletePhotoMessage:(GroupDeletePhotoMessage*)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion {
    
    Conversation *conversation = [_entityManager.entityFetcher conversationForGroupMessage:msg];
    if (conversation == nil) {
        DDLogInfo(@"Group ID %@ from %@ not found", msg.groupId, msg.groupCreator);
        [pendingMessage finishedProcessing];
        onCompletion();
        return;
    } else {
        if (conversation.managedObjectContext != nil) {
            [_entityManager performSyncBlockAndSafe:^{
                if (conversation.groupImage != nil) {
                    [[_entityManager entityDestroyer] deleteObjectWithObject:conversation.groupImage];
                    conversation.groupImage = nil;
                    conversation.groupImageSetDate = nil;
                }
            }];
            [pendingMessage finishedProcessing];
            onCompletion();
        }
    }
}

- (void)processIncomingGroupVideoMessage:(GroupVideoMessage*)msg conversation:(Conversation *) conversation pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    NSData *fileData = nil;
    NSString *filePath = [self filePath:msg];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        fileData = [[NSFileManager defaultManager] contentsAtPath:filePath];
    }
    
    Conversation *currentConversation = conversation;
    /* Conversation deleted in the meantime? */
    if ([conversation wasDeleted]) {
        /* Make a new one */
        currentConversation = [_entityManager.entityFetcher conversationForGroupMessage:msg];
        if (currentConversation == nil) {
            [pendingMessage finishedProcessing];
            onError([ThreemaError threemaError:@"Cannot get replacement for deleted conversation"]);
            return;
        }
    }
    
    if (fileData) {
        /* Decrypt the box */
        NSData *thumbnailData = [[NaClCrypto sharedCrypto] symmetricDecryptData:fileData withKey:msg.encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
        
        if (thumbnailData == nil) {
            [pendingMessage finishedProcessing];
            onError([ThreemaError threemaError:@"Video thumbnail blob decryption failed"]);
            return;
        }
        
        /* Make thumbnail */
        UIImage *thumbnail = [UIImage imageWithData:thumbnailData];
        if (thumbnail == nil) {
            [pendingMessage finishedProcessing];
            onError([ThreemaError threemaError:@"Video thumbnail decoding failed"]);
            return;
        }
        
        __block VideoMessage *message;
        /* Create Message in DB */
        [_entityManager performSyncBlockAndSafe:^{
            ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
            dbThumbnail.data = thumbnailData;
            dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
            
            message = [_entityManager.entityCreator videoMessageFromGroupBox:msg];
            message.thumbnail = dbThumbnail;
            message.duration = [NSNumber numberWithInt:msg.duration];
            message.videoSize = [NSNumber numberWithInt:msg.videoSize];
            message.videoBlobId = msg.videoBlobId;
            message.encryptionKey = msg.encryptionKey;
            
            message.conversation = currentConversation;
            message.sender = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
            
            currentConversation.lastMessage = message;
            [self increateUnreadMessageCount:conversation];
        }];
        [pendingMessage addBaseMessageWithMessage:message];
        
        /* Delete file from push */
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        [pendingMessage finishedProcessing];
        onCompletion();
    } else {
        __block UIImage *videoPlaceholderImage = [UIImage imageNamed:@"Video"];
        __block NSData *videoPlaceholderImageData = UIImageJPEGRepresentation(videoPlaceholderImage, 1.0);
        __block VideoMessage *message;
        /* Create Message in DB */
        [_entityManager performSyncBlockAndSafe:^{
            ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
            dbThumbnail.data = videoPlaceholderImageData;
            dbThumbnail.width = [NSNumber numberWithInt:videoPlaceholderImage.size.width];
            dbThumbnail.height = [NSNumber numberWithInt:videoPlaceholderImage.size.height];
            
            message = [_entityManager.entityCreator videoMessageFromGroupBox:msg];
            message.thumbnail = dbThumbnail;
            message.duration = [NSNumber numberWithInt:msg.duration];
            message.videoSize = [NSNumber numberWithInt:msg.videoSize];
            message.videoBlobId = msg.videoBlobId;
            message.encryptionKey = msg.encryptionKey;
            
            message.conversation = currentConversation;
            message.sender = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
            
            currentConversation.lastMessage = message;
            [self increateUnreadMessageCount:conversation];
        }];
        [pendingMessage addBaseMessageWithMessage:message];
        
        /* Fetch video thumbnail */
        NSURLRequest *request = [BlobUtil urlRequestForBlobId:msg.thumbnailBlobId];
        
        PinnedHTTPSURLLoader *thumbnailLoader = [[PinnedHTTPSURLLoader alloc] init];
        [thumbnailLoader startWithURLRequest:request onCompletion:^(NSData *data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                /* Decrypt the box */
                NSData *thumbnailData = [[NaClCrypto sharedCrypto] symmetricDecryptData:data withKey:msg.encryptionKey nonce:[NSData dataWithBytesNoCopy:kNonce_2 length:sizeof(kNonce_2) freeWhenDone:NO]];
                
                if (thumbnailData == nil) {
                    [pendingMessage finishedProcessing];
                    onError([ThreemaError threemaError:@"Video thumbnail blob decryption failed"]);
                    return;
                }
                
                /* Make thumbnail */
                UIImage *thumbnail = [UIImage imageWithData:thumbnailData];
                if (thumbnail == nil) {
                    [pendingMessage finishedProcessing];
                    onError([ThreemaError threemaError:@"Video thumbnail decoding failed"]);
                    return;
                }
                
                /* Create Message in DB */
                [_entityManager performSyncBlockAndSafe:^{
                    ImageData *dbThumbnail = [_entityManager.entityCreator imageData];
                    dbThumbnail.data = thumbnailData;
                    dbThumbnail.width = [NSNumber numberWithInt:thumbnail.size.width];
                    dbThumbnail.height = [NSNumber numberWithInt:thumbnail.size.height];
                    
                    message.thumbnail = dbThumbnail;
                    currentConversation.lastMessage = message;
                }];
                [pendingMessage addBaseMessageWithMessage:message];
                [pendingMessage finishedProcessing];
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                      conversation.objectID, kKeyObjectID,
                                      nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDBRefreshedDirtyObject object:self userInfo:info];
                onCompletion();
            });
        } onError:^(NSError *error) {
            DDLogError(@"Blob load failed: %@", error);
            [pendingMessage finishedProcessing];
            onError(error);
        }];
    }
}

- (void)processIncomingGroupBallotVoteMessage:(GroupBallotVoteMessage*)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    /* Create Message in DB */
    BallotMessageDecoder *decoder = [BallotMessageDecoder messageDecoder];
    if ([decoder decodeVoteFromGroupBox: msg] == NO) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error processing ballot vote"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    
    //persist decoded data
    [_entityManager performAsyncBlockAndSafe:nil];
    [pendingMessage finishedProcessing];
    onCompletion();
}

- (void)processIncomingBallotVoteMessage:(BoxBallotVoteMessage*)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    
    /* Create Message in DB */
    BallotMessageDecoder *decoder = [BallotMessageDecoder messageDecoder];
    if ([decoder decodeVoteFromBox: msg] == NO) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error parsing json for ballot vote"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    
    //persist decoded data
    [_entityManager performAsyncBlockAndSafe:nil];
    [pendingMessage finishedProcessing];
    onCompletion();
}

- (void)processPendingGroupMessages {
    DDLogVerbose(@"Processing pending group messages");
    NSArray *messages = [_pendingGroupMessages array];
    for (AbstractGroupMessage *msg in messages) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self processIncomingAbstractMessage:msg onCompletion:^{
                [_pendingGroupMessages removeObject:msg];
                [[ServerConnector sharedServerConnector] completedProcessingAbstractMessage:msg];
            } onError:^(NSError *err) {
                DDLogWarn(@"Processing pending group message failed: %@", err);
            }];
        });
    }
}

- (void)processIncomingContactSetPhotoMessage:(ContactSetPhotoMessage *)msg conversation:(Conversation *)conversation pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    /* Start loading image */
    ContactGroupPhotoLoader *loader = [[ContactGroupPhotoLoader alloc] init];
    
    [loader startWithBlobId:msg.blobId encryptionKey:msg.encryptionKey onCompletion:^(NSData *imageData) {
        DDLogInfo(@"contact photo blob load completed");
        ContactStore *contactStore = [ContactStore sharedContactStore];
        Contact *contact;
        
        if (conversation.managedObjectContext != nil) {
            contact =  conversation.contact;
        } else {
            contact =  [contactStore contactForIdentity:msg.fromIdentity];
        }
        
        NSError *error;
        [contactStore updateProfilePicture:contact imageData:imageData didFailWithError:&error];
        
        if (error != nil) {
            onError(error);
            return;
        }

        [pendingMessage finishedProcessing];
        onCompletion();
    } onError:^(NSError *err) {
        DDLogError(@"Contact photo blob load failed with error: %@", err);
        [pendingMessage finishedProcessing];
        if (err.code == 404)
            onCompletion();
        onError(err);
    }];
}

- (void)processIncomingContactDeletePhotoMessage:(ContactDeletePhotoMessage *)msg conversation:(Conversation *)conversation pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {

    ContactStore *contactStore = [ContactStore sharedContactStore];
    Contact *contact;

    if (conversation.managedObjectContext != nil) {
        contact = conversation.contact;
    } else {
        contact = [contactStore contactForIdentity:msg.fromIdentity];
    }
    
    [contactStore deleteProfilePicture:contact];

    [pendingMessage finishedProcessing];
    onCompletion();
}

- (void)processIncomingContactRequestPhotoMessage:(ContactRequestPhotoMessage *)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion {
    
    [[ContactStore sharedContactStore] removeProfilePictureFlagForContact:msg.fromIdentity];
    
    [pendingMessage finishedProcessing];
    onCompletion();
}


- (void)processIncomingVoIPCallOfferMessage:(BoxVoIPCallOfferMessage *)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    VoIPCallMessageDecoder *decoder = [VoIPCallMessageDecoder messageDecoder];
    VoIPCallOfferMessage *message = [decoder decodeVoIPCallOfferFromBox:msg];
    Contact *contact = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
    if (message == nil) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error parsing json for voip call offer"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    
    [[VoIPCallStateManager shared] incomingCallOfferWithOffer:message contact:contact completion:^{
        [pendingMessage finishedProcessing];
        onCompletion();
    }];
}

- (void)processIncomingVoIPCallAnswerMessage:(BoxVoIPCallAnswerMessage *)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    VoIPCallMessageDecoder *decoder = [VoIPCallMessageDecoder messageDecoder];
    VoIPCallAnswerMessage *message = [decoder decodeVoIPCallAnswerFromBox:msg];
    Contact *contact = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
    if (message == nil) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error parsing json for ballot vote"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    [[VoIPCallStateManager shared] incomingCallAnswerWithAnswer:message contact:contact completion:^{
        [pendingMessage finishedProcessing];
        onCompletion();
    }];
}

- (void)processIncomingVoIPCallIceCandidatesMessage:(BoxVoIPCallIceCandidatesMessage *)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    VoIPCallMessageDecoder *decoder = [VoIPCallMessageDecoder messageDecoder];
    VoIPCallIceCandidatesMessage *message = [decoder decodeVoIPCallIceCandidatesFromBox:msg];
    Contact *contact = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
    if (message == nil) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error parsing json for ice candidates"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    [[VoIPCallStateManager shared] incomingIceCandidatesWithCandidates:message contact:contact completion:^{
        [pendingMessage finishedProcessing];
        onCompletion();
    }];
    [pendingMessage finishedProcessing];
    onCompletion();
}

- (void)processIncomingVoIPCallHangupMessage:(BoxVoIPCallHangupMessage *)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    VoIPCallMessageDecoder *decoder = [VoIPCallMessageDecoder messageDecoder];
    Contact *contact = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
    VoIPCallHangupMessage *message = [decoder decodeVoIPCallHangupFromBox:msg contact:contact];
    
    if (message == nil) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error parsing json for hangup"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    
    [[VoIPCallStateManager shared] incomingCallHangupWithHangup:message];

    [pendingMessage finishedProcessing];
    onCompletion();
}

- (void)processIncomingVoipCallRingingMessage:(BoxVoIPCallRingingMessage *)msg pendingMessage:(PendingMessage *)pendingMessage onCompletion:(void(^)(void))onCompletion onError:(void(^)(NSError *err))onError {
    VoIPCallMessageDecoder *decoder = [VoIPCallMessageDecoder messageDecoder];
    Contact *contact = [_entityManager.entityFetcher contactForId: msg.fromIdentity];
    VoIPCallRingingMessage *message = [decoder decodeVoIPCallRingingFromBox:msg contact:contact];

    if (message == nil) {
        NSError *error;
        error = [ThreemaError threemaError:@"Error parsing json for ringing"];
        [pendingMessage finishedProcessing];
        onError(error);
        return;
    }
    
    [[VoIPCallStateManager shared] incomingCallRingingWithRinging:message];
    
    [pendingMessage finishedProcessing];
    onCompletion();
}

- (NSString *)filePath:(AbstractMessage *)message {
    NSString *groupDocumentsPath = [DocumentManager groupDocumentsDirectory].path;
    NSString *name = [NSString stringWithFormat:@"PushImage_%@", [NSString stringWithHexData:message.messageId]];
    NSString *fileName = [NSString stringWithFormat:@"/%@.jpg", name];
    return [groupDocumentsPath stringByAppendingString:fileName];
}

- (void)decryptImageFile:(NSData *)data message:(ImageMessage *)message onCompletion:(void(^)(NSData *decrypted))onCompletion {
    NSData *decryptedData = nil;
    
    ImageMessageLoader *loader = [[ImageMessageLoader alloc] init];
    NSData *encryptionKey = [message blobGetEncryptionKey];
    
    if (encryptionKey == nil) {
        // handle image message backward compatibility
        if ([message isKindOfClass:[ImageMessage class]]) {
            if (((ImageMessage *)message).imageNonce == nil) {
                DDLogWarn(@"Missing image encryption key or nonce!");
                onCompletion(nil);
            }
        } else {
            DDLogWarn(@"Missing encryption key!");
            onCompletion(nil);
        }
    }
    loader.message = message;
    decryptedData = [loader decryptData:data];
    if (decryptedData != nil) {
        [loader updateDBObjectWithData:decryptedData onCompletion:^{
            if (message.conversation.groupId == nil) {
                [MessageSender markBlobAsDone:message.imageBlobId];
            }
            
            DDLogInfo(@"Blob successfully downloaded (%lu bytes)", (unsigned long)data.length);
            onCompletion(decryptedData);
        }];
    } else {
        onCompletion(decryptedData);
    }
}

- (void)startProcessPendingGroupMessages {
    [self processPendingGroupMessages];
}

- (void)increateUnreadMessageCount:(Conversation *)conversation {
    NSNumber *unreadCount = conversation.unreadMessageCount;
    if (unreadCount.intValue == -1)
        unreadCount = @0;
    conversation.unreadMessageCount = [NSNumber numberWithInt:unreadCount.intValue + 1];
}

@end
