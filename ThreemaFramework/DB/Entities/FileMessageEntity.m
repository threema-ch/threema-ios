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

#import "FileMessageEntity.h"
#import "ImageData.h"
#import "UTIConverter.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "BundleUtil.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"
#import "ThreemaUtilityObjC.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

static NSString *fieldOrigin = @"origin";

@implementation FileMessageEntity

@dynamic blobId;
@dynamic blobThumbnailId;
@dynamic encryptionKey;
@dynamic fileName;
@dynamic fileSize;
@dynamic json;
@dynamic mimeType;
@dynamic progress;
@dynamic origin;
@dynamic type;

@dynamic data;
@dynamic thumbnail;

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
    NSString *name = [self blobFilename];
    if ([self blobData] == nil) {
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
        if ([self caption] != nil) {
            fileTypeDescriptionText = [fileTypeDescriptionText stringByAppendingString:[NSString stringWithFormat:@"\n%@", _caption]];
        }
        
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
            return [NSString stringWithFormat:@"%@ (%@)", [BundleUtil localizedStringForKey:@"file_message_voice"], [ThreemaUtilityObjC timeStringForSeconds:self.duration.integerValue]];
        } else {
            return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"file_message_voice"]];
        }
    }
    return nil;
}

#pragma mark - Misc

- (nullable NSURL *)tmpURL:(nonnull NSString *)tmpFileName {
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
        NSString *extension = [UTIConverter preferredFileExtensionForMimeType:self.mimeType];
        
        // Workaround for audio messages from Android
        // The extension would be `nil` otherwise and then Files.app cannot play the file.
        // This should be fixed in more detail with IOS-3075
        if ([self.mimeType isEqual:@"audio/aac"]) {
            extension = @"m4a";
        }
        
        // The mime type might not return an extension. If it does not, we check the path extension. If there is none, we use an empty extension.
        if (extension == nil && !(extension = fileName.pathExtension)) {
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
        NSString *extension = [UTIConverter preferredFileExtensionForMimeType:self.mimeType];
        if (extension == nil) {
            extension = @"";
        }
        tmpFileUrl = [[tmpDirUrl URLByAppendingPathComponent:tmpFileName] URLByAppendingPathExtension: extension];
    }
    
    return tmpFileUrl;
}

/// Exports the data for this message to url. Will overwrite any data at that URL
/// @param url 
- (void)exportDataToURL:(nullable NSURL *)url {
    NSData *data = [self blobData];
    if (![data writeToURL:url atomically:NO]) {
        DDLogWarn(@"Writing file data to temporary file failed");
    }
}

- (BOOL)renderFileImageMessage {
    if ((self.type.intValue == 1 || self.type.intValue == 2) &&
        ([UTIConverter isImageMimeType:self.mimeType])) {
        return [UTIConverter isRenderingImageMimeType:self.mimeType];
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

// Will return the caption. If it does not exist it will return the JSON caption.
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
        }
    }
    
    if ([_caption length] == 0) {
        return nil;
    }
    
    return _caption;
}

// Will return the correlationId. If it does not exist it will return the JSON correlationId.
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

// Will return the mimeTypeThumbnail. If it does not exist it will return the JSON mimeTypeThumbnail.
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

// Will return the duration. If it does not exist it will return the JSON duration.
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

// Will return the height. If it does not exist it will return the JSON height.
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

// Will return the width. If it does not exist it will return the JSON width.
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

- (BOOL)thumbnailDownloaded {
    return [self blobThumbnail] != nil;
}

- (BOOL)dataDownloaded {
    return [self blobData] != nil;
}

#ifdef DEBUG
#else
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ <%@>: %@ %@ %@ %@ %@ %@ %@ %@ %@ %@  %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", self.class, self, @"encryptionKey", @"*****", @"blobId", @"*****", @"blobThumbnailId = ", @"****", @"fileName = ", self.fileName.description, @"progress = ", self.progress.description, @"type = ", self.type.description, @"mimeType = ", self.mimeType.description, @"data = ", self.data.description, @"thumbnail", self.thumbnail.description, @"json = ", @"*****"];
}
#endif


@end
