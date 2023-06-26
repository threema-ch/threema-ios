//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "AudioMessageEntity.h"
#import "AudioData.h"
#import "NSString+Hex.h"
#import "UTIConverter.h"
#import "ThreemaUtilityObjC.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@implementation AudioMessageEntity

@dynamic audioBlobId;
@dynamic audioSize;
@dynamic encryptionKey;
@dynamic duration;
@dynamic progress;

@dynamic audio;

- (NSString*)logText {
    int seconds = self.duration.intValue;
    int minutes = seconds / 60;
    seconds -= minutes * 60;
    return [NSString stringWithFormat:@"%@ (%02d:%02d, %@)", [BundleUtil localizedStringForKey:@"file_message_voice"], minutes, seconds, [self blobFilename]];
}

- (NSString*)previewText {
    return [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"file_message_voice"], [ThreemaUtilityObjC timeStringForSeconds:self.duration.integerValue]];
}

#pragma mark - Misc

#ifdef DEBUG
#else
- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", [self class], self, @"duration = ", self.duration.description, @"encryptionKey = ", @"***", @"progress = ", self.progress.description, @"audioBlobId = ", @"***", @"audioSize = ", self.audioSize.description, @"audio = ", self.audio.description];
}
#endif

@end
