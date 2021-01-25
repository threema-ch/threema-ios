//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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
#import "Utils.h"
#import "UTIConverter.h"

@interface MediaBrowserFile ()

@property FileMessage *fileMessage;

@end

@implementation MediaBrowserFile

@synthesize underlyingImage = _underlyingImage; // synth property from protocol

+ (instancetype)fileWithFileMessage:(FileMessage *)fileMessage thumbnail:(BOOL)forThumbnail {
    MediaBrowserFile *file = [[self alloc] initWithFileMessage:fileMessage thumbnail:forThumbnail];
    return file;
}

- (instancetype)initWithFileMessage:(FileMessage *)fileMessage thumbnail:(BOOL)forThumbnail
{
    self = [super init];
    if (self) {
        _fileMessage = fileMessage;
        BOOL isRenderingFileMessage = false;
        if (_fileMessage.data != nil) {
            if (_fileMessage.data.data != nil) {
                if ([_fileMessage renderFileImageMessage] == true) {
                    isRenderingFileMessage = true;
                }
            }
        }
        
        if (isRenderingFileMessage == true) {
            _isUtiPreview = false;
            if (forThumbnail) {
                if (_fileMessage.thumbnail != nil) {
                    if (_fileMessage.thumbnail.data != nil) {
                        _underlyingImage = [[UIImage alloc] initWithData:_fileMessage.thumbnail.data];
                    }
                }
            } else {
                _underlyingImage = [[UIImage alloc] initWithData:_fileMessage.data.data];
            }
        }
        
        if (isRenderingFileMessage == false || _underlyingImage == nil) {
            UIImage *thumbnail = [FileMessagePreview thumbnailForFileMessage:fileMessage];
            _isUtiPreview = !fileMessage.thumbnail;
            if (fileMessage.thumbnail == nil) {
                UIImage *colorizedThumbnail = [thumbnail imageWithTint:[Colors white]];
                _underlyingImage = colorizedThumbnail;
            } else {
                if ([UTIConverter isGifMimeType:fileMessage.mimeType]) {
                    thumbnail = [Utils makeThumbWithOverlayFor:thumbnail];
                }
                
                _underlyingImage = thumbnail;
            }
        }
    }
    return self;
}

- (BOOL)isVideo {
    if ([_fileMessage renderFileVideoMessage] == true) {
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
    return _fileMessage;
}

#pragma mark - MWPhoto Protocol Methods

-(BOOL)showControls {
    return YES;
}

-(void)handleSingleTap:(CGPoint)touchPoint {
    if (_fileMessage.data != nil) {
        if ([_fileMessage renderFileImageMessage] == true) {
            [_delegate toggleControls];
        }
        else if ([_fileMessage renderFileVideoMessage] == true) {
            [self play];
        }
        else {
            [_delegate showFile: _fileMessage];
        }
    } else {
        [self loadUnderlyingImageAndNotify];
    }
}

- (void)play {
    if (_delegate) {
        [_delegate playFileVideo: _fileMessage];
    }
}

-(BOOL)canScaleImage {
    if ([_fileMessage renderFileImageMessage] == true) {
        return true;
    }
    return NO;
}

-(NSURL *)urlForExportData:(NSString *)tmpFileName {
    if (_fileMessage == nil || _fileMessage.data == nil) {
        return nil;
    }
    NSURL *url = [_fileMessage tmpURL:tmpFileName];
    [_fileMessage exportDataToURL:url];
    return url;
}

- (UIImage *)underlyingImage {
    return _underlyingImage;
}

- (void)loadUnderlyingImageAndNotify {
    // loaded already
    if (_fileMessage.data != nil) {
        if (_fileMessage.thumbnail != nil) {
            if (_fileMessage.thumbnail.data != nil) {
                _underlyingImage = [[UIImage alloc] initWithData:_fileMessage.thumbnail.data];
                [self postCompleteNotification];
            }
        } else {
            UIImage *thumbnail = [FileMessagePreview thumbnailForFileMessage:_fileMessage];
            _isUtiPreview = !_fileMessage.thumbnail;
            if (_fileMessage.thumbnail == nil) {
                UIImage *colorizedThumbnail = [thumbnail imageWithTint:[Colors white]];
                _underlyingImage = colorizedThumbnail;
            } else {
                if ([UTIConverter isGifMimeType:_fileMessage.mimeType]) {
                    thumbnail = [Utils makeThumbWithOverlayFor:thumbnail];
                }
                _underlyingImage = thumbnail;
            }
            [self postCompleteNotification];
        }
        return;
    }
    
    // loading
    if (_fileMessage.progress != nil) {
        return;
    }
    
    [self performLoadUnderlyingImageAndNotify];
}

- (void)performLoadUnderlyingImageAndNotify {
    BlobMessageLoader *loader;
    if ([UTIConverter isGifMimeType:_fileMessage.mimeType]) {
        loader = [[AnimGifMessageLoader alloc] init];
    } else {
        loader = [[BlobMessageLoader alloc] init];
    }
    
    [loader startWithMessage:_fileMessage onCompletion:^(BaseMessage *message) {
        [self postCompleteNotification];
    } onError:^(NSError *error) {
        [self postCompleteNotification];
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
    NSString *date = [DateFormatter accessibilityDateTime:_fileMessage.remoteSentDate];
    return [NSString stringWithFormat:@"%@. %@", NSLocalizedString(@"file", nil), date];
}

- (BOOL)canHideToolBar {
    return [UTIConverter isImageMimeType:_fileMessage.mimeType];
}
/***** END THREEMA MODIFICATION: add function *********/

@end
