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

#import "BoxLocationMessage.h"
#import "ProtocolDefines.h"

@implementation BoxLocationMessage

@synthesize latitude;
@synthesize longitude;
@synthesize accuracy;
@synthesize poiName;
@synthesize poiAddress;

- (uint8_t)type {
    return MSGTYPE_LOCATION;
}

- (NSData *)body {
    NSMutableString *bodyString = [NSMutableString stringWithFormat:@"%f,%f,%f", latitude, longitude, accuracy];
    if (poiName != nil) {
        [bodyString appendString:[NSString stringWithFormat:@"\n%@", poiName]];
        if (poiAddress != nil)
            [bodyString appendString:[NSString stringWithFormat:@"\n%@", [poiAddress stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]]];
    }
    
    return [bodyString dataUsingEncoding:NSUTF8StringEncoding];
}

- (BOOL)shouldPush {
    return YES;
}

-(BOOL)isContentValid {
    return YES;
}

- (BOOL)allowToSendProfilePicture {
    return YES;
}

@end
