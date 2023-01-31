//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import "BoxFileMessage.h"

@implementation BoxFileMessage

- (uint8_t)type {
    return MSGTYPE_FILE;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:_jsonData];
    
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return YES;
}

- (BOOL)supportsForwardSecurity {
    return YES;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder]) {
        self.jsonData = [decoder decodeObjectForKey:@"jsonData"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    [encoder encodeObject:self.jsonData forKey:@"jsonData"];
}

@end
