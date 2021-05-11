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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SDAVAssetExportSession.h"

@interface MediaConverter : NSObject

+ (CGSize)getWebThumbnailSizeForImageData:(NSData *)data;

+ (UIImage*)getThumbnailForVideo:(AVAsset *)asset;

+ (NSData * _Nullable)getWebThumbnailData:(NSData * _Nonnull)orig;

+ (NSData *)getWebPreviewData:(NSData *)orig;

+ (NSUInteger)thumbnailSizeForCurrentDevice;

+ (UIImage*)getThumbnailForImage:(UIImage *)orig;

+ (UIImage*)scaleImage:(UIImage*)orig toMaxSize:(CGFloat)maxSize;

+ (UIImage* _Nullable)scaleImageData:(NSData * _Nonnull)imageData toMaxSize:(CGFloat)maxSize;

+ (NSData* _Nullable)scaleImageDataToData:(NSData * _Nonnull)imageData toMaxSize:(CGFloat)maxSize useJPEG:(BOOL)useJPEG;

+ (UIImage*)scaleImageUrl:(NSURL *)imageUrl toMaxSize:(CGFloat)maxSize;

+ (BOOL)isVideoDurationValidAtUrl:(NSURL *)url;

+ (NSArray*)videoQualities;
+ (NSArray*)videoQualityMaxDurations;
+ (NSTimeInterval)videoMaxDurationAtCurrentQuality;

+ (SDAVAssetExportSession*)convertVideoAsset:(AVAsset*)asset onCompletion:(void(^)(NSURL *url))onCompletion onError:(void(^)(NSError *error))onError;
+ (void)convertVideoAsset:(AVAsset*)asset withExportSession:(SDAVAssetExportSession *)exportSession onCompletion:(void(^)(NSURL *url))onCompletion onError:(void(^)(NSError *error))onError;

+ (SDAVAssetExportSession *)getAVAssetExportSessionFrom:(AVAsset *) asset outputURL:(NSURL *)outputURL;
+ (NSURL *) getAssetOutputURL;

+ (NSData *_Nullable)PNGRepresentationFor: (UIImage *_Nonnull) image;
+ (NSData *_Nullable)JPEGRepresentationFor: (UIImage *_Nonnull) image;

@end
