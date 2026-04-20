#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaConverter : NSObject

#pragma mark - Web

+ (CGSize)getWebThumbnailSizeForImageData:(NSData *)data;

+ (nullable NSData *)getWebThumbnailData:(NSData *)orig;
+ (nullable NSData *)getWebPreviewData:(NSData *)orig;

#pragma mark - Thumbnails

+ (NSUInteger)thumbnailSizeForCurrentDevice;
+ (NSUInteger)fullscreenPreviewSizeForCurrentDevice;

+ (nullable UIImage *)getThumbnailForImage:(UIImage *)orig;
+ (nullable UIImage *)getThumbnailForSticker:(UIImage *)orig;
+ (nullable UIImage *)getThumbnailForVideo:(AVAsset *)asset;

#pragma mark - Scale images

+ (nullable UIImage *)scaleImage:(UIImage *)orig toMaxSize:(CGFloat)maxSize;
+ (nullable UIImage *)scaleImageData:(NSData *)imageData toMaxSize:(CGFloat)maxSize;
+ (nullable NSData *)scaleImageDataToData:(NSData *)imageData toMaxSize:(CGFloat)maxSize useJPEG:(BOOL)useJPEG;
+ (nullable NSData *)scaleImageDataToData:(NSData *)imageData toMaxSize:(CGFloat)maxSize useJPEG:(BOOL)useJPEG withQuality:(NSNumber *)compressionQuality;

+ (nullable UIImage *)scaleImageUrl:(NSURL *)imageUrl toMaxSize:(CGFloat)maxSize NS_SWIFT_NAME(scale(image:toMaxSize:));

#pragma mark - Video

+ (BOOL)isVideoDurationValidAtUrl:(nullable NSURL *)url NS_SWIFT_NAME(isVideoDurationValid(at:));

+ (double)videoMaxDurationInMinutes;

+ (void)convertVideoWithExportSession:(nullable AVAssetExportSession *)exportSession onCompletion:(void(^)(NSURL * _Nullable url))onCompletion onError:(void(^)(NSError * _Nullable error))onError;

+ (nullable NSURL *)getAssetOutputURL;

#pragma mark - Get image as PNG or JPEG

+ (nullable NSData *)PNGRepresentationFor:(UIImage *)image;
+ (nullable NSData *)JPEGRepresentationFor:(UIImage *)image;
+ (nullable NSData *)JPEGRepresentationFor: (UIImage *) image withQuality:(NSNumber *)compressionQuality;

@end

NS_ASSUME_NONNULL_END
