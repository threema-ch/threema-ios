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

#import "ActivityIndicatorProxy.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

static id wiredActivityIndicator;

@implementation ActivityIndicatorProxy

+ (void)wireActivityIndicator:(id)activityIndicator {
    if ([activityIndicator respondsToSelector:@selector(startActivity)] == NO) {
        DDLogError(@"activityIndicator is required to implement 'startActivity'");
        return;
    }

    if ([activityIndicator respondsToSelector:@selector(stopActivity)] == NO) {
        DDLogError(@"activityIndicator is required to implement 'stopActivity'");
        return;
    }

    wiredActivityIndicator = activityIndicator;
}


+ (void)startActivity {
    if (wiredActivityIndicator) {
        [wiredActivityIndicator startActivity];
    }
}

+ (void)stopActivity {
    if (wiredActivityIndicator) {
        [wiredActivityIndicator stopActivity];
    }
}

@end
