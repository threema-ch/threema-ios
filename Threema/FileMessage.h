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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BaseMessage.h"
#import "FileData.h"
#import "BlobData.h"

@class ImageData;

@interface FileMessage : BaseMessage <BlobData>

@property (nonatomic, retain, nullable) NSData * encryptionKey;
@property (nonatomic, retain, nullable) NSData * blobId;
@property (nonatomic, retain, nullable) NSData * blobThumbnailId;
@property (nonatomic, retain, nullable) NSString * fileName;
@property (nonatomic, retain, nullable) NSNumber * fileSize;
@property (nonatomic, retain, nullable) NSNumber * progress;
@property (nonatomic, retain, nullable) NSNumber * type;
@property (nonatomic, retain, nullable) NSString * mimeType;
@property (nonatomic, retain, nullable) FileData *data;
@property (nonatomic, retain, nullable) ImageData *thumbnail;
@property (nonatomic, retain, nullable) NSString * json;

// not stored in core data
@property (nonatomic, retain, nullable) NSString *caption;
@property (nonatomic, retain, nullable) NSString *correlationId;
@property (nonatomic, retain, nullable) NSString *mimeTypeThumbnail;
@property (nonatomic, retain, nullable) NSNumber *duration;
@property (nonatomic, retain, nullable) NSNumber *height;
@property (nonatomic, retain, nullable) NSNumber *width;

- (NSURL *)tmpURL:(NSString *)tmpFileName;

- (void)exportDataToURL:(NSURL *)url;

- (BOOL)renderMediaFileMessage;
- (BOOL)renderStickerFileMessage;

- (BOOL)renderFileImageMessage;
- (BOOL)renderFileVideoMessage;
- (BOOL)renderFileAudioMessage;
- (BOOL)renderFileGifMessage;

- (BOOL)sendAsFileImageMessage;
- (BOOL)sendAsFileVideoMessage;
- (BOOL)sendAsFileAudioMessage;
- (BOOL)sendAsFileGifMessage;

- (BOOL)shouldShowCaption;

- (BOOL)thumbnailDownloaded;
- (BOOL)dataDownloaded;

@end
