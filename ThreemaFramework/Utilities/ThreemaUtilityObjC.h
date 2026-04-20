#import <Foundation/Foundation.h>

__deprecated_msg("Use ThreemaUtility instead")
@interface ThreemaUtilityObjC : NSObject

+ (void)reverseGeocodeNearLatitude:(double)latitude longitude:(double)longitude accuracy:(double)accuracy completion:(void (^)(NSString *label))completion onError:(void(^)(NSError *error))onError __deprecated_msg("Use fetchAddress() instead");

+ (time_t)systemUptime;

+ (NSString *)timeStringForSeconds: (NSInteger) totalSeconds;
+ (NSString *)accessibilityTimeStringForSeconds: (NSInteger) totalSeconds;
+ (NSString *)accessibilityStringAtTime:(NSTimeInterval)timeInterval withPrefix:(NSString *)prefixKey;

+ (NSDate*)parseISO8601DateString:(NSString*)dateString;

+ (NSString *)formatDataLength:(CGFloat)numBytes;

+ (BOOL)isValidEmail:(NSString *)email;

+ (UIViewAnimationOptions)animationOptionsFor:(NSNotification *)notification animationDuration:(NSTimeInterval*)animationDuration;

+ (UIImage *)makeThumbWithOverlayFor:(UIImage *)image;

+ (NSData*)truncatedUTF8String:(NSString*)str maxLength:(NSUInteger)maxLength;

+ (void)sendErrorLocalNotification:(NSString *)title body:(NSString *)body userInfo:(NSDictionary *)userInfo;

+ (void)sendErrorLocalNotification:(NSString *)title body:(NSString *)body userInfo:(NSDictionary *)userInfo onCompletion:(void(^)(void))onCompletion;

@end
