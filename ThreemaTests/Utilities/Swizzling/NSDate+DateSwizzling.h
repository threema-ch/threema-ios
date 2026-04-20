#import <Foundation/Foundation.h>

@interface NSDate (DateSwizzling)

+ (void) setCustomDate: (NSDate *) date;
+ (void) reset;

@end
