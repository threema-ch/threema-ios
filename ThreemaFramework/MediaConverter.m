//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2021 Threema GmbH
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

#import "MediaConverter.h"
#import "UIImage+Resize.h"
#import "UserSettings.h"
#import "SDAVAssetExportSession.h"
#import "UIDefines.h"
#import "ValidationLogger.h"
#import <CoreServices/UTCoreTypes.h>

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@implementation MediaConverter

+ (CGSize)getWebThumbnailSizeForImageData:(NSData *)data {
    UIImage *image = [self scaleImageData:data toMaxSize:kWebClientMediaThumbnailSize];
    
    return CGSizeMake(image.size.width, image.size.height);
}

+ (UIImage*)getThumbnailForVideo:(AVAsset *)asset {
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *thumbnail = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    
    CGFloat size = (CGFloat) [self thumbnailSizeForCurrentDevice];
    return [self scaleImage:thumbnail toMaxSize:size];
}

+ (UIImage*)getThumbnailForImage:(UIImage *)orig {
    NSUInteger size = [self thumbnailSizeForCurrentDevice];
    return [self scaleImage:orig toMaxSize:size];
}

+ (NSData *)getWebPreviewData:(NSData *)orig {
    UIImage *image = [self scaleImageData:orig toMaxSize:kWebClientMediaPreviewSize];
    return UIImageJPEGRepresentation(image, kWebClientMediaQuality);
}

+ (NSData *)getWebThumbnailData:(NSData *)orig {
    UIImage *image = [self scaleImageData:orig toMaxSize:kWebClientMediaThumbnailSize];
    return UIImageJPEGRepresentation(image, kWebClientMediaQuality);
}

+ (UIImage*)scaleImage:(UIImage*)orig toMaxSize:(CGFloat)maxSize {
    @autoreleasepool {
        // Check if we need to scale this image at all
        if (orig.size.width * orig.scale <= maxSize && orig.size.height * orig.scale <= maxSize) {
            // to rotate the image to the correct orientation
            return [orig resizedImage:CGSizeMake(orig.size.width * orig.scale, orig.size.height * orig.scale) interpolationQuality:kCGInterpolationLow];
        }
        UIImage *scaled = [orig resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(maxSize, maxSize) interpolationQuality:kCGInterpolationLow];
        return scaled;
    }
}

+ (UIImage* _Nullable)scaleImageData:(NSData * _Nonnull)imageData toMaxSize:(CGFloat)maxSize {
    @autoreleasepool {
        CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, (__bridge CFDictionaryRef) @{
            (id) kCGImageSourceShouldCache : @NO});
        NSMutableDictionary *imageRefOptions = [MediaConverter imageRefOptionsForSize:maxSize];
        
        CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef) imageRefOptions);
        UIImage *scaled = [UIImage imageWithCGImage:scaledImageRef];
        CGImageRelease(scaledImageRef);
        if (src) CFRelease(src);
        if (scaled == nil) {
            scaled = [UIImage imageWithData:imageData];
        }
        return scaled;
    }
}

+ (NSData*)scaleImageDataToData:(nonnull NSData *)imageData toMaxSize:(CGFloat)maxSize useJPEG:(BOOL)useJPEG {
    @autoreleasepool {
        CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, (__bridge CFDictionaryRef) @{
            (id) kCGImageSourceShouldCache : @NO});
        NSMutableDictionary *imageRefOptions = [MediaConverter imageRefOptionsForSize:maxSize];
        
        CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef) imageRefOptions);
        
        UIImage *scaled = [UIImage imageWithCGImage:scaledImageRef];
        CGImageRelease(scaledImageRef);
        CFRelease(src);
        
        if (scaled == nil) {
            scaled = [UIImage imageWithData:imageData];
        }
        NSData *scaledData = useJPEG ? UIImageJPEGRepresentation(scaled, kJPEGCompressionQuality) : UIImagePNGRepresentation(scaled);
        return scaledData;
    }
}

+ (UIImage*)scaleImageUrl:(NSURL *)imageUrl toMaxSize:(CGFloat)maxSize {
    @autoreleasepool {
        CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)imageUrl, (__bridge CFDictionaryRef) @{
            (id) kCGImageSourceShouldCache : @NO});
        NSMutableDictionary *imageRefOptions = [MediaConverter imageRefOptionsForSize:maxSize];

        CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef) imageRefOptions);
        UIImage *scaled = [UIImage imageWithCGImage:scaledImageRef];
        CGImageRelease(scaledImageRef);
        CFRelease(src);
        return scaled;
    }
}

+ (NSMutableDictionary *)imageRefOptionsForSize:(CGFloat)maxSize {
    NSMutableDictionary *imageRefOptions = [[NSMutableDictionary alloc] initWithDictionary:@{
        (id) kCGImageSourceCreateThumbnailWithTransform : @YES,
        (id) kCGImageSourceCreateThumbnailFromImageAlways : @YES,
    }];
    // If maxSize is 0, we don't need to scale this image
    if (maxSize > 0) {
        [imageRefOptions setValue:@(maxSize) forKey:(id)kCGImageSourceThumbnailMaxPixelSize];
    }
    return imageRefOptions;
}

+ (NSUInteger)thumbnailSizeForCurrentDevice {
    /* maximum thumbnail size: 50% of the screen height of the current device multiplied by the scale,
     and rounded to the nearest multiple of 32 */
    int screenHeightPixels = (int)(MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) * [UIScreen mainScreen].scale);
    
    int thumbnailSize = screenHeightPixels / 2;
    thumbnailSize -= (thumbnailSize % 32);
    
    return thumbnailSize;
}

+ (NSArray*)videoQualities {
    return @[@"low", @"high"];
}

+ (NSArray*)videoQualityMaxDurations {
    int highMaxDuration = (int) [VideoConversionHelper getMaxdurationForVideoBitrate:kVideoBitrateHigh audioBitrate:kAudioBitrateHigh];
    int lowMaxDuration = (int) [VideoConversionHelper getMaxdurationForVideoBitrate:kVideoBitrateLow audioBitrate:kAudioBitrateLow];
    
    return @[[NSNumber numberWithInt:lowMaxDuration], [NSNumber numberWithInt:highMaxDuration]];
}

/// Returns the maximum duration for a video at the lowest possible quality in minutes.
+ (double)videoMaxDurationAtCurrentQuality {
    long long lowMaxDuration = [VideoConversionHelper getMaxdurationForVideoBitrate:kVideoBitrateLow audioBitrate:kAudioBitrateLow];
    
    return lowMaxDuration;
}

+ (BOOL)isVideoDurationValidAtUrl:(NSURL *)url {
    
    if (url == nil) {
        return false;
    }
    return [VideoConversionHelper videoHasAllowedSizeAt:url];
}

+ (SDAVAssetExportSession*)convertVideoAsset:(AVAsset*)asset onCompletion:(void(^)(NSURL *url))onCompletion onError:(void(^)(NSError *error))onError {
    /* convert video to MPEG4 for compatibility with Android */
    
    NSURL *outputURL = [MediaConverter getAssetOutputURL];
    
    SDAVAssetExportSession *exportSession = [MediaConverter getAVAssetExportSessionFrom:asset outputURL:outputURL];
    
    [MediaConverter convertVideoAsset:asset withExportSession:exportSession onCompletion:onCompletion onError:onError];
    
    return exportSession;
}

+ (void)convertVideoAsset:(AVAsset*)asset withExportSession:(SDAVAssetExportSession *)exportSession onCompletion:(void(^)(NSURL *url))onCompletion onError:(void(^)(NSError *error))onError {
    /* convert video to MPEG4 for compatibility with Android */
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
        DDLogVerbose(@"Export Complete %ld %@ %@", (long)exportSession.status, exportSession.error, exportSession.outputURL);
        if (exportSession.status == AVAssetExportSessionStatusCompleted) {
            onCompletion(exportSession.outputURL);
        } else {
            [[NSFileManager defaultManager] removeItemAtURL:exportSession.outputURL error:nil];
            onError(exportSession.error);
        }
    }];
}

+ (NSURL *)getAssetOutputURL {
    NSString *filename = [NSString stringWithFormat:@"%f-%u.%@", [[NSDate date] timeIntervalSinceReferenceDate], arc4random(), MEDIA_EXTENSION_VIDEO];
    NSString *tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    NSURL *outputURL = [NSURL fileURLWithPath:tmpfile];
    return outputURL;
}

+ (SDAVAssetExportSession *)getAVAssetExportSessionFrom:(AVAsset *) asset outputURL:(NSURL *)outputURL {
    
    if (asset == nil) {
        return nil;
    }
    
    if (outputURL == nil) {
        return nil;
    }
    
    return [VideoConversionHelper getAVAssetExportSessionFrom:asset outputURL:outputURL];
}

+ (NSData *)PNGRepresentationFor: (UIImage *) image {
    return [self representationForType:kUTTypePNG andImage:image];
}

+ (NSData *)JPEGRepresentationFor: (UIImage *) image {
    return [self representationForType:kUTTypeJPEG andImage:image];
}

+ (NSData *)representationForType: (CFStringRef) type andImage:(UIImage *) image {
    @autoreleasepool {
        CFMutableDataRef data = CFDataCreateMutable(nil, 0);
        CGImageDestinationRef destination = CGImageDestinationCreateWithData(data, type, 1, nil);
        if (destination == nil) {
            return nil;
        }
        
        // Fix problem with wrong orientation
        NSNumber *orientation = @0;
        switch (image.imageOrientation) {
            case UIImageOrientationRight:
                orientation = @6;
                break;
            case UIImageOrientationDown:
                orientation = @3;
                break;
            case UIImageOrientationLeft:
                orientation = @8;
                break;
            case UIImageOrientationUp:
                orientation = @1;
                break;
            default:
                break;
        }
        
        NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithFloat:kJPEGCompressionQuality], kCGImageDestinationLossyCompressionQuality,
                                    @1, kCGImagePropertyDPIHeight,
                                    @1, kCGImagePropertyDPIWidth,
                                    orientation, kCGImagePropertyOrientation,
                                    nil];
        
        CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef) properties);
        if (!CGImageDestinationFinalize(destination)) {
            DDLogError(@"Could not write image!");
            return nil;
        }
        NSData *imageData = [NSData dataWithData:(__bridge_transfer NSData*) data];
        CFRelease(destination);
        return imageData;
    }
}

@end
