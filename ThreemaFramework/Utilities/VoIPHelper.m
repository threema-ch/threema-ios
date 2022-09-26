//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

#import "VoIPHelper.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "BundleUtil.h"
#import "UserSettings.h"

#import "ThreemaFramework/ThreemaFramework-swift.h"

@interface VoIPHelper ()

@end

@implementation VoIPHelper

static VoIPHelper *instance;

+ (VoIPHelper*)shared {
    
    @synchronized (self) {
        if (!instance) {
            instance = [[VoIPHelper alloc] init];
        }
    }
    
    return instance;
}


#pragma mark - Public methods

- (NSString *)currentPromptString:(NSNumber *)currentCallDuration {
    if (_isCallActiveInBackground) {
        if (currentCallDuration) {
            return [NSString stringWithFormat:@"%@ - %@", [DateFormatter timeFormatted:currentCallDuration.intValue], _contactName];
        } else {
            return _contactName;
        }
    }
    return nil;
}

- (void)setIsCallActiveInBackground:(BOOL)isCallActiveInBackground {
    _isCallActiveInBackground = isCallActiveInBackground;
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNavigationBarColorShouldChange object:nil];
}


#pragma mark - Private methods



@end
