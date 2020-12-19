//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "LocationMessage.h"


@implementation LocationMessage

@dynamic latitude;
@dynamic longitude;
@dynamic accuracy;
@dynamic reverseGeocodingResult;
@dynamic poiName;

- (NSString*)logText {
    return [NSString stringWithFormat:@"%.6f,%.6f (+/- %.0f m), name %@", self.latitude.doubleValue, self.longitude.doubleValue, self.accuracy.doubleValue, self.poiName];
}

- (NSString*)previewText {
    if (self.poiName != nil)
        return [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"location", nil), self.poiName];
    else if (self.reverseGeocodingResult != nil)
        return [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"location", nil), self.reverseGeocodingResult];
    else
        return NSLocalizedString(@"location", nil);
}

@end
