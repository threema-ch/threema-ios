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

- (BOOL)flagShouldPush {
    return NO;
}

- (BOOL)flagDontQueue {
    return YES;
}

- (BOOL)flagDontAck {
    return YES;
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

- (BOOL)canUnarchiveConversation {
    return NO;
}

- (BOOL)canShowUserNotification {
    return NO;
}

- (BOOL)noDeliveryReceiptFlagSet {
    return YES;
}

- (ObjcCspE2eFs_Version)minimumRequiredForwardSecurityVersion {
    return kV11;
}

#pragma mark - NSSecureCoding

- (id)initWithCoder:(NSCoder *)decoder {
    return [super initWithCoder:decoder];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
