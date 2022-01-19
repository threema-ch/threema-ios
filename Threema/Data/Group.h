//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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


@interface Group : NSManagedObject

@property (nonatomic, retain) NSNumber * state;
@property (nonatomic, retain) NSString * groupCreator;
@property (nonatomic, retain) NSData * groupId;

#pragma mark - own definitions & methods

typedef enum {
    kGroupStateActive = 0,
    kGroupStateRequestedSync = 1,
    kGroupStateLeft = 2,
    kGroupStateForcedLeft = 3
} GroupState;

#pragma mark - own definitions & methods

- (BOOL)didLeave;

- (BOOL)didForcedLeave;

@end
