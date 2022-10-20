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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "TMAManagedObject.h"

typedef enum {
    MESSAGE_STATE_SENDING,
    MESSAGE_STATE_SENT,
    MESSAGE_STATE_DELIVERED,
    MESSAGE_STATE_READ,
    MESSAGE_STATE_USER_ACK,
    MESSAGE_STATE_USER_DECLINED,
    MESSAGE_STATE_FAILED
} MessageState DEPRECATED_MSG_ATTRIBUTE("Only use from Objective-C. Use state otherwise.");

typedef NS_OPTIONS(NSInteger, BaseMessageFlags) {
    BaseMessageFlagsPush = 1 << 0,
    BaseMessageFlagsImmediate = 1 << 1,
    BaseMessageFlagsNoAck = 1 << 2,
    BaseMessageFlagsAlreadyDelivered = 1 << 3,
    BaseMessageFlagsGroup = 1 << 4,
    BaseMessageFlagsVoip = 1 << 5,
    BaseMessageFlagsSilentPush = 1 << 6,
    BaseMessageFlagsNoDeliveryReceipt = 1 << 7
};


@class Conversation;
@class Contact;

@interface BaseMessage : TMAManagedObject

// All these properties are in theory nullable.
// Maybe test if we can check "Use Scalar Type" so Bools are converted correctly: https://www.objc.io/issues/4-core-data/core-data-models-and-model-objects/

@property (nonatomic, retain) NSData *id; // Non-optional by Core Data

/// Is this a message I sent?
///
/// For a non-null access in Swift use `isOwnMessage`. (This is non-optional by Core Data)
@property (nullable, nonatomic, retain) NSNumber *isOwn;


@property (nonatomic, retain) NSDate *date; // Non-optional by Core Data
@property (nonatomic, retain) NSDate *remoteSentDate;
@property (nullable, nonatomic, retain) NSDate *deliveryDate;
@property (nullable, nonatomic, retain) NSDate *readDate;
@property (nullable, nonatomic, retain) NSDate *userackDate;

// The following block is non-optional by Core Data
@property (nonatomic, retain) NSNumber *sent;
@property (nonatomic, retain) NSNumber *delivered;
@property (nonatomic, retain) NSNumber *read;
@property (nonatomic, retain) NSNumber *userack;

@property (nullable, nonatomic, retain) NSNumber *sendFailed;

@property (nonatomic, retain) NSString *webRequestId NS_SWIFT_NAME(webRequestID);
@property (nonatomic, retain) NSNumber *flags;

@property (nonatomic, retain) Conversation *conversation;
@property (nonatomic, retain) Contact *sender;

@property (readonly) MessageState old_messageState DEPRECATED_MSG_ATTRIBUTE("Only use from Objective-C. Use messageState otherwise.");

- (nullable NSString *)logText;
- (NSString *)previewText;
- (NSString *)quotePreviewText DEPRECATED_MSG_ATTRIBUTE("Deprecated in redesign. Use .quoteMessageType instead");

- (BOOL)wasDeleted;

- (BOOL)noDeliveryReceiptFlagSet;

@end