#import "LicenseStore.h"
#import "BundleUtil.h"
#import "ServerAPIConnector.h"
#import "ThreemaUtilityObjC.h"
#import "ThreemaError.h"
#import "AppGroup.h"
#import "MyIdentityStore.h"
#import "NaClCrypto.h"
#import "NSString+Hex.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
@import Keychain;

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

#define WORK_APP_ID @"ch.threema.work." // Prefix for ch.threema.work.iapp and ch.threema.work.red.iapp
#define ONPREM_APP_ID @"ch.threema.onprem."

#define LICENSE_CHECK_INTERVAL_S 6*60*60
#define LICENSE_OFFLINE_INTERVAL_S 24*60*60
#define DEVICE_ID_LENGTH 16

@interface LicenseStore ()

@property BOOL didCheckLicense;
@property dispatch_semaphore_t sema;
@property NSString *internalDeviceID;

@end

@implementation LicenseStore

@synthesize licenseUsername = _licenseUsername;
@synthesize licensePassword = _licensePassword;
@synthesize licenseDeviceID;
@synthesize onPremConfigUrl = _onPremConfigUrl;

@synthesize internalDeviceID;

+ (nonnull instancetype)sharedLicenseStore {
    static LicenseStore *instance;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [LicenseStore new];
    });

    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _didCheckLicense = NO;
        
        _sema = dispatch_semaphore_create(1);
    }
    return self;
}

- (BOOL)isWithinCheckInterval {
    NSDate *lastCheck = [MyIdentityStore sharedMyIdentityStore].licenseLastCheck;
    if (lastCheck == nil) {
        return NO;
    }
    
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:lastCheck];
    if (time > LICENSE_CHECK_INTERVAL_S) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isWithinOfflineInterval {
    NSDate *lastCheck = [MyIdentityStore sharedMyIdentityStore].licenseLastCheck;
    if (lastCheck == nil) {
        return NO;
    }
    
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:lastCheck];
    if (time > LICENSE_OFFLINE_INTERVAL_S) {
        return NO;
    }
    
    return YES;
}


- (BOOL)isValid {
    if (TargetManagerObjC.isBusinessApp) {
        if (_didCheckLicense) {
            if ([self isWithinCheckInterval] == NO) {
                // force fresh license check
                _didCheckLicense = NO;
                DDLogNotice(@"License Check: force fresh license check");
                return NO;
            }
            return YES;
        } else if (([AppGroup getCurrentType] == AppGroupTypeNotificationExtension || [AppGroup getCurrentType] == AppGroupTypeShareExtension) && [self isWithinOfflineInterval]) {
            // keep notification or share extension valid for one day
            return YES;
        }
        else {
            // force license check on every app start
            DDLogNotice(@"License Check: it's not valid");
            return NO;
        }
    }
    
    return YES;
}

- (void)performLicenseCheckWithCompletion:(nonnull void(^)(BOOL success))onCompletion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
        
        if (_didCheckLicense) {
            dispatch_semaphore_signal(_sema);
            onCompletion(YES);
            return;
        }
        
        if (_licenseUsername.length < 1 || _licensePassword.length < 1) {
            dispatch_semaphore_signal(_sema);
            
            _errorMessage = @"License username/password too short";
            onCompletion(NO);
            return;
        }
        
        NSString *appId = [BundleUtil mainBundle].bundleIdentifier;
        NSString *version = ThreemaUtility.clientVersion;
        
        ServerAPIConnector *connector = [[ServerAPIConnector alloc] init];
        [connector validateLicenseUsername:_licenseUsername password:_licensePassword appId:appId version:version deviceId:[self licenseDeviceID] onCompletion:^(BOOL success, NSDictionary *info) {
            _error = nil;
            _errorMessage = nil;
            if (success) {
                [MyIdentityStore sharedMyIdentityStore].licenseLastCheck = [NSDate date];
                _didCheckLicense = YES;
            } else {
                [MyIdentityStore sharedMyIdentityStore].licenseLastCheck = nil;
                _didCheckLicense = NO;
                _errorMessage = info[@"error"];
            }
            MDMSetup *mdmSetup = [MDMSetup new];
            [mdmSetup applyCompanyMDMWithCachedThreemaMDMSendForce:false];
            dispatch_semaphore_signal(_sema);
            onCompletion(success);
        } onError:^(NSError *error) {
            _errorMessage = error.localizedDescription;
            _error = error;
            
            if ([_error.domain hasPrefix:@"NSURL"] == NO && _error.code != 256) {
                // Remove licenceLastCheck. If notification extension will be startet, it will not process the messages
                [MyIdentityStore sharedMyIdentityStore].licenseLastCheck = nil;
                _didCheckLicense = NO;
            }
            
            dispatch_semaphore_signal(_sema);
            onCompletion(NO);
        }];
    });
}

- (void)performUpdateWorkInfoForce:(BOOL)force {
    // Only send the update work info when there is a valid license username and a valid threema id
    if (!TargetManagerObjC.isBusinessApp || _licenseUsername.length < 1 || !AppSetup.isCompleted) {
        return;
    }
        
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ServerAPIConnector *connector = [[ServerAPIConnector alloc] init];
        [connector updateWorkInfoForStore:[MyIdentityStore sharedMyIdentityStore] licenseUsername:_licenseUsername password:_licensePassword force:force onCompletion:^(BOOL sent) {
            if (sent) {
                DDLogNotice(@"Work info update completed (sent, %@)", [AppGroup getCurrentTypeString]);
            } else {
                DDLogNotice(@"Work info update completed without changes (not sent, %@)", [AppGroup getCurrentTypeString]);
            }
        } onError:^(NSError *error) {
            DDLogError(@"Work info update failed (%@): %@", [AppGroup getCurrentTypeString], error);
        }];
    });
}

- (void)performUpdateWorkInfo {
    [self performUpdateWorkInfoForce:NO];
}

- (void)setLicenseUsername:(NSString *)licenseUsername {
    if ([_licenseUsername isEqualToString:licenseUsername] == NO) {
        _licenseUsername = licenseUsername;
        _didCheckLicense = NO;
    }
}

- (NSString *)licenseUsername {
    return _licenseUsername;
}

- (void)setLicensePassword:(NSString *)licensePassword {
    if ([_licensePassword isEqualToString:licensePassword] == NO) {
        _licensePassword = licensePassword;
        _didCheckLicense = NO;
    }
}

- (NSString *)licensePassword {
    return _licensePassword;
}

- (BOOL)validCustomOnPremConfigUrlWithPredefinedUrl:(NSString *)onPremConfigUrl {
    if ([TargetManagerObjC isCustomOnPrem]) {
        NSString *formattedOnPremConfigUrl = [self formatOnPremConfigUrl:onPremConfigUrl];
        
        NSString *presetOppfUrl = [BundleUtil objectForInfoDictionaryKey:@"PresetOppfUrl"];
        if (presetOppfUrl != nil) {
            return [[self formatOnPremConfigUrl:presetOppfUrl] isEqualToString:formattedOnPremConfigUrl];
        }
        else {
            return YES;
        }
    }
    
    return YES;
}

- (void)setOnPremConfigUrl:(NSString *)onPremConfigUrl {
    NSString *formattedOnPremConfigUrl = [self formatOnPremConfigUrl:onPremConfigUrl];
    
    // Change it only if the final url was changed. Otherwise it will be in a endless loop when the url is set in the company mdm
    if ([_onPremConfigUrl isEqualToString:formattedOnPremConfigUrl] == NO) {
        if ([self validCustomOnPremConfigUrlWithPredefinedUrl:formattedOnPremConfigUrl]) {
            _onPremConfigUrl = formattedOnPremConfigUrl;
            _didCheckLicense = NO;
        } else {
            // Show Error
        }
    }
}

- (NSString *)formatOnPremConfigUrl:(NSString *)onPremConfigUrl {
    NSString *formattedOnPremConfigUrl = onPremConfigUrl;
    // Automatically expand hostnames to default provisioning URL
    if (![formattedOnPremConfigUrl hasPrefix:@"https://"]) {
        formattedOnPremConfigUrl = [NSString stringWithFormat:@"https://%@", formattedOnPremConfigUrl];
    }
    else if ([formattedOnPremConfigUrl hasPrefix:@"https://https://"]) {
        formattedOnPremConfigUrl= [formattedOnPremConfigUrl substringFromIndex:8];
    }
    
    NSString *check = [formattedOnPremConfigUrl substringFromIndex:8];
    if (![check hasSuffix:@".oppf"]) {
        if ([check hasSuffix:@"/"]) {
            formattedOnPremConfigUrl = [NSString stringWithFormat:@"%@prov/config.oppf", formattedOnPremConfigUrl];
        }
        else {
            formattedOnPremConfigUrl = [NSString stringWithFormat:@"%@/prov/config.oppf", formattedOnPremConfigUrl];
        }
    }
    return formattedOnPremConfigUrl;
}

- (NSString *)onPremConfigUrl {
    return _onPremConfigUrl;
}

- (void)deleteLicense {
    _didCheckLicense = NO;
    _licenseUsername = nil;
    _licensePassword = nil;
    _onPremConfigUrl = nil;

    NSError *error = nil;

    KeychainManager *keychain = [[BusinessInjector ui] keychainManagerObjC];
    [keychain deleteLicenseAndReturnError:&error];
    if (error) {
        DDLogError(@"Couldn't delete license in Keychain: %@", [error localizedDescription]);
    }
}

#pragma mark - private

- (NSString *)licenseDeviceID {
    if (internalDeviceID == nil) {
        internalDeviceID = [NSString stringWithHexData:[[NaClCrypto sharedCrypto] randomBytes:DEVICE_ID_LENGTH]];

    }
    return internalDeviceID;
}

- (void)setLicenseDeviceID:(NSString *)newLicenseDeviceID {
    if ([newLicenseDeviceID decodeHex].length == DEVICE_ID_LENGTH) {
        internalDeviceID = newLicenseDeviceID;
    }
    else {
        internalDeviceID = nil;
    }
}

@end
