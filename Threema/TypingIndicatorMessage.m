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

#import "TypingIndicatorMessage.h"
#import "ProtocolDefines.h"

@implementation TypingIndicatorMessage

@synthesize typing;

- (uint8_t)type {
    return MSGTYPE_TYPING_INDICATOR;
}

- (NSData *)body {
    NSMutableData *typingIndicatorBody = [NSMutableData dataWithCapacity:1];
    
    uint8_t typingVal = typing ? 1 : 0;
    [typingIndicatorBody appendBytes:&typingVal length:sizeof(uint8_t)];
    
    return typingIndicatorBody;
}

- (BOOL)shouldPush {
    return NO;
}

- (BOOL)immediate {
    return YES;
}

- (BOOL)noAck {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowToSendProfilePicture {
    return NO;
}

- (BOOL)canCreateConversation {
    return NO;
}

@end
