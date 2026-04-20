#import "MediaBrowserVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h> 
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
        BlobManagerObjCWrapper *manager = [[BlobManagerObjCWrapper alloc] init];
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
    BlobManagerObjCWrapper *manager = [[BlobManagerObjCWrapper alloc] init];
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
