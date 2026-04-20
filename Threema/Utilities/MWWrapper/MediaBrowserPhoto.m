#import "MWPhoto.h"
//
//  MediaBrowserPhoto.m
//  Threema
//
//  Copyright (c) 2014 Threema GmbH. All rights reserved.
//

#import "MediaBrowserPhoto.h"
#import "NSString+Hex.h"
#import "BundleUtil.h"
#import <ThreemaFramework/Constants.h>
#import "ThreemaFramework.h"

@interface MediaBrowserPhoto ()

@property NSURL *photoURL;
@property BOOL thumbnail;

@end

@implementation MediaBrowserPhoto

@synthesize underlyingImage = _underlyingImage; // synth property from protocol

+ (instancetype)photoWithImageMessageEntity:(ImageMessageEntity *)imageMessageEntity thumbnail:(BOOL)thumbnail {
    return [[MediaBrowserPhoto alloc] initWithImageMessageEntity:imageMessageEntity thumbnail:thumbnail];
}

- (id)initWithImageMessageEntity:(ImageMessageEntity *)imageMessageEntity thumbnail:(BOOL)thumbnail {
    if ((self = [super init])) {
        _imageMessageEntity = imageMessageEntity;
        _thumbnail = thumbnail;
        _isUtiPreview = false;
    }
    return self;
}

-(id)sourceReference {
    return _imageMessageEntity;
}

#pragma mark - MWPhoto Protocol Methods

- (UIImage *)underlyingImage {
    return _underlyingImage;
}

- (void)loadUnderlyingImageAndNotify {
    [self performLoadUnderlyingImageAndNotify];
}

// Set the underlyingImage
- (void)performLoadUnderlyingImageAndNotify {
    if (_thumbnail) {
        _underlyingImage = _imageMessageEntity.thumbnail.uiImage;
    }
    else {
        _underlyingImage = _imageMessageEntity.image != nil ? _imageMessageEntity.image.uiImage : _imageMessageEntity.thumbnail.uiImage;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION object:self];
    });
}

- (void)unloadUnderlyingImage {
    _underlyingImage = nil;
}

- (BOOL)showControls {
    return NO;
}

-(BOOL)canScaleImage {
    return YES;
}

-(NSURL *)urlForExportData:(NSString *)tmpFileName {
    NSString *fileName = [[_imageMessageEntity image] getFilename];
    if (fileName == nil) {
        fileName = tmpFileName;
    }
    _photoURL = [[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:fileName] URLByAppendingPathExtension:MEDIA_EXTENSION_IMAGE];
    NSData *imageData = _imageMessageEntity.image.data;
    if (![imageData writeToURL:_photoURL atomically:NO]) {
        return nil;
    }
    
    return _photoURL;
}

- (void)cancelAnyLoading {
    
}

- (NSString *)accessibilityLabelForContent {
    NSString *date = [DateFormatter accessibilityDateTime:_imageMessageEntity.remoteSentDate];
    return [NSString stringWithFormat:@"%@. %@", [BundleUtil localizedStringForKey:@"image"], date];
}

@end
