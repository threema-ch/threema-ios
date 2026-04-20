#import <Foundation/Foundation.h>

@interface NSString (Hex)

+ (NSString*)stringWithHexData:(NSData*)data;
- (NSData*)decodeHex;

@end
