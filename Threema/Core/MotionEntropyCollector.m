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
