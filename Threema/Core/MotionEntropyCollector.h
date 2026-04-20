#import <Foundation/Foundation.h>

@interface MotionEntropyCollector : NSObject

- (void)start;
- (NSData*)stop;

@end
