//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "TouchIdAuthentication.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "KKPasscodeLock.h"
#import "BundleUtil.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation TouchIdAuthentication

+ (void)tryTouchIdAuthenticationCallback:(void(^)(BOOL success, NSError *error))callback {
    if (![[KKPasscodeLock sharedLock] isTouchIdOn])
        return;
    
    LAContext *context = [LAContext new];
    NSError *error;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        NSString *reason = [BundleUtil localizedStringForKey:@"to_unlock_passcode"];
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:reason
                          reply:^(BOOL success, NSError *error) {
                              callback(success, error);
                          }
         ];
    }
    
    if (error) {
        DDLogError(@"Touch ID evaluation error: %@", error);
    }
}

@end
