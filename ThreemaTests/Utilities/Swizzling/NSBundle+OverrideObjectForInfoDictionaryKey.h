#import <Foundation/Foundation.h>

@interface NSBundle (OverrideObjectForInfoDictionaryKey)

+ (void)ttt_overrideKey:(NSString *)key withValue:(NSString *) value;

+ (void)ttt_reset;

@end
