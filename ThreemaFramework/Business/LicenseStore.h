#import <Foundation/Foundation.h>

@interface LicenseStore : NSObject

@property (readonly, nullable) NSString *errorMessage;
@property (readonly, nullable) NSError *error;

@property (nullable, readwrite) NSString *licenseUsername;
@property (nullable, readwrite) NSString *licensePassword;
@property (nonnull, readwrite) NSString *licenseDeviceID;
@property (nullable, readwrite) NSString *onPremConfigUrl NS_SWIFT_NAME(onPremConfigURL);

+ (nonnull instancetype)sharedLicenseStore;
- (nonnull instancetype) __unavailable init;

- (BOOL)validCustomOnPremConfigUrlWithPredefinedUrl:(NSString *)onPremConfigUrl;

- (BOOL)isValid;

- (BOOL)isWithinCheckInterval;

- (BOOL)isWithinOfflineInterval;

- (void)performLicenseCheckWithCompletion:(nonnull void(^)(BOOL success))onCompletion;

/**
 Send the update work info if there is a valid license username and a valid threema id.
 If there was nothing changed and the last request was earlier then 24 hours, the request will not be send to the server.

 @param force: Send request anyway
 */
- (void)performUpdateWorkInfoForce:(BOOL)force NS_SWIFT_NAME(performUpdateWorkInfo(force:));

- (void)performUpdateWorkInfo;

- (void)deleteLicense;

@end
