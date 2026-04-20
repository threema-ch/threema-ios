#import "NSLocale+OverrideLocale.h"
#import "NSObject+Swizzling.h"
#import <objc/runtime.h>


@implementation NSLocale (OverrideLocale)

+ (void)load
{
    [self ttt_swizzleLocales];
}

static NSLocale *ttt_locale = nil;

+ (void)ttt_overrideRuntimeLocale:(NSLocale *)locale
{
    ttt_locale = locale;
}

+ (void)ttt_resetRuntimeLocale
{
    ttt_locale = nil;
}

+ (void)ttt_swizzleLocales
{
    [self ttt_swizzleClassMethod:@selector(autoupdatingCurrentLocale) withReplacement:@selector(ttt_autoupdatingCurrentLocale)];
    [self ttt_swizzleClassMethod:@selector(currentLocale) withReplacement:@selector(ttt_currentLocale)];
    [self ttt_swizzleClassMethod:@selector(systemLocale) withReplacement:@selector(ttt_systemLocale)];
}

+ (id /* NSLocale * */)ttt_autoupdatingCurrentLocale
{
    return ttt_locale ?: [self ttt_autoupdatingCurrentLocale];
}

+ (id /* NSLocale * */)ttt_currentLocale
{
    return ttt_locale ?: [self ttt_currentLocale];
}

+ (id /* NSLocale * */)ttt_systemLocale
{
    return ttt_locale ?: [self ttt_systemLocale];
}

@end
