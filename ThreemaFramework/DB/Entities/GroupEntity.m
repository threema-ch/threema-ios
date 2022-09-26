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

#import "GroupEntity.h"


@implementation GroupEntity

@dynamic state;
@dynamic groupCreator;
@dynamic groupId;
@dynamic lastPeriodicSync;

- (BOOL)didLeave {
    return self.state.intValue == GroupStateLeft;
}

- (BOOL)didForcedLeave {
    return self.state.intValue == GroupStateForcedLeft;
}

- (void)setLeft {
    self.state = [NSNumber numberWithInt:GroupStateLeft];
}

- (void)setForcedLeft {
    self.state = [NSNumber numberWithInt:GroupStateForcedLeft];
}

@end
