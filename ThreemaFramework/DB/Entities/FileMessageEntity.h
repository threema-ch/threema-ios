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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BaseMessage.h"
#import "FileData.h"
#import "BlobOrigin.h"

@class ImageData;

@interface FileMessageEntity : BaseMessage

// Attributes
@property (nullable, nonatomic, retain) NSData * blobId NS_SWIFT_NAME(blobID);
@property (nullable, nonatomic, retain) NSData * blobThumbnailId NS_SWIFT_NAME(blobThumbnailID);
@property (nullable, nonatomic, retain) NSString * caption;
@property (nullable, nonatomic, retain) NSData * encryptionKey;
@property (nullable, nonatomic, retain) NSString * fileName;
@property (nullable, nonatomic, retain) NSNumber * fileSize;
@property (nullable, nonatomic, retain) NSString * json;
@property (nullable, nonatomic, retain) NSString * mimeType;
@property (nullable, nonatomic, retain) NSNumber * origin;
@property (nullable, nonatomic, retain) NSNumber * progress;
@property (nullable, nonatomic, retain) NSNumber * type;

// Relationships
@property (nullable, nonatomic, retain) FileData *data;
@property (nullable, nonatomic, retain) ImageData *thumbnail;

// Not stored in core data
@property (nullable, nonatomic, retain) NSString *correlationId NS_SWIFT_NAME(correlationID);
@property (nullable, nonatomic, retain) NSString *mimeTypeThumbnail;
@property (nullable, nonatomic, retain) NSNumber *duration;
@property (nullable, nonatomic, retain) NSNumber *height;
@property (nullable, nonatomic, retain) NSNumber *width;

- (nullable NSURL *)tmpURL:(nonnull NSString *)tmpFileName;

- (void)exportDataToURL:(nullable NSURL *)url;

- (BOOL)renderMediaFileMessage __deprecated_msg("For Objective-C only. Use renderType instead.");
- (BOOL)renderStickerFileMessage __deprecated_msg("For Objective-C only. Use renderType instead.");

- (BOOL)renderFileImageMessage __deprecated_msg("For Objective-C only. Use renderType instead.");
- (BOOL)renderFileVideoMessage __deprecated_msg("For Objective-C only. Use renderType instead.");
- (BOOL)renderFileAudioMessage __deprecated_msg("For Objective-C only. Use renderType instead.");
- (BOOL)renderFileGifMessage __deprecated_msg("For Objective-C only. Use renderType instead.");

- (BOOL)sendAsFileImageMessage;
- (BOOL)sendAsFileVideoMessage;
- (BOOL)sendAsFileAudioMessage;
- (BOOL)sendAsFileGifMessage;

- (BOOL)shouldShowCaption;
- (NSString *)getJSONCaption;

/// Returns `true` if this FileMessageEntity has a thumbnail and `false` otherwise
///
/// Note that this does not indicate that a thumbnail must exist.
- (BOOL)thumbnailDownloaded __deprecated_msg("For Objective-C only. Use thumbnailState instead.");

/// Returns `true` if this FileMessageEntity has data available and `false` otherwise
- (BOOL)dataDownloaded __deprecated_msg("For Objective-C only. Use dataState instead.");

@end
