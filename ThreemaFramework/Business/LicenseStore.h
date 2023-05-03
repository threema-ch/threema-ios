//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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

#import <Foundation/Foundation.h>

@interface LicenseStore : NSObject

@property (readonly, nullable) NSString *errorMessage;
@property (readonly, nullable) NSError *error;

@property (nullable) NSString *licenseUsername;
@property (nullable) NSString *licensePassword;
@property (nullable) NSString *onPremConfigUrl NS_SWIFT_NAME(onPremConfigURL);

+ (nonnull instancetype)sharedLicenseStore;
- (nonnull instancetype) __unavailable init;

+ (BOOL)requiresLicenseKey;

+ (BOOL)isOnPrem;

- (BOOL)getRequiresLicenseKey;

- (BOOL)isValid;

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
