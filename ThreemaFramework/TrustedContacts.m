//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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

#import "TrustedContacts.h"
#import "NSString+Hex.h"

@implementation TrustedContacts

+ (BOOL)isTrustedContactWithIdentity:(NSString*)identity publicKey:(NSData*)publicKey {
    NSData *trustedKey = nil;
    if ([identity isEqualToString:@"*THREEMA"]) {
        trustedKey = [@"3a38650c681435bd1fb8498e213a2919b09388f5803aa44640e0f706326a865c" decodeHex];
    } else if ([identity isEqualToString:@"*SUPPORT"]) {
        trustedKey = [@"0f944d18324b2132c61d8e40afce60a0ebd701bb11e89be94972d4229e94722a" decodeHex];
    } else if ([identity isEqualToString:@"*MY3DATA"]) {
        trustedKey = [@"3b01854f24736e2d0d2dc387eaf2c0273c5049052147132369bf3960d0a0bf02" decodeHex];
    }
    
    return (trustedKey != nil && [trustedKey isEqualToData:publicKey]);
}

@end
