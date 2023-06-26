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

#import "MediaBrowserFile.h"
#import "ImageData.h"
#import "FileMessagePreview.h"
#import "AnimGifMessageLoader.h"
#import "UIImage+ColoredImage.h"
#import "ThreemaUtilityObjC.h"
#import "UTIConverter.h"
#import "BundleUtil.h"

@interface MediaBrowserFile ()

@property FileMessageEntity *fileMessageEntity;

@end

@implementation MediaBrowserFile

@synthesize underlyingImage = _underlyingImage; // synth property from protocol

+ (instancetype)fileWithFileMessageEntity:(FileMessageEntity *)fileMessageEntity thumbnail:(BOOL)forThumbnail {
    MediaBrowserFile *file = [[self alloc] initWithFileMessage:fileMessageEntity thumbnail:forThumbnail];
    return file;
}

- (instancetype)initWithFileMessage:(FileMessageEntity *)fileMessageEntity thumbnail:(BOOL)forThumbnail
{
    self = [super init];
    if (self) {
        _fileMessageEntity = fileMessageEntity;
        BOOL isRenderingFileMessage = false;
        if (_fileMessageEntity.data != nil) {
            if (_fileMessageEntity.data.data != nil) {
                if ([_fileMessageEntity renderFileImageMessage] == true) {
                    isRenderingFileMessage = true;
                }
            }
        }
        
        if (isRenderingFileMessage == true) {
            _isUtiPreview = false;
            if (forThumbnail) {
                if (_fileMessageEntity.thumbnail != nil) {
                    if (_fileMessageEntity.thumbnail.data != nil) {
                        _underlyingImage = [[UIImage alloc] initWithData:_fileMessageEntity.thumbnail.data];
                    }
                }
            } else {
                _underlyingImage = [[UIImage alloc] initWithData:_fileMessageEntity.data.data];
            }
        }
        
        if (isRenderingFileMessage == false || _underlyingImage == nil) {
            UIImage *thumbnail = [FileMessagePreview thumbnailForFileMessageEntity:fileMessageEntity];
            _isUtiPreview = !fileMessageEntity.thumbnail;
            if (fileMessageEntity.thumbnail == nil) {
                UIImage *colorizedThumbnail = [thumbnail imageWithTint:Colors.white];
                _underlyingImage = colorizedThumbnail;
            } else {
                if ([UTIConverter isGifMimeType:fileMessageEntity.mimeType]) {
                    thumbnail = [ThreemaUtilityObjC makeThumbWithOverlayFor:thumbnail];
                }
                
                _underlyingImage = thumbnail;
            }
        }
    }
    return self;
}

- (BOOL)isVideo {
    if ([_fileMessageEntity renderFileVideoMessage] == true) {
        return true;
    }
    return false;
}

- (UIImage *)padImage:(UIImage *)image toSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    
    CGFloat x = (size.width - image.size.width)/2.0;
    CGFloat y = (size.height - image.size.height)/2.0;
    [image drawInRect:CGRectMake(x, y, image.size.width, image.size.height) blendMode:kCGBlendModeNormal alpha:0.8];
    
    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return resultImage;
}

- (id)sourceReference {
    return _fileMessageEntity;
}

#pragma mark - MWPhoto Protocol Methods

-(BOOL)showControls {
    return !([_fileMessageEntity renderFileImageMessage]);
}

-(void)handleSingleTap:(CGPoint)touchPoint {
    if (_fileMessageEntity.data != nil) {
        if ([_fileMessageEntity renderFileImageMessage] == true) {
            [_delegate toggleControls];
        }
        else if ([_fileMessageEntity renderFileVideoMessage] == true) {
            [self play];
        }
        else {
            [_delegate showFile: _fileMessageEntity];
        }
    } else {
        BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
        [manager syncBlobsFor:_fileMessageEntity.objectID onCompletion:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION object:self];
        }];
    }
}

- (void)play {
    if (_delegate) {
        [_delegate playFileVideo: _fileMessageEntity];
    }
}

-(BOOL)canScaleImage {
    if ([_fileMessageEntity renderFileImageMessage] == true) {
        return true;
    }
    return NO;
}

-(NSURL *)urlForExportData:(NSString *)tmpFileName {
    if (_fileMessageEntity == nil || _fileMessageEntity.data == nil) {
        return nil;
    }
    NSURL *url = [_fileMessageEntity tmpURL:tmpFileName];
    [_fileMessageEntity exportDataToURL:url];
    return url;
}

- (UIImage *)underlyingImage {
    return _underlyingImage;
}

- (void)loadUnderlyingImageAndNotify {
    // loaded already
        
    if (_fileMessageEntity.thumbnail != nil) {
        if (_fileMessageEntity.thumbnail != nil) {
            if (_fileMessageEntity.thumbnail.data != nil) {
                _underlyingImage = [[UIImage alloc] initWithData:_fileMessageEntity.thumbnail.data];
                [self postCompleteNotification];
                return;
            }
        }
    }
    
    if (_fileMessageEntity.data != nil) {
        UIImage *thumbnail = [FileMessagePreview thumbnailForFileMessageEntity:_fileMessageEntity];
        _isUtiPreview = !_fileMessageEntity.thumbnail;
        if (_fileMessageEntity.thumbnail == nil) {
            UIImage *colorizedThumbnail = [thumbnail imageWithTint:Colors.white];
            _underlyingImage = colorizedThumbnail;
        } else {
            if ([UTIConverter isGifMimeType:_fileMessageEntity.mimeType]) {
                thumbnail = [ThreemaUtilityObjC makeThumbWithOverlayFor:thumbnail];
            }
            _underlyingImage = thumbnail;
        }
        [self postCompleteNotification];
        return;
    }
        
    // loading
    if (_fileMessageEntity.progress != nil) {
        return;
    }
    
    [self performLoadUnderlyingImageAndNotify];
}

- (void)performLoadUnderlyingImageAndNotify {
    BlobManagerObjcWrapper *manager = [[BlobManagerObjcWrapper alloc] init];
    [manager syncBlobsFor:_fileMessageEntity.objectID onCompletion:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION object:self];
    }];
}

- (void)postCompleteNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION object:self];
}

- (void)unloadUnderlyingImage {
    _underlyingImage = nil;
}

- (void)cancelAnyLoading {
    
}

- (void)getVideoURL:(void (^)(NSURL *))completion {
    completion([self urlForExportData:@"video"]);
}

/***** BEGIN THREEMA MODIFICATION: add function *********/
- (NSString *)accessibilityLabelForContent {
    NSString *date = [DateFormatter accessibilityDateTime:_fileMessageEntity.remoteSentDate];
    return [NSString stringWithFormat:@"%@. %@", [BundleUtil localizedStringForKey:@"file"], date];
}

- (BOOL)canHideToolBar {
    return [UTIConverter isImageMimeType:_fileMessageEntity.mimeType];
}
/***** END THREEMA MODIFICATION: add function *********/

@end
