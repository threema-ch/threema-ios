#import <Foundation/Foundation.h>

@interface ErrorHandler : NSObject

+ (void)abortWithError:(nonnull NSError *)error NS_SWIFT_NAME(abort(with:));
+ (void)abortWithError:(nonnull NSError *)error additionalText:(nullable NSString *)additionalText;
+ (void)abortWithTitle:(nonnull NSString *)title message:(nonnull NSString *)message;

@end
