//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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
#import "BoxedMessage.h"

@interface AbstractMessage : NSObject <NSCoding>

@property (nonatomic, strong) NSString *fromIdentity;
@property (nonatomic, strong) NSString *toIdentity;
@property (nonatomic, strong) NSData *messageId;
@property (nonatomic, strong) NSString *pushFromName;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSDate *deliveryDate;
@property (nonatomic, strong) NSNumber *delivered;
@property (nonatomic, strong) NSNumber *userAck;
@property (nonatomic, strong) NSNumber *sendUserAck;
@property (nonatomic, strong) NSData *nonce;
@property (nonatomic, strong) NSNumber *flags;

@property (nonatomic) BOOL receivedAfterInitialQueueSend;

- (BoxedMessage*)makeBox;

+ (NSData*)randomMessageId;

/* Methods to be overridden by subclasses: */
- (uint8_t)type;
- (BOOL)shouldPush;
- (BOOL)immediate;
- (BOOL)noAck;
- (BOOL)isGroup;
- (BOOL)isVoIP;
- (NSData*)body;
- (BOOL)canCreateConversation;
- (BOOL)needsConversation;

- (BOOL)isContentValid;
- (NSString *)pushNotificationBody;

- (BOOL)allowToSendProfilePicture;

- (NSString *)getMessageIdString;

- (BOOL)noDeliveryReceiptFlagSet;

@end
