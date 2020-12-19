//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "NSString+Hex.h"
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

@implementation NSString (Hex)

+ (NSString*)stringWithHexData:(NSData*)data {
    unsigned char *c = (unsigned char*)data.bytes;
    if (c == nil)
        return nil;
    
    NSUInteger n = data.length;
    NSMutableString* s = [NSMutableString stringWithCapacity:(2 * n)];
    for (NSUInteger i = 0; i < n; i++) {
        [s appendFormat:@"%02x", c[i]];
    }
    return s;
}

- (NSData*)decodeHex
{
    const char *hexChars = [self cStringUsingEncoding:NSASCIIStringEncoding];
    if (hexChars == NULL)
        return nil;
    
    NSUInteger length = strlen(hexChars);
    unsigned char *bytes = malloc(length / 2);
    unsigned char lastnib = 0xff;
    NSUInteger n = 0;
    NSUInteger i;
    
    for (i = 0; hexChars[i] != 0; i++) {
        unsigned char curhex = hexChars[i];
        unsigned char curnib;
        if (curhex >= '0' && curhex <= '9')
            curnib = curhex - '0';
        else if (curhex >= 'a' && curhex <= 'f')
            curnib = curhex - 'a' + 0x0a;
        else if (curhex >= 'A' && curhex <= 'F')
            curnib = curhex - 'A' + 0x0a;
        else
            continue; /* ignore unknown character */
    
        if (lastnib != 0xff) {
            /* we have another full byte */
            bytes[n] = (lastnib << 4) | curnib;
            n++;
            lastnib = 0xff;
        } else {
            lastnib = curnib;
        }
    }
    
    return [NSData dataWithBytesNoCopy:bytes length:n];
}

@end
