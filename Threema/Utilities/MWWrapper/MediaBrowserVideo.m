//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2024 Threema GmbH
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

#import "MediaBrowserVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h> 
#import "VideoMessageLoader.h"
#import "NSString+Hex.h"
#import "BundleUtil.h"
#import "ThreemaFramework.h"

@interface MediaBrowserVideo ()

@property VideoMessageEntity *message;

@end

@implementation MediaBrowserVideo

@synthesize underlyingImage = _underlyingImage; // synth property from protocol

+ (instancetype)videoWithThumbnail:(UIImage *)image {
    MediaBrowserVideo *video = [[self alloc] initWithImage:image];
    return video;
}

- (instancetype)initWithImage:(UIImage *)image
{
    self = [super init];
    if (self) {
        _image = image;
        _isUtiPreview = false;
    }
    return self;
}

- (void)setSourceReference:(id)sourceReference {
    _message = (VideoMessageEntity *)sourceReference;
}

-(id)sourceReference {
    return _message;
}

- (void)play {
    if (_delegate) {
        [_delegate playVideo: self];
    }
}

#pragma mark - MWPhoto Protocol Methods

-(BOOL)showControls {
    return YES;
}

-(void)handleSingleTap:(CGPoint)touchPoint {
    if (_message.video != nil) {
        [self play];
    } else {
        BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
        [manager syncBlobsFor:_message.objectID onCompletion:^(enum BlobManagerObjCResult result){
            NSAssert(result != BlobManagerObjCResultUploaded, @"We never upload a file in this case");
            [self postCompleteNotification];
        }];
    }
}


-(BOOL)canScaleImage {
    return NO;
}

-(NSURL *)urlForExportData:(NSString *)tmpFileName {
    if (_message == nil || _message.video == nil) {
        return nil;
    }
    
    NSString *fileName = [[_message video] getFilename];
    if (fileName == nil) {
        fileName = tmpFileName;
    }
    
    NSURL *exportDirUrl = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSURL *exportVideoUrl = [[exportDirUrl URLByAppendingPathComponent:fileName] URLByAppendingPathExtension: MEDIA_EXTENSION_VIDEO];
    
    NSData *data = [_message blobData];
    if (![data writeToURL:exportVideoUrl atomically:NO]) {
        return nil;
    }
    
    return exportVideoUrl;
}

- (UIImage *)underlyingImage {
    return _image;
}

- (void)loadUnderlyingImageAndNotify {
    // loaded already
    if (_message.video != nil) {
        if (_message.thumbnail != nil) {
            if (_message.thumbnail.data != nil) {
                _image = [[UIImage alloc] initWithData:_message.thumbnail.data];
                [self postCompleteNotification];
            }
        }
        return;
    }

    // loading
    if (_message.progress != nil) {
        return;
    }
    
    [self performLoadUnderlyingImageAndNotify];
}

- (void)performLoadUnderlyingImageAndNotify {
    BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
    [manager syncBlobsFor:_message.objectID onCompletion:^(enum BlobManagerObjCResult result){
        NSAssert(result != BlobManagerObjCResultUploaded, @"We never upload a file in this case");
        [self postCompleteNotification];
    }];
}

- (void)postCompleteNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION object:self];
}

- (void)unloadUnderlyingImage {
    _image = nil;
}

- (void)cancelAnyLoading {
    
}

- (BOOL)isVideo {
    return YES;
}

- (void)getVideoURL:(void (^)(NSURL *))completion {
    completion([self urlForExportData:@"video"]);
}

- (NSString *)accessibilityLabelForContent {
    NSString *date = [DateFormatter accessibilityDateTime:_message.remoteSentDate];
    return [NSString stringWithFormat:@"%@. %@", [BundleUtil localizedStringForKey:@"video"], date];
}

@end
