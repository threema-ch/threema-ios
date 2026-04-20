#import <Foundation/Foundation.h>

@interface ThreemaError : NSObject

+ (NSError*)threemaError:(NSString*)message;

+ (NSError*)threemaError:(NSString*)message withCode:(NSInteger)code;

@end
