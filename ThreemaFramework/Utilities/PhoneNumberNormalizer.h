#import <Foundation/Foundation.h>

@interface PhoneNumberNormalizer : NSObject

+ (PhoneNumberNormalizer*)sharedInstance;

- (NSString*)phoneNumberToE164:(NSString*)phoneNumber withDefaultRegion:(NSString*)defaultRegion prettyFormat:(NSString**)prettyFormat;

- (NSString*)examplePhoneNumberForRegion:(NSString*)region;
- (NSString *)exampleRegionalPhoneNumberForRegion:(NSString *)region;

- (NSString *)regionalPartForPhoneNumber:(NSString *)phoneNumber;

- (NSString *)regionForPhoneNumber:(NSString *)phoneNumber;

+ (NSString*)userRegion;

@end
