#import <Foundation/Foundation.h>

@interface NSLocale (OverrideLocale)

+ (void)ttt_overrideRuntimeLocale:(NSLocale *)locale;

+ (void)ttt_resetRuntimeLocale;

@end
