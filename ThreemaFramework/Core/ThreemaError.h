#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThreemaError : NSObject

+ (NSError*)threemaError:(nullable NSString*)message;

+ (NSError*)threemaError:(nullable NSString*)message withCode:(NSInteger)code;

@end

NS_ASSUME_NONNULL_END
