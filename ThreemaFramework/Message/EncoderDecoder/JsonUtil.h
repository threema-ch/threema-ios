#import <Foundation/Foundation.h>

@interface JsonUtil : NSObject

+ (NSData *)serializeJsonFrom:(id)object error:(NSError *)error;

@end
