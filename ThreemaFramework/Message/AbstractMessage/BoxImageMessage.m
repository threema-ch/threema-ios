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

#import "BoxImageMessage.h"
#import "ProtocolDefines.h"

@implementation BoxImageMessage

@synthesize blobId;
@synthesize size;
@synthesize imageNonce;

- (uint8_t)type {
    return MSGTYPE_IMAGE;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData data];
    
    [body appendData:blobId];
    [body appendBytes:&size length:sizeof(uint32_t)];
    [body appendData:imageNonce];
    
    return body;
}

- (BOOL)shouldPush {
    return YES;
}

-(BOOL)isContentValid {
    if (size == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.blobId = [decoder decodeObjectForKey:@"blobId"];
        self.size = (uint32_t)[decoder decodeIntegerForKey:@"size"];
        self.imageNonce = [decoder decodeObjectForKey:@"imageNonce"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.blobId forKey:@"blobId"];
    [encoder encodeInt:self.size forKey:@"size"];
    [encoder encodeObject:self.imageNonce forKey:@"imageNonce"];
}

@end
