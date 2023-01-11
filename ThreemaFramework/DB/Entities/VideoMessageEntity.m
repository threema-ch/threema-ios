//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

@dynamic progress;
@dynamic videoSize;
@dynamic videoBlobId;
@dynamic encryptionKey;
@dynamic video;
@dynamic thumbnail;
@dynamic duration;

@synthesize thumbnailWithPlayOverlay = _thumbnailWithPlayOverlay;

- (NSString*)logText {
    int seconds = self.duration.intValue;
    int minutes = seconds / 60;
    seconds -= minutes * 60;
    return [NSString stringWithFormat:@"%@ (%02d:%02d, %@)", [BundleUtil localizedStringForKey:@"video"], minutes, seconds, [self blobGetFilename]];
}

- (NSString*)previewText {
   return [BundleUtil localizedStringForKey:@"video"];
}

- (UIImage *)thumbnailWithPlayOverlay {
    if (_thumbnailWithPlayOverlay == nil) {
        _thumbnailWithPlayOverlay = [ThreemaUtilityObjC makeThumbWithOverlayFor:self.thumbnail.uiImage];
    }
    
    return _thumbnailWithPlayOverlay;
}

#pragma mark - BlobData

- (BOOL)blobIsOutgoing {
    if (self.isOwn) {
        return self.isOwn.boolValue;
    }
    
    return false;
}

- (NSData *)blobGetData {
    if (self.video) {
        return self.video.data;
    }
    
    return nil;
}

- (NSData *)blobGetId {
    return self.videoBlobId;
}

- (void)blobSetDataID:(NSData *)dataID {
    self.videoBlobId = dataID;
}

- (NSData *)blobGetThumbnailId {
    return nil;
}

- (NSData *)blobGetEncryptionKey {
    return self.encryptionKey;
}

- (NSNumber *)blobGetSize {
    return self.videoSize;
}

- (void)blobSetData:(NSData *)data {
    VideoData *dbData = [NSEntityDescription
                         insertNewObjectForEntityForName:@"VideoData"
                         inManagedObjectContext:self.managedObjectContext];
    
    dbData.data = data;
    self.video = dbData;
}

- (void)blobSetThumbnail:(NSData *)data {
    ImageData *dbData = [NSEntityDescription
                         insertNewObjectForEntityForName:@"ImageData"
                         inManagedObjectContext:self.managedObjectContext];
    
    dbData.data = data;
    self.thumbnail = dbData;
}

- (NSData *)blobGetThumbnail {
    if (self.thumbnail) {
        return self.thumbnail.data;
    }
    
    return nil;
}

- (void)blobSetOrigin:(BlobOrigin)origin {
    // no-op
}

- (BlobOrigin)blobGetOrigin {
    return BlobOriginPublic;
}

- (NSString *)blobGetUTI {
    return UTTYPE_VIDEO;
}

- (NSString *)blobGetFilename {
    return [NSString stringWithFormat: @"%@.%@", [NSString stringWithHexData:self.id], MEDIA_EXTENSION_VIDEO];
}

- (NSString *)blobGetWebFilename {
    return [NSString stringWithFormat: @"threema-%@-video.%@", [DateFormatter getDateForWeb:self.date], MEDIA_EXTENSION_VIDEO];
}

- (void)blobUpdateProgress:(NSNumber *)progress {
    self.progress = progress;
}

- (NSNumber *)blobGetProgress {
    return self.progress;
}

- (BOOL)blobGetError {
    if (self.sendFailed) {
        return self.sendFailed.boolValue;
    }
    
    return false;
}

- (void)blobSetError:(BOOL)error {
    self.sendFailed = [[NSNumber alloc] initWithBool:error];
}

- (NSString *)getExternalFilename {
    return [[self video] getFilename];
}

- (NSString *)getExternalFilenameThumbnail {
    return [[self thumbnail] getFilename];
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
