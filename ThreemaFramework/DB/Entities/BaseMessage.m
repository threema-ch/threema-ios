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

#import "BaseMessage.h"
#import "Conversation.h"

@implementation BaseMessage

@dynamic date;
@dynamic id;
@dynamic delivered;
@dynamic isOwn;
@dynamic read;
@dynamic sent;
@dynamic userack;
@dynamic userackDate;
@dynamic deliveryDate;
@dynamic readDate;
@dynamic remoteSentDate;
@dynamic sendFailed;
@dynamic conversation;
@dynamic sender;
@dynamic webRequestId;
@dynamic flags;
@dynamic forwardSecurityMode;
@dynamic groupDeliveryReceipts;

- (NSString*)logText {
    return nil;
}

- (NSString*)previewText {
    return @"";
}

- (NSString*)quotePreviewText {
    return self.previewText;
}

/// Check is managedObjectContext nil or isDeleted set to true
- (BOOL)wasDeleted {
    return self.managedObjectContext == nil || self.isDeleted == YES;
}

// for backwards compatibility of message created before ThreemaDataV19
- (NSDate *)remoteSentDate {
    NSDate *date = [self primitiveValueForKey:@"remoteSentDate"];
    if (date == nil) {
        date = [self primitiveValueForKey:@"date"];
    }
    
    return date;
}

- (MessageState)old_messageState {
    if (self.isOwn.boolValue) {
        if (self.userackDate) {
            if (self.userack.boolValue) {
                return MESSAGE_STATE_USER_ACK;
            } else {
                return MESSAGE_STATE_USER_DECLINED;
            }
        } else if (self.sendFailed.boolValue) {
            return MESSAGE_STATE_FAILED;
        } else if (self.read.boolValue) {
            return MESSAGE_STATE_READ;
        } else if (self.delivered.boolValue) {
            return MESSAGE_STATE_DELIVERED;
        } else if (self.sent.boolValue) {
            return MESSAGE_STATE_SENT;
        } else {
            return MESSAGE_STATE_SENDING;
        }
    } else {
        if (self.userackDate) {
            if (self.userack.boolValue) {
                return MESSAGE_STATE_USER_ACK;
            } else {
                return MESSAGE_STATE_USER_DECLINED;
            }
        } else {
            return MESSAGE_STATE_SENT;
        }
    }
}

- (BOOL)noDeliveryReceiptFlagSet {
    if (self.flags != nil) {
        if ([self.flags integerValue] & BaseMessageFlagsNoDeliveryReceipt) {
            return true;
        }
    }
    return false;
}

@end
