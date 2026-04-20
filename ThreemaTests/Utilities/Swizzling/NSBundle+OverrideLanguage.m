#import "NSBundle+OverrideLanguage.h"
#import "NSObject+Swizzling.h"

@implementation NSBundle (OverrideLanguage)

+ (void)load
{
    [self ttt_swizzleLanguageBundles];
}

+ (void)ttt_swizzleLanguageBundles
{
    [self ttt_swizzleInstanceMethod:@selector(localizedStringForKey:value:table:)
                    withReplacement:@selector(ttt_localizedStringForKey:value:table:)];
}

static NSBundle *ttt_languageBundle = nil;

+ (void)ttt_overrideLanguage:(NSString *)language
{
    NSString *path = [[NSBundle mainBundle] pathForResource:language ofType:@"lproj"];
    ttt_languageBundle = [NSBundle bundleWithPath:path];
}

+ (void)ttt_resetLanguage
{
    ttt_languageBundle = nil;
}

- (NSString *)ttt_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName NS_FORMAT_ARGUMENT(1);
{
    if (ttt_languageBundle)
    {
        return [ttt_languageBundle ttt_localizedStringForKey:key value:value table:tableName];
    }
    
    return [self ttt_localizedStringForKey:key value:value table:tableName];
}
@end
