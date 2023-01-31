//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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
#import <CoreLocation/CoreLocation.h>
#import <PromiseKit/PromiseKit.h>

#import "AbstractMessage.h"
#import "BaseMessage.h"
#import "BallotMessage.h"
#import "TextMessage.h"
#import "FileMessageEntity.h"

@class Conversation;
@class Contact;
@class Group;

@protocol MessageSenderProtocol <NSObject>

- (AnyPromise * _Nonnull)sendDeliveryReceiptForAbstractMessage:(AbstractMessage* _Nonnull)message;

@end

@interface MessageSender : NSObject<MessageSenderProtocol>

- (instancetype _Nonnull)init NS_UNAVAILABLE;

/**
 @param taskManager: Must be en TaskManager, is NSObject because TaskManager is implemented in Swift (circularity #import not possible)
 */
- (instancetype _Nonnull)initWith:(nonnull NSObject *)taskManager;

/**
 Create text message for conversation, save in DB and send it.
 
 @param message: Text to send
 @param inConversation: Conversation for message
 @param quickReply: Is false, then send contact profile picture if necessary
 @param requestId: ID for web client
 @param onCompletion: Will be called after message was sent
 */
+ (void)sendMessage:(NSString* _Nullable)message inConversation:(Conversation* _Nonnull)conversation quickReply:(BOOL)quickReply requestId:(NSString* _Nullable)requestId onCompletion:(void(^_Nullable)(BaseMessage* _Nonnull message))onCompletion
    NS_SWIFT_NAME(sendMessage(_:in:quickReply:requestID:completion:));

+ (void)sendLocation:(CLLocationCoordinate2D)coordinates accuracy:(CLLocationAccuracy)accuracy poiName:(NSString* _Nullable)poiName poiAddress:(NSString* _Nullable)poiAddress inConversation:(Conversation* _Nonnull)conversation onCompletion:(void(^ _Nonnull)(NSData *_Nonnull messageId))onCompletion;

/**
 Send a raw message.
 
 @param message: Message to send
 @param isPersistent: whether to persist the message across app restarts
 @param onCompletion: Will be called after message was sent
 */
+ (void)sendMessage:(AbstractMessage * _Nonnull)message isPersistent:(BOOL)isPersistent onCompletion:(void(^_Nullable)(void))onCompletion;

+ (void)sendReadReceiptForMessages:(NSArray*_Nonnull)messages toIdentity:(NSString*_Nonnull)identity onCompletion:(void(^_Nullable)(void))onCompletion;
+ (void)sendUserAckForMessages:(NSArray*_Nonnull)messages toIdentity:(NSString*_Nullable)identity group:(Group *_Nullable)group onCompletion:(void(^_Nonnull)(void))onCompletion;
+ (void)sendUserDeclineForMessages:(NSArray*_Nonnull)messages toIdentity:(NSString*_Nullable)identity group:(Group *_Nullable)group onCompletion:(void(^_Nonnull)(void))onCompletion;

+ (void)sendTypingIndicatorMessage:(BOOL)typing toIdentity:(NSString*_Nonnull)identity;

+ (void)markBlobAsDoneWithBlobID:(NSData* _Nonnull)blobID origin:(BlobOrigin)origin NS_SWIFT_NAME(markBlobAsDone(blobID:origin:));

+ (void)sendCreateMessageForBallot:(Ballot *_Nonnull)ballot;

+ (void)sendBallotVoteMessage:(Ballot *_Nonnull)ballot;

+ (void)sendBaseMessage:(BaseMessage *)baseMessage;

@end
