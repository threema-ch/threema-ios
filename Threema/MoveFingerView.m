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

#import <CommonCrypto/CommonDigest.h>
#import "MoveFingerView.h"

@implementation MoveFingerView {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
}

@synthesize numberOfPositionsRecorded;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        bzero(digest, sizeof(digest));
        self.accessibilityTraits |= UIAccessibilityTraitAllowsDirectInteraction;
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches)
        [self processTouch:touch];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches)
        [self processTouch:touch];
}

- (void)processTouch:(UITouch*)touch {
    
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    
    /* add last digest */
    CC_SHA256_Update(&ctx, digest, sizeof(digest));
    
    /* add position and time stamp of this touch */
    CGPoint location = [touch locationInView:nil];
    NSTimeInterval timestamp = touch.timestamp;
    CC_SHA256_Update(&ctx, &location, sizeof(location));
    CC_SHA256_Update(&ctx, &timestamp, sizeof(timestamp));
    
    CC_SHA256_Final(digest, &ctx);
    
    numberOfPositionsRecorded++;
    
    [self.delegate didMoveFingerInView:self];
}

- (NSData *)digest {
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

@end
