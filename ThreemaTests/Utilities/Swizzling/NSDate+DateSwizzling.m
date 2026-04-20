#import "NSDate+DateSwizzling.h"
#import "NSObject+Swizzling.h"

@implementation NSDate (DateSwizzling)

static NSDate *customDate = nil;

+ (void) load
{
    [self ttt_swizzleClassMethod:@selector(date) withReplacement:@selector(customNowDate)];
}

+ (void) setCustomDate: (NSDate *) date
{
    customDate = date;
}

+ (void) reset
{
    customDate = nil;
}

+ (id) customNowDate
{
    if (customDate) {
        return customDate;
    } else {
        return [self customNowDate];
    }
}

@end
