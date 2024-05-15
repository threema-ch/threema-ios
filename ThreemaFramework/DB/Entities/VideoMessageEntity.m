//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "VideoMessageEntity.h"
#import "ImageData.h"
#import "VideoData.h"
#import "NSString+Hex.h"
#import "BundleUtil.h"
#import "UTIConverter.h"
#import "ThreemaUtilityObjC.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation VideoMessageEntity

@dynamic duration;
@dynamic encryptionKey;
@dynamic progress;
@dynamic thumbnail;
@dynamic videoSize;

@dynamic video;
@dynamic videoBlobId;

- (nullable NSString*)additionalExportInfo {
    int seconds = self.duration.intValue;
    int minutes = seconds / 60;
    seconds -= minutes * 60;
    return [NSString stringWithFormat:@"%@ (%02d:%02d, %@)", [BundleUtil localizedStringForKey:@"video"], minutes, seconds, [self blobFilename]];
}

#pragma mark - Misc

#ifdef DEBUG
#else
- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", [self class], self, @"progress = ", self.progress.description, @"videoBlobId = ", @"***", @"encryptionKey = ", @"***", @"videoSize = ", self.videoSize.description, @"video = ", self.video.description, @"thumbnail = ", self.thumbnail.description, @"duration = ", self.duration.description];
}
#endif

@end
