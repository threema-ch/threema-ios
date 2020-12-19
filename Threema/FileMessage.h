//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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
#import "ExternalStorageInfo.h"

@class ImageData;

@interface FileMessage : BaseMessage <BlobData, ExternalStorageInfo>

@property (nonatomic, retain) NSData * encryptionKey;
@property (nonatomic, retain) NSData * blobId;
@property (nonatomic, retain) NSData * blobThumbnailId;
@property (nonatomic, retain) NSString * fileName;
@property (nonatomic, retain) NSNumber * fileSize;
@property (nonatomic, retain) NSNumber * progress;
@property (nonatomic, retain) NSNumber * type;
@property (nonatomic, retain) NSString * mimeType;
@property (nonatomic, retain) FileData *data;
@property (nonatomic, retain) ImageData *thumbnail;
@property (nonatomic, retain) NSString * json;

// not stored in core data
@property (nonatomic, retain) NSString *caption;
@property (nonatomic, retain) NSString *correlationId;
@property (nonatomic, retain) NSString *mimeTypeThumbnail;
@property (nonatomic, retain) NSNumber *duration;
@property (nonatomic, retain) NSNumber *height;
@property (nonatomic, retain) NSNumber *width;

- (NSString *)getCaption;

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

- (NSNumber *)getDuration;
- (NSNumber *)getHeight;
- (NSNumber *)getWidth;

@end
