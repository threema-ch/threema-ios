#import <CommonCrypto/CommonDigest.h>
#import "MoveFingerView.h"

@implementation MoveFingerView {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
}

@synthesize numberOfPositionsRecorded;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        memset(digest, 0, sizeof(digest));
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
