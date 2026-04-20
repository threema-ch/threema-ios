#import <Foundation/Foundation.h>

@interface ActivityIndicatorProxy : NSObject

+ (void)wireActivityIndicator:(id)activityIndicator;

+ (void)startActivity;
+ (void)stopActivity;

@end
