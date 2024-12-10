//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

#import "AbstractMessage.h"
#import "BaseMessage.h"
#import "TypingIndicatorMessage.h"

@protocol MessageProcessorDelegate <NSObject>

- (void)beforeDecode;

/**
 Will be called if core data object has changed during incoming message process, but is not a message.

 @param objectID: Managed Object ID of changed core data object
 */
- (void)changedManagedObjectID:(NSManagedObjectID * _Nonnull)objectID;

/**
 Processing of incoming (reflected) message started.
 
 @param message Incoming message
 */
- (void)incomingMessageStarted:(AbstractMessage * _Nonnull)message;

/**
 Processing of incoming (reflected) message has changed (is stored in DB).
 
 @param message Incoming message
 @param baseMessage Created or edited DB message
 */
- (void)incomingMessageChanged:(AbstractMessage * _Nonnull)message baseMessage:(BaseMessage * _Nonnull)baseMessage;

/**
 Processing of incoming (reflected) message is finished.
 
 @param message Incoming message
 */
- (void)incomingMessageFinished:(AbstractMessage * _Nonnull)message;

/**
 Message was marked as read.

 @param inConversations Recalculate count of unread messages in this conversations
 */
- (void)readMessage:(nullable NSSet<ConversationEntity *> *)inConversations
NS_SWIFT_NAME(readMessage(inConversations:));

/**
 Will be called from TaskQueue if queue is empty.
 Processing of incoming message is failed.

 @param message Incoming message
 */
- (void)incomingMessageFailed:(BoxedMessage * _Nonnull)message;

/// Called when processing of the abstract message has failed
///
/// This typically occurs when a PFS wrapped message cannot be decrypted due to missing or incorrect session state
/// @param message
- (void)incomingAbstractMessageFailed:(AbstractMessage * _Nonnull)message;

/// A FS message with no unwrapped message was successfully processed (i.e. auxiliary messages or rejected messages)
/// @param message  Abstract message of FS message
- (void)incomingForwardSecurityMessageWithNoResultFinished:(AbstractMessage * _Nonnull)message;

/**
 Will be called from TaskQueue if is queue empty.
 */
- (void)taskQueueEmpty;

- (void)chatQueueDry;
- (void)reflectionQueueDry;

- (void)processTypingIndicator:(TypingIndicatorMessage * _Nonnull)message;

/**
 Process voip call.

 @param message: VoIP message
 @param identity: Identity from contact of the message
 @param onCompletion: Completion handler with MessageProcessorDelegate, use it when call MessageProcessorDelegate in completion block of processVoIPCall, to prevent blocking of dispatch queue 'ServerConnector.registerMessageProcessorDelegateQueue')
 @param onError: Error handler
 */
- (void)processVoIPCall:(NSObject * _Nonnull)message identity:(NSString * _Nullable)identity onCompletion:(void(^ _Nonnull)(id<MessageProcessorDelegate> _Nonnull delegate))onCompletion onError:(void(^ _Nonnull)(NSError * _Nonnull))onError;

@end
