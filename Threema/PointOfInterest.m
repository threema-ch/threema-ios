//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "PointOfInterest.h"

@implementation PointOfInterest

@synthesize name;
@synthesize address;
@synthesize latitude;
@synthesize longitude;

- (NSString*)description {
    return [NSString stringWithFormat:@"%@, %@ (%.6f,%.6f)", name, address, latitude, longitude];
}

- (CLLocationCoordinate2D)coordinate {
    return CLLocationCoordinate2DMake(latitude, longitude);
}

- (NSString *)title {
    return name;
}

- (NSString *)subtitle {
    return address;
}

@end
