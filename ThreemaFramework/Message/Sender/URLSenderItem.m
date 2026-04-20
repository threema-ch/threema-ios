#import "URLSenderItem.h"
#import "UserSettings.h"
#import "ContactUtil.h"
#import "FLAnimatedImage.h"
#import "MediaConverter.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@import FileUtility;

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
        if ([_type isEqualToString:UTTypeVCard.identifier]) {
            return [self getContactFileName];
        }
        
        if (_fileName != nil) {
            return _fileName;
        }
        NSString *postfix = [UTIConverter preferredFileExtensionForMimeType:[self getMimeType]];

        if (postfix) {
            return [NSString stringWithFormat:@"file.%@", postfix];
        } else {
            return @"file";
        }
    }
}

- (nonnull NSString *)getMimeType {
    NSString *mimeType = [UTIConverter mimeTypeFromUTI:_type];

    if (!mimeType) {
        mimeType = @"application/octet-stream";
    }

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

    if (!mimeType) {
        mimeType = @"application/octet-stream";
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
        return [self getVideoThumbnail];
    }
    else if ([UTIConverter isImageMimeType:[self getMimeType]]) {
        return [self getImageThumbnail];
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

- (UIImage *)getVideoThumbnail {
    if (self.url == nil) {
        
        NSString *tmpPath = [NSString stringWithFormat:@"%@video.mp4", NSTemporaryDirectory()];
        FileUtility *fileUtility = [FileUtility new];
        if ([fileUtility fileExistsAtPath:tmpPath]) {
            NSError *error;
            [fileUtility deleteAtPath:tmpPath error:&error];
            if (error != nil) {
                DDLogError(@"Can't delete file at path %@", tmpPath);
            }
        }
        [fileUtility createFileAtPath:tmpPath contents:[self getData] attributes:nil];
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
    if(_duration) {
        return _duration.floatValue;
    }
    if ([UTIConverter isRenderingVideoMimeType:[self getMimeType]]) {
        /* Find duration and make thumbnail */
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.url options:nil];
        return CMTimeGetSeconds(asset.duration);
    }
    if ([UTIConverter isRenderingAudioMimeType:[self getMimeType]]) {
        /* Find duration and make thumbnail */
        NSString *tmpPath = self.url.absoluteString;
        
        FileUtility *fileUtility = [FileUtility new];
        if (!tmpPath) {
            NSString *mimeType = [UTIConverter mimeTypeFromUTI:_type];

            if (!mimeType) {
                mimeType = @"application/octet-stream";
            }
            
            NSString *fileExtension = [UTIConverter preferredFileExtensionForMimeType:mimeType];
            NSURL *directoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];

            if (fileExtension) {
                tmpPath = [
                    NSString stringWithFormat:@"%@%@.%@",
                    NSTemporaryDirectory(),
                    [fileUtility getTemporarySendableFileNameWithBase:@"audio" directoryURL:directoryURL pathExtension:fileExtension],
                    fileExtension
                ];
            } else {
                tmpPath = [
                    NSString stringWithFormat:@"%@%@",
                    NSTemporaryDirectory(),
                    [fileUtility getTemporarySendableFileNameWithBase:@"audio" directoryURL:directoryURL pathExtension:nil]
                ];
            }

            if ([fileUtility fileExistsAtPath:tmpPath]) {
                return 0.0;
            }

            [_data writeToFile:tmpPath atomically:true];
        }
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:_url options:nil];
        Float64 duration = CMTimeGetSeconds(asset.duration);
        if (!self.url) {
            [fileUtility deleteAtPath:tmpPath error:nil];
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
