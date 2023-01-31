//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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
#import <CoreData/CoreData.h>

#import "TMAManagedObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebClientSession : TMAManagedObject

+ (NSFetchRequest<WebClientSession *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *active;
@property (nullable, nonatomic, copy) NSString *browserName;
@property (nullable, nonatomic, copy) NSNumber *browserVersion;
@property (nullable, nonatomic, retain) NSData *initiatorPermanentPublicKey;
@property (nullable, nonatomic, copy) NSString *initiatorPermanentPublicKeyHash;
@property (nullable, nonatomic, copy) NSDate *lastConnection;
@property (nullable, nonatomic, copy) NSNumber *permanent;
@property (nullable, nonatomic, retain) NSData *privateKey;
@property (nullable, nonatomic, copy) NSString *saltyRTCHost;
@property (nullable, nonatomic, copy) NSNumber *saltyRTCPort;
@property (nullable, nonatomic, copy) NSNumber *selfHosted;
@property (nullable, nonatomic, retain) NSData *serverPermanentPublicKey;
@property (nullable, nonatomic, copy) NSNumber *version;

// not stored in core data
@property (nonatomic) BOOL isConnecting;

@end

NS_ASSUME_NONNULL_END
