#import "NSBundle+OverrideObjectForInfoDictionaryKey.h"
#import "NSObject+Swizzling.h"

@implementation NSBundle (OverrideObjectForInfoDictionaryKey)

static NSMutableDictionary *dictionary = nil;

+ (void)load
{
    [self ttt_swizzleMethods];
    
    dictionary = [NSMutableDictionary dictionary];
}

+ (void)ttt_swizzleMethods
{
    [self ttt_swizzleInstanceMethod:@selector(objectForInfoDictionaryKey:)
                    withReplacement:@selector(ttt_objectForInfoDictionaryKey:)];
}

+ (void)ttt_overrideKey:(NSString *)key withValue:(NSString *) value
{
    [dictionary setObject: value forKey: key];
}

+ (void)ttt_reset
{
    dictionary = nil;
}

- (NSString *)ttt_objectForInfoDictionaryKey:(NSString *)key
{
    if (dictionary)
    {
        NSString *value = [dictionary valueForKey: key];
        if (value) {
            return value;
        }
    }
    
    return [self ttt_objectForInfoDictionaryKey:key];
}
@end
