//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2025 Threema GmbH
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

#import "BoxVoIPCallAnswerMessage.h"
#import "ProtocolDefines.h"

@implementation BoxVoIPCallAnswerMessage

- (uint8_t)type {
    return MSGTYPE_VOIP_CALL_ANSWER;
}

- (NSData *)body {
    NSMutableData *body = [NSMutableData dataWithData:_jsonData];
    return body;
}

- (BOOL)flagShouldPush {
    return YES;
}

- (BOOL)flagImmediateDeliveryRequired {
    return YES;
}

- (BOOL)flagIsVoIP {
    return YES;
}

- (BOOL)isContentValid {
    return YES;
}

- (BOOL)allowSendingProfile {
    return _isUserInteraction;
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
