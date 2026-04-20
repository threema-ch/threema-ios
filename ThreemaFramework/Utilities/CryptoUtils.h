#import <Foundation/Foundation.h>

@interface CryptoUtils : NSObject

+ (NSData*)hmacSha256ForData:(NSData*)data key:(NSData*)key;

@end
