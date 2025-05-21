//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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
#import <ThreemaFramework/BoxedMessage.h>
#import <ThreemaFramework/MyIdentityStore.h>
#import <ThreemaFramework/LoggingDescriptionProtocol.h>
#import <ThreemaFramework/ProtocolDefines.h>
#import <ThreemaFramework/ObjcCspE2eFs_Version.h>

/// Copied from BaseMessage.m, used in Obj-C code. For swift see `BaseMessageFlags`
typedef NS_OPTIONS(NSInteger, BaseMessageFlags) {
    BaseMessageFlagsSendPush = 1 << 0,
    BaseMessageFlagsDontQueue = 1 << 1,
    BaseMessageFlagsDontAck = 1 << 2,
    BaseMessageFlagsAlreadyDelivered = 1 << 3,
    BaseMessageFlagsGroup = 1 << 4,
    BaseMessageFlagsImmediateDelivery = 1 << 5,
    BaseMessageFlagsSilentPush = 1 << 6,
    BaseMessageFlagsNoDeliveryReceipt = 1 << 7
};

@class ContactEntity;

@protocol MyIdentityStoreProtocol;

@interface AbstractMessage : NSObject <NSSecureCoding, LoggingDescriptionProtocol>

@property (nonatomic, strong) NSString *fromIdentity;
@property (nonatomic, strong) NSString *toIdentity;
@property (nonatomic, strong) NSData *messageId NS_SWIFT_NAME(messageID);
@property (nonatomic, strong) NSString *pushFromName;
@property (nonatomic, strong) NSDate *date; // created at
@property (nonatomic, strong) NSDate *deliveryDate;
@property (nonatomic, strong) NSNumber *delivered;
@property (nonatomic, strong) NSNumber *userAck;
@property (nonatomic, strong) NSNumber *sendUserAck;
@property (nonatomic, strong) NSData *nonce;
@property (nonatomic, strong) NSNumber *flags;

@property (nonatomic) BOOL receivedAfterInitialQueueSend;
@property (readonly, nonnull) NSString *loggingDescription;
@property (nonatomic) ForwardSecurityMode forwardSecurityMode;

/**
 Make boxed message with end to end encrypted message.

 @param toContact: Receiver contact of the message
 @param myIdentityStore: Sender of the message, with secret key
 @param nonce: Nonce to encrypt message
 */
- (BoxedMessage* _Nullable)makeBox:(ContactEntity* _Nonnull)toContact myIdentityStore:(id<MyIdentityStoreProtocol>  _Nonnull)myIdentityStore nonce:(NSData* _Nonnull)nonce;

+ (NSData*)randomMessageId NS_SWIFT_NAME(randomMessageID());

/* Methods to be overridden by subclasses: */
- (uint8_t)type;
- (BOOL)flagShouldPush;

/// No server queuing. Use this for messages that can be
/// discarded by the chat server in case the receiver is not connected
/// to the chat server, e.g. the _typing_ indicator.
- (BOOL)flagDontQueue;

- (BOOL)flagDontAck;
- (BOOL)flagGroupMessage;
- (BOOL)flagImmediateDeliveryRequired;
- (BOOL)flagIsVoIP;
- (nullable NSData *)body;
- (BOOL)canCreateConversation;
- (BOOL)canUnarchiveConversation;
- (BOOL)needsConversation;
- (BOOL)canShowUserNotification;
- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion;

- (BOOL)isContentValid;
- (NSString *)pushNotificationBody;

- (BOOL)allowSendingProfile;

- (NSString *)getMessageIdString NS_SWIFT_NAME(getMessageIDString());

- (BOOL)noDeliveryReceiptFlagSet;

@end
