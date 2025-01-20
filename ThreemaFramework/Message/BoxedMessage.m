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

#import "BoxedMessage.h"
#import "NSString+Hex.h"

@implementation BoxedMessage

@synthesize fromIdentity;
@synthesize toIdentity;
@synthesize messageId;
@synthesize date;
@synthesize flags;
@synthesize pushFromName;
@synthesize metadataBox;
@synthesize nonce;
@synthesize box;
@synthesize deliveryDate;
@synthesize delivered;
@synthesize userAck;
@synthesize sendUserAck;

#pragma mark - LoggingDescriptionProtocol

- (NSString * _Nonnull)loggingDescription {
    return [NSString stringWithFormat:@"(type: %@; id: %@)", self.class, [NSString stringWithHexData:self.messageId]];
}

@end
