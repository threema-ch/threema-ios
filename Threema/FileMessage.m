//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

#import "FileMessage.h"
#import "ImageData.h"
#import "UTIConverter.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "Utils.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@implementation FileMessage

@dynamic encryptionKey;
@dynamic blobId;
@dynamic blobThumbnailId;
@dynamic fileName;
@dynamic fileSize;
@dynamic progress;
@dynamic type;
@dynamic mimeType;
@dynamic data;
@dynamic thumbnail;
@dynamic json;
@synthesize caption = _caption;
@synthesize correlationId = _correlationId;
@synthesize mimeTypeThumbnail = _mimeTypeThumbnail;
@synthesize duration = _duration;
@synthesize height = _height;
@synthesize width = _width;

- (NSString *)fileName {
    NSString *name = [self primitiveValueForKey:@"fileName"];
    if (name) {
        return name;
    } else {
        return self.mimeType;
    }
}

- (NSString*)logFileName {
    NSString *name = [self blobGetFilename];
    if ([self blobGetData] == nil) {
        name = [name stringByAppendingFormat:@" %@", [NSString stringWithFormat:@" %@", [BundleUtil localizedStringForKey:@"fileNotDownloaded"]]];
    }
    return name;
}

- (NSString*)logText {
    
    NSString *logCaption = [NSString string];
    
    if (self.caption != nil) {
        logCaption = [logCaption stringByAppendingFormat:@" %@", [NSString stringWithFormat:@"%@ %@", [BundleUtil localizedStringForKey:@"caption"], self.caption]];
    }
    
    return [NSString stringWithFormat:@"%@: %@%@", [BundleUtil localizedStringForKey:@"file"], [self logFileName], logCaption];
}

- (NSString*)previewText {
    
    if (self.type.intValue == 0 && self.fileName) {
        return self.fileName;
    }
    
    NSString *fileTypeDescriptionText = [self fileTypeDescriptionText];
    
    if (fileTypeDescriptionText != nil) {
        return fileTypeDescriptionText;
    }

    return [BundleUtil localizedStringForKey:@"file"];
}

- (NSString *)fileTypeDescriptionText {
    if ([UTIConverter isGifMimeType:self.mimeType]) {
        return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"gif"]];
    } else if ([UTIConverter isImageMimeType:self.mimeType]) {
        if (self.type.intValue == 2) {
            return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"sticker"]];
        }
        return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"image"]];
    } else if ([UTIConverter isVideoMimeType:self.mimeType] || [UTIConverter isMovieMimeType:self.mimeType]) {
        return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"video"]];
    } else if ([UTIConverter isAudioMimeType:self.mimeType]) {
        if (self.duration != nil) {
            return [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"audio"], [Utils timeStringForSeconds:self.duration.integerValue]];
        } else {
            return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"audio"]];
        }

    }
    return nil;
}

#pragma mark - BlobData

- (NSData *)blobGetData {
    if (self.data) {
        return self.data.data;
    }
    
    return nil;
}

- (NSData *)blobGetId {
    return self.blobId;
}

- (NSData *)blobGetEncryptionKey {
    return self.encryptionKey;
}

- (NSNumber *)blobGetSize {
    return self.fileSize;
}

- (void)blobSetData:(NSData *)data {
    FileData *dbData = [NSEntityDescription
                        insertNewObjectForEntityForName:@"FileData"
                        inManagedObjectContext:self.managedObjectContext];
    
    dbData.data = data;
    self.data = dbData;
}

- (NSData *)blobGetThumbnail {
    if (self.thumbnail) {
        return self.thumbnail.data;
    }
    
    return nil;
}

- (NSString *)blobGetUTI {
    return [UTIConverter utiFromMimeType:self.mimeType];
}

- (NSString *)blobGetFilename {
    return [NSString stringWithFormat:@"%@-%@", [NSString stringWithHexData:self.id], self.fileName];
}

- (NSString *)blobGetWebFilename {
    return self.fileName;
}

- (void)blobUpdateProgress:(NSNumber *)progress {
    self.progress = progress;
}

- (NSNumber *)blobGetProgress {
    return self.progress;
}

- (NSString *)getExternalFilename {
    return [[self data] getFilename];
}

- (NSString *)getExternalFilenameThumbnail {
    return [[self thumbnail] getFilename];
}

#pragma mark - Misc

- (NSURL *)tmpURL:(NSString *)tmpFileName {
    NSURL *tmpFileUrl = nil;
    NSURL *tmpDirUrl = [NSURL fileURLWithPath: NSTemporaryDirectory() isDirectory:YES];
    NSString *fileName = nil;
    if (self.fileName) {
        // Sanitize file name by stripping slashes
        fileName = self.fileName;
        NSURL *tmp = [tmpDirUrl URLByAppendingPathComponent:[self.fileName stringByReplacingOccurrencesOfString:@"/" withString:@""]];
        tmpFileUrl = tmp;
    }
    
    if (fileName == nil) {
        fileName = [[self data] getFilename];
    }
    
    if (fileName != nil) {
        NSString *extension = [UTIConverter preferedFileExtensionForMimeType:self.mimeType];
        if (extension == nil) {
            extension = @"";
        }
        
        NSURL *tmp;
        //Check if the filename already contains the suffix to avoid appending it twice
        if ([fileName hasSuffix:[@"." stringByAppendingString:extension]]) {
            fileName = [fileName stringByReplacingOccurrencesOfString:[@"." stringByAppendingString:extension] withString:@""];
        }
        
        // Get unique filename in temporary directory, to allow sharing multiple files with the same name
        NSString *uniqueFileName = [FileUtility getUniqueFilenameFrom:fileName directoryURL:tmpDirUrl pathExtension:extension];
        fileName = uniqueFileName;
        
        tmp = [[tmpDirUrl URLByAppendingPathComponent:fileName] URLByAppendingPathExtension: extension];
        tmpFileUrl = tmp;
    }
    
    if (tmpFileUrl == nil) {
        NSString *extension = [UTIConverter preferedFileExtensionForMimeType:self.mimeType];
        if (extension == nil) {
            extension = @"";
        }
        tmpFileUrl = [[tmpDirUrl URLByAppendingPathComponent:tmpFileName] URLByAppendingPathExtension: extension];
    }
    
    return tmpFileUrl;
}

/// Exports the data for this message to url. Will overwrite any data at that URL
/// @param url 
- (void)exportDataToURL:(NSURL *)url {
    NSData *data = [self blobGetData];
    if (![data writeToURL:url atomically:NO]) {
        DDLogWarn(@"Writing file data to temporary file failed");
    }
}

- (BOOL)renderFileImageMessage {
    if (self.type.intValue == 1 || self.type.intValue == 2) {
        if ([UTIConverter isImageMimeType:self.mimeType]) {
            return [UTIConverter isRenderingImageMimeType:self.mimeType];
        }
    }
    
    return false;
}

- (BOOL)renderFileVideoMessage {
    if (self.type.intValue == 1 || self.type.intValue == 2) {
        return [UTIConverter isRenderingVideoMimeType:self.mimeType];
    }
    
    return false;
}

- (BOOL)renderFileAudioMessage {
    if (self.type.intValue == 1 || self.type.intValue == 2) {
        return [UTIConverter isRenderingAudioMimeType:self.mimeType];
    }
    
    return false;
}

- (BOOL)renderMediaFileMessage {
    return self.type.intValue == 1;
}

- (BOOL)renderStickerFileMessage {
    return self.type.intValue == 2;
}

- (BOOL)renderFileGifMessage {
    if (self.type.intValue == 1 || self.type.intValue == 2) {
        return [UTIConverter isGifMimeType:self.mimeType];
    }
    
    return false;
}

- (BOOL)renderAsFileMessage {
    return self.type.intValue == 0;
}

- (BOOL)sendAsFileImageMessage {
    if ([UTIConverter isImageMimeType:self.mimeType]) {
        return [UTIConverter isRenderingImageMimeType:self.mimeType];
    }
    return false;
}

- (BOOL)sendAsFileVideoMessage {
    if ([UTIConverter isMovieMimeType:self.mimeType]) {
        return [UTIConverter isRenderingVideoMimeType:self.mimeType];
    }
    return false;
}

- (BOOL)sendAsFileAudioMessage {
    if (self.type.intValue == 0) {
        return false;
    }
    return true;
}

- (BOOL)sendAsFileGifMessage {
    if ([UTIConverter isGifMimeType:self.mimeType]) {
        return true;
    }
    return false;
}

- (BOOL)shouldShowCaption {
    if (self.type.intValue == 2) {
        return false;
    }
    return true;
}

/// /// Will return the caption. If it does not exist it will return the JSON caption.
- (NSString *)caption {
    if (_caption == nil && self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSString *caption = [json objectForKey:JSON_FILE_KEY_DESCRIPTION];
            _caption = caption;
            return caption;
        }
    }
    return _caption;
}

/// /// Will return the correlationId. If it does not exist it will return the JSON correlationId.
- (NSString *)correlationId {
    if (_correlationId == nil && self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSString *correlationId = [json objectForKey:JSON_FILE_KEY_CORRELATION];
            _correlationId = correlationId;
            return correlationId;
        }
    }
    return _correlationId;
}

/// /// Will return the mimeTypeThumbnail. If it does not exist it will return the JSON mimeTypeThumbnail.
- (NSString *)mimeTypeThumbnail {
    if (_mimeTypeThumbnail == nil && self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSString *mTT = [json objectForKey:JSON_FILE_KEY_MIMETYPETHUMBNAIL];
            if (mTT != nil) {
                _mimeTypeThumbnail = mTT;
                return mTT;
            }
        }
    }
    return @"image/jpeg";
}

/// /// Will return the duration. If it does not exist it will return the JSON duration.
- (NSNumber *)duration {
    if (_duration == nil && self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSDictionary *meta = [json objectForKey:JSON_FILE_KEY_METADATA];
            if (meta != nil) {
                float durationFloat = [[meta objectForKey:JSON_FILE_KEY_METADATA_DURATION] floatValue];
                NSNumber *duration = [[NSNumber alloc] initWithFloat:durationFloat];
                _duration = duration;
                return duration;
            }
        }
    }
    return _duration;
}

/// /// Will return the height. If it does not exist it will return the JSON height.
- (NSNumber *)height {
    if (_height == nil && self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSDictionary *meta = [json objectForKey:JSON_FILE_KEY_METADATA];
            if (meta != nil) {
                NSNumber *height = [meta objectForKey:JSON_FILE_KEY_METADATA_HEIGHT];
                _height = height;
                return height;
            }
        }
    }
    
    return _height;
}

/// /// Will return the width. If it does not exist it will return the JSON width.
- (NSNumber *)width {
    if (_width == nil && self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSDictionary *meta = [json objectForKey:JSON_FILE_KEY_METADATA];
            if (meta != nil) {
                NSNumber *width = [meta objectForKey:JSON_FILE_KEY_METADATA_WIDTH];
                _width = width;
                return width;
            }
        }
    }
    
    return _width;
}
- (NSString *)quotePreviewText {
    NSString *quoteCaption = _caption;
    if (!quoteCaption) {
        if ([self renderFileAudioMessage] == true) {
            if (self.duration != nil) {
                return [DateFormatter timeFormatted:self.duration.intValue];
            }
            return @"0:00";
        }
        else if ([self renderAsFileMessage] == true) {
            if (self.fileName != nil) {
                return self.fileName;
            }
            return @"";
        }
        
        return @"";
    }
    return quoteCaption;
}

/// Returns true if this FileMessage has a thumbnail and false otherwise
/// Note that this does not indicate that a thumbnail must exist.
- (BOOL)thumbnailDownloaded {
    if (self.thumbnail != nil) {
        return self.thumbnail.data != nil;
    }
    return false;
}

/// Returns true if this FileMessage has data available and false otherwise
- (BOOL)dataDownloaded {
    if (self.data != nil) {
        return self.data.data != nil;
    }
    return false;
}

#ifdef DEBUG
#else
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ <%@>: %@ %@ %@ %@ %@ %@ %@ %@ %@ %@  %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", self.class, self, @"encryptionKey", @"*****", @"blobId", @"*****", @"blobThumbnailId = ", @"****", @"fileName = ", self.fileName.description, @"progress = ", self.progress.description, @"type = ", self.type.description, @"mimeType = ", self.mimeType.description, @"data = ", self.data.description, @"thumbnail", self.thumbnail.description, @"json = ", @"*****"];
}
#endif


@end
