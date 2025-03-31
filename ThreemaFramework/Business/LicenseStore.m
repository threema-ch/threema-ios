//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "LicenseStore.h"
#import "BundleUtil.h"
#import "ServerAPIConnector.h"
#import "ThreemaUtilityObjC.h"
#import "ThreemaError.h"
#import "AppGroup.h"
#import "MyIdentityStore.h"
#import "NaClCrypto.h"
#import "NSString+Hex.h"
#import "ValidationLogger.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif

#define WORK_APP_ID @"ch.threema.work." // Prefix for ch.threema.work.iapp and ch.threema.work.red.iapp
#define ONPREM_APP_ID @"ch.threema.onprem."
#define PERSISTENCE_KEY_LICENSE_USER @"Threema license username"
#define PERSISTENCE_KEY_LICENSE_PASSWORD @"Threema license password"
#define PERSISTENCE_KEY_DEVICE_ID @"Threema device ID"
#define PERSISTENCE_KEY_ONPREM_CONFIG_URL @"Threema OnPrem config URL"

#define LICENSE_CHECK_INTERVAL_S 6*60*60
#define LICENSE_OFFLINE_INTERVAL_S 24*60*60
#define DEVICE_ID_LENGTH 16

static LicenseStore *singleton;

@interface LicenseStore ()

@property BOOL didCheckLicense;
@property dispatch_semaphore_t sema;

@end

@implementation LicenseStore

@synthesize licenseUsername = _licenseUsername;
@synthesize licensePassword = _licensePassword;
@synthesize onPremConfigUrl = _onPremConfigUrl;

+ (nonnull instancetype)sharedLicenseStore {
    if (singleton == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            singleton = [LicenseStore new];
        });
    }

    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _didCheckLicense = NO;
        
        _sema = dispatch_semaphore_create(1);
        [self loadLicense];
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
    if (TargetManagerObjc.isBusinessApp) {
        if (_didCheckLicense) {
            if ([self isWithinCheckInterval] == NO) {
                // force fresh license check
                _didCheckLicense = NO;
                [[ValidationLogger sharedValidationLogger] logString:@"License Check: force fresh license check"];
                return NO;
            }
            return YES;
        } else if (([AppGroup getCurrentType] == AppGroupTypeNotificationExtension || [AppGroup getCurrentType] == AppGroupTypeShareExtension) && [self isWithinOfflineInterval]) {
            // keep notification or share extension valid for one day
            return YES;
        }
        else {
            // force license check on every app start
            [[ValidationLogger sharedValidationLogger] logString:@"License Check: it's not valid"];
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
        [connector validateLicenseUsername:_licenseUsername password:_licensePassword appId:appId version:version deviceId:[self deviceId] onCompletion:^(BOOL success, NSDictionary *info) {
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
            MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
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
    if (!TargetManagerObjc.isBusinessApp || _licenseUsername.length < 1 || !AppSetup.isCompleted) {
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
        
        [self saveLicense];
    }
}

- (NSString *)licenseUsername {
    return _licenseUsername;
}

- (void)setLicensePassword:(NSString *)licensePassword {
    if ([_licensePassword isEqualToString:licensePassword] == NO) {
        _licensePassword = licensePassword;
        _didCheckLicense = NO;
        
        [self saveLicense];
    }
}

- (NSString *)licensePassword {
    return _licensePassword;
}

- (void)setOnPremConfigUrl:(NSString *)onPremConfigUrl {
    // Automatically expand hostnames to default provisioning URL
    if (![onPremConfigUrl hasPrefix:@"https://"]) {
        onPremConfigUrl = [NSString stringWithFormat:@"https://%@", onPremConfigUrl];
    }
    else if ([onPremConfigUrl hasPrefix:@"https://https://"]) {
        onPremConfigUrl= [onPremConfigUrl substringFromIndex:8];
    }
    
    NSString *check = [onPremConfigUrl substringFromIndex:8];
    if (![check hasSuffix:@".oppf"]) {
        if ([check hasSuffix:@"/"]) {
            onPremConfigUrl = [NSString stringWithFormat:@"%@prov/config.oppf", onPremConfigUrl];
        }
        else {
            onPremConfigUrl = [NSString stringWithFormat:@"%@/prov/config.oppf", onPremConfigUrl];
        }
    }
    
    // Change it only if the final url was changed. Otherwise it will be in a endless loop when the url is set in the company mdm
    if ([_onPremConfigUrl isEqualToString:onPremConfigUrl] == NO) {
        _onPremConfigUrl = onPremConfigUrl;
        _didCheckLicense = NO;
        
        [self saveLicense];
    }
}

- (NSString *)onPremConfigUrl {
    return _onPremConfigUrl;
}

- (void)deleteLicense {
    _didCheckLicense = NO;
    _licenseUsername = nil;
    _licensePassword = nil;
    _onPremConfigUrl = nil;
    [[AppGroup userDefaults] setValue:nil forKey:PERSISTENCE_KEY_LICENSE_USER];
    [[AppGroup userDefaults] setValue:nil forKey:PERSISTENCE_KEY_LICENSE_PASSWORD];
    [[AppGroup userDefaults] setValue:nil forKey:PERSISTENCE_KEY_ONPREM_CONFIG_URL];
    [[AppGroup userDefaults] synchronize];
}

#pragma mark - private

- (void)loadLicense {
    _licenseUsername = [[AppGroup userDefaults] stringForKey:PERSISTENCE_KEY_LICENSE_USER];
    _licensePassword = [[AppGroup userDefaults] stringForKey:PERSISTENCE_KEY_LICENSE_PASSWORD];
    _onPremConfigUrl = [[AppGroup userDefaults] stringForKey:PERSISTENCE_KEY_ONPREM_CONFIG_URL];
}

- (void)saveLicense {
    [[AppGroup userDefaults] setValue:_licenseUsername forKey:PERSISTENCE_KEY_LICENSE_USER];
    [[AppGroup userDefaults] setValue:_licensePassword forKey:PERSISTENCE_KEY_LICENSE_PASSWORD];
    [[AppGroup userDefaults] setValue:_onPremConfigUrl forKey:PERSISTENCE_KEY_ONPREM_CONFIG_URL];
    [[AppGroup userDefaults] synchronize];
}

- (NSString*)deviceId {
    // Obtain device ID from user defaults. If it doesn't exist yet, generate a new random device ID.
    NSString *deviceId = [[AppGroup userDefaults] stringForKey:PERSISTENCE_KEY_DEVICE_ID];
    if (deviceId == nil) {
        deviceId = [NSString stringWithHexData:[[NaClCrypto sharedCrypto] randomBytes:DEVICE_ID_LENGTH]];
        [[AppGroup userDefaults] setValue:deviceId forKey:PERSISTENCE_KEY_DEVICE_ID];
        [[AppGroup userDefaults] synchronize];
    }
    return deviceId;
}

@end
