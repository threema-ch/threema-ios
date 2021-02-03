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

#import "BoxedMessage.h"

@implementation BoxedMessage

@synthesize fromIdentity;
@synthesize toIdentity;
@synthesize messageId;
@synthesize date;
@synthesize flags;
@synthesize pushFromName;
@synthesize nonce;
@synthesize box;
@synthesize deliveryDate;
@synthesize delivered;
@synthesize userAck;
@synthesize sendUserAck;

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.fromIdentity = [coder decodeObjectForKey:@"fromIdentity"];
        self.toIdentity = [coder decodeObjectForKey:@"toIdentity"];
        self.messageId = [coder decodeObjectForKey:@"messageId"];
        self.date = [coder decodeObjectForKey:@"date"];
        self.flags = (uint8_t)[coder decodeIntegerForKey:@"flags"];
        self.pushFromName = [coder decodeObjectForKey:@"pushFromName"];
        self.nonce = [coder decodeObjectForKey:@"nonce"];
        self.box = [coder decodeObjectForKey:@"box"];
        self.deliveryDate = [coder decodeObjectForKey:@"deliveryDate"];
        self.delivered = [coder decodeObjectForKey:@"delivered"];
        self.userAck = [coder decodeObjectForKey:@"userAck"];
        self.sendUserAck =[coder decodeObjectForKey:@"sendUserAck"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.fromIdentity forKey:@"fromIdentity"];
    [coder encodeObject:self.toIdentity forKey:@"toIdentity"];
    [coder encodeObject:self.messageId forKey:@"messageId"];
    [coder encodeObject:self.date forKey:@"date"];
    [coder encodeInt:self.flags forKey:@"flags"];
    [coder encodeObject:self.pushFromName forKey:@"pushFromName"];
    [coder encodeObject:self.nonce forKey:@"nonce"];
    [coder encodeObject:self.box forKey:@"box"];
    [coder encodeObject:self.deliveryDate forKey:@"deliveryDate"];
    [coder encodeObject:self.delivered forKey:@"delivered"];
    [coder encodeObject:self.userAck forKey:@"userAck"];
    [coder encodeObject:self.sendUserAck forKey:@"sendUserAck"];
}

@end
