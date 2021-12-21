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

#import "URLSenderItem.h"
#import "UTIConverter.h"
#import "UserSettings.h"
#import "ContactUtil.h"
#import "FLAnimatedImage.h"
#import "MediaConverter.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface URLSenderItem ()

@property NSData *data;
@property NSString *fileName;

@end

@implementation URLSenderItem

+(instancetype)itemWithUrl:(NSURL *)url type:(NSString *)type renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    URLSenderItem *item = [[URLSenderItem alloc] initWithUrl:url type:type renderType:renderType sendAsFile:sendAsFile];
    return item;
}

+(instancetype)itemWithData:(NSData *)data fileName:(NSString *)fileName type:(NSString *)type renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    URLSenderItem *item = [[URLSenderItem alloc] initWithData:data fileName:fileName type:type renderType:renderType sendAsFile:sendAsFile];
    return item;
}

- (instancetype)initWithUrl:(NSURL *)url type:(NSString *)type renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    self = [super init];
    if (self) {
        _url = url;
        _type = type;
        _sendAsFile = sendAsFile;
        _renderType = renderType;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data fileName:(NSString *)fileName type:(NSString *)type renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile {
    self = [super init];
    if (self) {
        _data = data;
        _type = type;
        _sendAsFile = sendAsFile;
        _renderType = renderType;
        _fileName = fileName;
    }
    return self;
}

- (NSData *)getData {
    if (_url) {
        return [[NSData alloc] initWithContentsOfURL:_url];
    } else {
        return _data;
    }
}

- (NSString *)getName {
    if (_url) {
        return [_url lastPathComponent];
    } else {
        if ([_type isEqualToString:UTTYPE_VCARD]) {
            return [self getContactFileName];
        }
        
        if (_fileName != nil) {
            return _fileName;
        }
        NSString *postfix = [UTIConverter preferedFileExtensionForMimeType:[self getMimeType]];
        return [NSString stringWithFormat:@"file.%@", postfix];
    }
}

- (NSString *)getMimeType {
    NSString *mimeType = [UTIConverter mimeTypeFromUTI:_type];
    if ([mimeType isEqualToString:@"application/octet-stream"] && _url != nil) {
        NSString *uti = [UTIConverter utiForFileURL:_url];
        mimeType = [UTIConverter mimeTypeFromUTI:uti];
    }
    
    // Hack for m4a files shared via UIDocumentInteractionController
    if ([mimeType isEqualToString:@"application/octet-stream"] && [_url.pathExtension isEqualToString:@"m4a"]) {
        mimeType = @"audio/mp4";
    }
    
    // Hack for public.image files shared via screen shots on iOS
    if ([mimeType isEqualToString:@"application/octet-stream"] && [_type isEqualToString:@"public.image"]) {
           mimeType = @"image/jpeg";
       }
    
    return mimeType;
}

- (UIImage *)getThumbnail {
    if ([UTIConverter isGifMimeType:[self getMimeType]] || [self.type isEqualToString:@"image/gif"]) {
        return [self getGifThumbnail];
    }
    else if ([UTIConverter isRenderingImageMimeType:[self getMimeType]]) {
        return [self getImageThumbnail];
    }
    else if ([UTIConverter isRenderingVideoMimeType:[self getMimeType]]) {
        return [self getVideoThumnbail];
    }

    return nil;
}

- (UIImage *)getGifThumbnail {
    FLAnimatedImage *animImage = [FLAnimatedImage animatedImageWithGIFData:[self getData]];
    UIImage *thumbnail = [MediaConverter getThumbnailForSticker:animImage.posterImage];
    
    return thumbnail;
}

- (UIImage *)getImageThumbnail {
    NSData *data = [self getData];
    if (data == nil) {
        return nil;
    }
    UIImage *originalImage = [UIImage imageWithData:data];
    
    if (originalImage == nil) {
        return nil;
    }
    
    UIImage *thumbnail;
    if ([self.renderType  isEqual: @2]) {
        thumbnail = [MediaConverter getThumbnailForSticker:originalImage];
    } else {
        thumbnail = [MediaConverter getThumbnailForImage:originalImage];
    }
    return thumbnail;
}

- (UIImage *)getVideoThumnbail {
    if (self.url == nil) {
        
        NSString *tmpPath = [NSString stringWithFormat:@"%@video.mp4", NSTemporaryDirectory()];
        if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:&error];
            if (error != nil) {
                DDLogError(@"Can't delete file at path %@", tmpPath);
            }
        }
        [[NSFileManager defaultManager] createFileAtPath:tmpPath contents:[self getData] attributes:nil];
        _url = [[NSURL alloc] initFileURLWithPath:tmpPath];
    }
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.url options:nil];
            
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *thumbnail = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    
    thumbnail = [MediaConverter getThumbnailForImage:thumbnail];
    return thumbnail;
}

- (NSString *)getContactFileName {
    NSString *name = [ContactUtil getNameFromVCardData:_data];

    if (name.length < 1) {
        return @"contact.vcf";
    }
    
    return [NSString stringWithFormat:@"%@.vcf", name];
}

- (CGFloat)getDuration {
    if ([UTIConverter isRenderingVideoMimeType:[self getMimeType]]) {
        /* Find duration and make thumbnail */
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.url options:nil];
        return CMTimeGetSeconds(asset.duration);
    }
    if ([UTIConverter isRenderingAudioMimeType:[self getMimeType]]) {
        /* Find duration and make thumbnail */
        NSString *tmpPath = self.url.absoluteString;
        
        if (!tmpPath) {
            NSString *type = [UTIConverter preferedFileExtensionForMimeType:[UTIConverter mimeTypeFromUTI:_type]];
            tmpPath = [NSString stringWithFormat:@"%@%@.%@", NSTemporaryDirectory(), [FileUtility getTemporarySendableFileNameWithBase:@"audio" directoryURL:[NSURL fileURLWithPath:NSTemporaryDirectory()] pathExtension:type], type];
            if ([[NSFileManager defaultManager] fileExistsAtPath:tmpPath]) {
                return 0.0;
            }

            [_data writeToFile:tmpPath atomically:true];
        }
        NSURL *tmpURL = [[NSURL alloc] initFileURLWithPath:tmpPath];
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:tmpURL options:nil];
        Float64 duration = CMTimeGetSeconds(asset.duration);
        if (!self.url) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        }
        return duration;
    }
    return 0.0;
}

- (CGFloat)getHeight {
    if ([UTIConverter isImageMimeType:[self getMimeType]]) {
        UIImage *originalImage = [UIImage imageWithData:[self getData]];
        return originalImage.size.height;
    }
    if ([UTIConverter isVideoMimeType:[self getMimeType]]) {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.url options:nil];
        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        return clipVideoTrack.naturalSize.height;
    }
    return 0.0;
}

- (CGFloat)getWidth {
    if ([UTIConverter isImageMimeType:[self getMimeType]]) {
        UIImage *originalImage = [UIImage imageWithData:[self getData]];
        return originalImage.size.width;
    }
    if ([UTIConverter isVideoMimeType:[self getMimeType]]) {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.url options:nil];
        AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        return clipVideoTrack.naturalSize.width;
    }
    return 0.0;
}

- (void) setCaption:(NSString *)caption {
    _caption = caption;
    
    // A file message with render type 2 (sticker) must not contain a caption.
    // Stickers with caption will be rendered as type 1 (regular image).
    if (caption != nil && _renderType.intValue == 2) {
        _renderType = [NSNumber numberWithInt:1];
    }
}

@end
