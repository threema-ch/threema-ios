//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "NSDate+DateSwizzling.h"
#import "NSObject+Swizzling.h"

@implementation NSDate (DateSwizzling)

static NSDate *customDate = nil;

+ (void) load
{
    [self ttt_swizzleClassMethod:@selector(date) withReplacement:@selector(customNowDate)];
}

+ (void) setCustomDate: (NSDate *) date
{
    customDate = date;
}

+ (void) reset
{
    customDate = nil;
}

+ (id) customNowDate
{
    if (customDate) {
        return customDate;
    } else {
        return [self customNowDate];
    }
}

@end
