#import "MWPhoto.h"

@class MediaBrowserVideo;

@protocol MWVideoDelegate

-(void)playVideo:(MediaBrowserVideo *)video;

@end

@interface MediaBrowserVideo : NSObject <MWPhoto>

@property (nonatomic, strong) NSString *caption;
@property (nonatomic, readonly) UIImage *image;

@property (strong) id<MWVideoDelegate> delegate;
@property (strong) id sourceReference;
@property (nonatomic) BOOL isUtiPreview;

+ (instancetype)videoWithThumbnail:(UIImage *)image;

- (void)play;

@end
