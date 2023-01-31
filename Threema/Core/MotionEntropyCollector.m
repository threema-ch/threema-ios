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

#import "MotionEntropyCollector.h"
#import <CoreMotion/CoreMotion.h>
#import <CommonCrypto/CommonDigest.h>

#define ACCELEROMETER_UPDATE_INTERVAL   0.05

@implementation MotionEntropyCollector {
    CMMotionManager *motionManager;
    NSOperationQueue *queue;
    BOOL running;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        motionManager = [[CMMotionManager alloc] init];
        queue = [[NSOperationQueue alloc] init];
        motionManager.accelerometerUpdateInterval = ACCELEROMETER_UPDATE_INTERVAL;
    }
    return self;
}

- (void)start {
    if (running)
        return;
    
    running = YES;
    [motionManager startAccelerometerUpdatesToQueue:queue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
        CC_SHA256_CTX ctx;
        CC_SHA256_Init(&ctx);
        
        /* add last digest */
        CC_SHA256_Update(&ctx, digest, sizeof(digest));
        
        /* add content of this update */
        double x = accelerometerData.acceleration.x;
        double y = accelerometerData.acceleration.y;
        double z = accelerometerData.acceleration.z;
        NSTimeInterval timestamp = accelerometerData.timestamp;
        CC_SHA256_Update(&ctx, &x, sizeof(double));
        CC_SHA256_Update(&ctx, &y, sizeof(double));
        CC_SHA256_Update(&ctx, &z, sizeof(double));
        CC_SHA256_Update(&ctx, &timestamp, sizeof(timestamp));
        
        CC_SHA256_Final(digest, &ctx);
    }];
}

- (NSData*)stop {
    if (running) {
        [motionManager stopAccelerometerUpdates];
        running = NO;
    }
    
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

- (void)dealloc {
    [self stop];
}

@end
