//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import "TouchIDAuthentication.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "KKPasscodeLock.h"
#import "BundleUtil.h"
#import <ThreemaFramework/ThreemaFramework-Swift.h>
#import "ThreemaError.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation TouchIDAuthentication

+ (void)tryTouchIDAuthenticationCallback:(void(^)(BOOL success, NSError *error, NSData * data))callback {
    if (![[KKPasscodeLock sharedLock] isTouchIdOn])
        return;
    
    LAContext *context = [LAContext new];
    NSError *error;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        NSString *reason = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"to_unlock_passcode"], [ThreemaAppObjc appName]];
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:reason reply:^(BOOL success, NSError *error) {            
            // If we encounter an error, we directly return it.
            if (error != nil) {
                callback(success,error, nil);
                return;
            }
            
            // We safe the policy the first time
            if ([AppGroup getActiveType] == AppGroupTypeApp && [[UserSettings sharedUserSettings] evaluatedPolicyDomainStateApp] == nil) {
                [[UserSettings sharedUserSettings] setEvaluatedPolicyDomainStateApp:context.evaluatedPolicyDomainState];
                callback(success, error, nil);
                return;
            }
            else if ([AppGroup getActiveType] == AppGroupTypeShareExtension && [[UserSettings sharedUserSettings] evaluatedPolicyDomainStateShareExtension] == nil) {
                [[UserSettings sharedUserSettings] setEvaluatedPolicyDomainStateShareExtension:context.evaluatedPolicyDomainState];
                callback(success, error, nil);
                return;
            }
            
            if ([AppGroup getActiveType] == AppGroupTypeApp && ![[[UserSettings sharedUserSettings] evaluatedPolicyDomainStateApp] isEqualToData: context.evaluatedPolicyDomainState]) {
                DDLogWarn(@"[Passcode] Biometrics have possibly changed. Passcode needed in App.");
                callback(nil, [ThreemaError threemaError:@"Biometrics have possibly changed."], context.evaluatedPolicyDomainState);
                return;
            }
            else if ([AppGroup getActiveType] == AppGroupTypeShareExtension && ![[[UserSettings sharedUserSettings] evaluatedPolicyDomainStateShareExtension] isEqualToData: context.evaluatedPolicyDomainState]) {
                DDLogWarn(@"[Passcode] Biometrics have possibly changed. Passcode needed in ShareExtension.");
                callback(nil, [ThreemaError threemaError:@"Biometrics have possibly changed."], context.evaluatedPolicyDomainState);
                return;
            }
            
            callback(success, error, nil);
        }
        ];
    }
    
    if (error) {
        DDLogError(@"Touch ID evaluation error: %@", error);
    }
}

@end
