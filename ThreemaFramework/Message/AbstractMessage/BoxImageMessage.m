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

- (BOOL)flagShouldPush {
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

- (BOOL)supportsForwardSecurity {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kUnspecified;
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.blobId = [decoder decodeObjectOfClass:[NSData class] forKey:@"blobId"];
        self.size = (uint32_t)[decoder decodeIntegerForKey:@"size"];
        self.imageNonce = [decoder decodeObjectOfClass:[NSData class] forKey:@"imageNonce"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.blobId forKey:@"blobId"];
    [encoder encodeInt:self.size forKey:@"size"];
    [encoder encodeObject:self.imageNonce forKey:@"imageNonce"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
