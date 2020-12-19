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

#import "FileMessage.h"
#import "ImageData.h"
#import "UTIConverter.h"
#import "FileMessageKeys.h"
#import "NSString+Hex.h"
#import "BundleUtil.h"

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
@synthesize caption;
@synthesize correlationId;
@synthesize mimeTypeThumbnail;
@synthesize duration;
@synthesize height;
@synthesize width;

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
        return [NSString stringWithFormat:@"%@", [BundleUtil localizedStringForKey:@"audio"]];
    }
    return nil;
}

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

- (NSString *)getCaption {
    if (self.json == nil) {
        return nil;
    }
    
    NSError *error;
    NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (json == nil) {
        DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        return nil;
    }
    
    NSString *description = [json objectForKey:JSON_FILE_KEY_DESCRIPTION];
    return description;
}

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
        fileName = [self getFilename];
    }
    
    if (fileName != nil) {
        NSString *extension = [UTIConverter preferedFileExtensionForMimeType:self.mimeType];
        if (extension == nil) {
            extension = @"";
        }
        NSURL *tmp = [[tmpDirUrl URLByAppendingPathComponent:fileName] URLByAppendingPathExtension: extension];
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

- (NSString *)mimeTypeThumbnail {
    if (self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSString *mTT = [json objectForKey:JSON_FILE_KEY_MIMETYPETHUMBNAIL];
            if (mTT != nil) {
                return mTT;
            }
        }
    }
    return @"image/jpeg";
}


#pragma mark ExternalStorageInfo

- (NSString *)getFilename {
    return self.data != nil ? [self getFilename:self.data.data] : nil;
}

- (NSString *)getThumbnailname {
    return self.thumbnail != nil ? [self getFilename:self.thumbnail.data] : nil;
}

- (NSString *)getFilename:(NSData *)ofData {
    if (ofData != nil && [ofData respondsToSelector:NSSelectorFromString(@"filename")]) {
        return [ofData performSelector:NSSelectorFromString(@"filename")];
    }
    return nil;
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
//    if (self.type.intValue == 0) {
//        return false;
//    }
//    return true;
    return false;
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

- (NSNumber *)getDuration {
    if (self.json != nil) {
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
                return duration;
            }
        }
    }
    return self.duration;
}

- (NSNumber *)getHeight {
    if (self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSDictionary *meta = [json objectForKey:JSON_FILE_KEY_METADATA];
            if (meta != nil) {
                NSNumber *height = [meta objectForKey:JSON_FILE_KEY_METADATA_HEIGHT];
                return height;
            }
        }
    }
    return @0;
}

- (NSNumber *)getWidth {
    if (self.json != nil) {
        NSError *error;
        NSData *jsonData = [self.json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (json == nil) {
            DDLogError(@"Error parsing json data %@, %@", error, [error userInfo]);
        } else {
            NSDictionary *meta = [json objectForKey:JSON_FILE_KEY_METADATA];
            if (meta != nil) {
                NSNumber *width = [meta objectForKey:JSON_FILE_KEY_METADATA_WIDTH];
                return width;
            }
        }
    }
    return @0;
}

- (NSString *)quotePreviewText {
    NSString *quoteCaption = [self getCaption];
    if (!quoteCaption) {
        return @"";
    }
    return quoteCaption;
}

#ifdef DEBUG
#else
- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"%@ <%@>: %@ %@ %@ %@ %@ %@ %@ %@ %@ %@  %@ %@ %@ %@ %@ %@ %@ %@ %@ %@", self.class, self, @"encryptionKey", @"*****", @"blobId", @"*****", @"blobThumbnailId = ", @"****", @"fileName = ", self.fileName.description, @"progress = ", self.progress.description, @"type = ", self.type.description, @"mimeType = ", self.mimeType.description, @"data = ", self.data.description, @"thumbnail", self.thumbnail.description, @"json = ", @"*****"];
}
#endif


@end
