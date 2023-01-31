//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2023 Threema GmbH
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
#import <AVFoundation/AVFoundation.h>
#import "SDAVAssetExportSession.h"

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

+ (NSArray<NSString *> *)videoQualities;
+ (NSArray<NSNumber *> *)videoQualityMaxDurations;
+ (NSTimeInterval)videoMaxDurationAtCurrentQuality;

+ (nullable SDAVAssetExportSession *)convertVideoAsset:(nullable AVAsset *)asset onCompletion:(void(^)(NSURL * _Nullable url))onCompletion onError:(void(^)(NSError * _Nullable error))onError;
+ (void)convertVideoWithExportSession:(nullable SDAVAssetExportSession *)exportSession onCompletion:(void(^)(NSURL * _Nullable url))onCompletion onError:(void(^)(NSError * _Nullable error))onError;

+ (nullable SDAVAssetExportSession *)getAVAssetExportSessionFrom:(nullable AVAsset *)asset outputURL:(nullable NSURL *)outputURL;
+ (NSURL *)getAssetOutputURL;

#pragma mark - Get image as PNG or JPEG

+ (nullable NSData *)PNGRepresentationFor:(UIImage *)image;
+ (nullable NSData *)JPEGRepresentationFor:(UIImage *)image;
+ (nullable NSData *)JPEGRepresentationFor: (UIImage *) image withQuality:(NSNumber *)compressionQuality;

@end

NS_ASSUME_NONNULL_END
