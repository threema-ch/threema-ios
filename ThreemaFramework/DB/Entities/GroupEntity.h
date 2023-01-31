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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "TMAManagedObject.h"

typedef NS_CLOSED_ENUM(NSInteger, GroupState) {
    GroupStateActive = 0,
    GroupStateRequestedSync = 1,
    GroupStateLeft = 2,
    GroupStateForcedLeft = 3
};

NS_ASSUME_NONNULL_BEGIN

@interface GroupEntity : TMAManagedObject

@property (nonatomic, retain) NSNumber *state;
@property (nonatomic, retain, nullable) NSString *groupCreator;
@property (nonatomic, retain) NSData *groupId NS_SWIFT_NAME(groupID);
@property (nonatomic, retain, nullable) NSDate *lastPeriodicSync;

- (BOOL)didLeave;

- (BOOL)didForcedLeave;

@end

NS_ASSUME_NONNULL_END
