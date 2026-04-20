#import "TestLocale.h"
#import "NSLocale+OverrideLocale.h"
#import "NSBundle+OverrideLanguage.h"

@implementation TestLocale

+ (void) setLocale: (NSString *) localeId
{
    NSString *languageCode = [localeId substringToIndex: 2];
    [NSBundle ttt_overrideLanguage: languageCode];
    [NSLocale ttt_overrideRuntimeLocale: [NSLocale localeWithLocaleIdentifier:localeId]];
 
    NSLocale __attribute__((unused)) *locale = [NSLocale localeWithLocaleIdentifier: localeId];
}

+ (void) reset
{
    [NSLocale ttt_resetRuntimeLocale];
    [NSBundle ttt_resetLanguage];
}

@end
