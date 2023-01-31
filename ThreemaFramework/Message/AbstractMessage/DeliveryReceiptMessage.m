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

#import "DeliveryReceiptMessage.h"
#import "ProtocolDefines.h"

@implementation DeliveryReceiptMessage

@synthesize receiptType;
@synthesize receiptMessageIds;

- (uint8_t)type {
    return MSGTYPE_DELIVERY_RECEIPT;
}

- (NSData *)body {
    NSMutableData *receiptBody = [NSMutableData dataWithCapacity:kMessageIdLen*receiptMessageIds.count + 1];
    
    [receiptBody appendBytes:&receiptType length:sizeof(uint8_t)];
    
    for (NSData *receiptMessageId in receiptMessageIds) {
        [receiptBody appendData:receiptMessageId];
    }
    
    return receiptBody;
}

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return NO;
}

- (BOOL)canCreateConversation {
    return NO;
}

- (BOOL)noDeliveryReceiptFlagSet {
    return YES;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.receiptType = (uint8_t)[decoder decodeIntegerForKey:@"receiptType"];
        self.receiptMessageIds = [decoder decodeObjectForKey:@"receiptMessageIds"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeInt:self.receiptType forKey:@"receiptType"];
    [encoder encodeObject:self.receiptMessageIds forKey:@"receiptMessageIds"];
}

@end
