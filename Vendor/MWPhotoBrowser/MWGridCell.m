// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  MWGridCell.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 08/10/2013.
//
//
/***** BEGIN THREEMA MODIFICATION: Use stylekit check image *********/
#import "ThreemaFramework/ThreemaFramework-swift.h"
/***** END THREEMA MODIFICATION: Use stylekit check image *********/
#import <DACircularProgress/DACircularProgressView.h>
#import "MWGridCell.h"
#import "MWCommon.h"
#import "MWPhotoBrowserPrivate.h"
#import "UIImage+MWPhotoBrowser.h"
#import "MediaBrowserFile.h"

#define VIDEO_INDICATOR_PADDING 10

@interface MWGridCell () {
    
    UIImageView *_imageView;
    UIImageView *_videoIndicator;
    UIImageView *_loadingError;
	DACircularProgressView *_loadingIndicator;
    UIButton *_selectedButton;
    /***** BEGIN THREEMA MODIFICATION: add label to display filename *********/
    UILabel *_label;
    /***** END THREEMA MODIFICATION: add label to display filename *********/
}

@end

@implementation MWGridCell

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {

        // Grey background
        self.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1];
        self.isAccessibilityElement = YES;
        
        
        // Image
        _imageView = [UIImageView new];
        _imageView.frame = self.bounds;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.autoresizesSubviews = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _imageView.accessibilityTraits = UIAccessibilityTraitImage;
        /***** BEGIN THREEMA MODIFICATION: accessibilityIgnoresInvertColors *********/
        _imageView.accessibilityIgnoresInvertColors = true;
        /***** END THREEMA MODIFICATION: accessibilityIgnoresInvertColors *********/
        [self addSubview:_imageView];
        
        // Video Image
        _videoIndicator = [UIImageView new];
        _videoIndicator.hidden = NO;
        UIImage *videoIndicatorImage = [UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/VideoOverlay" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]];
        _videoIndicator.frame = CGRectMake(self.bounds.size.width - videoIndicatorImage.size.width - VIDEO_INDICATOR_PADDING, self.bounds.size.height - videoIndicatorImage.size.height - VIDEO_INDICATOR_PADDING, videoIndicatorImage.size.width, videoIndicatorImage.size.height);
        _videoIndicator.image = videoIndicatorImage;
        _videoIndicator.autoresizesSubviews = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:_videoIndicator];
        
        // Selection button
        _selectedButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _selectedButton.contentMode = UIViewContentModeTopRight;
        _selectedButton.adjustsImageWhenHighlighted = NO;
        /***** BEGIN THREEMA MODIFICATION: Use stylekit check image *********/
        [_selectedButton setImage:[[StyleKit uncheck] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
        [_selectedButton setImage:[[StyleKit check] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateSelected];
        /***** END THREEMA MODIFICATION: Use stylekit check image *********/
        [_selectedButton addTarget:self action:@selector(selectionButtonPressed) forControlEvents:UIControlEventTouchDown];
        _selectedButton.hidden = YES;
        _selectedButton.frame = CGRectMake(0, 0, 26, 26);
        [self addSubview:_selectedButton];
    
		// Loading indicator
		_loadingIndicator = [[DACircularProgressView alloc] initWithFrame:CGRectMake(0, 0, 40.0f, 40.0f)];
        _loadingIndicator.userInteractionEnabled = NO;
        _loadingIndicator.thicknessRatio = 0.1;
        _loadingIndicator.roundedCorners = NO;
		[self addSubview:_loadingIndicator];
        
        /***** BEGIN THREEMA MODIFICATION: add label to display filename *********/
        // Label for File name
        _label = [[UILabel alloc] initWithFrame:CGRectMake(10 , self.bounds.size.height - 45 , self.bounds.size.width  - 20 , 40)];
        _label.opaque = NO;
        _label.backgroundColor = [UIColor clearColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.adjustsFontSizeToFitWidth = NO;
        _label.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _label.numberOfLines = 2;
        _label.textColor = [UIColor whiteColor];
        _label.font = [UIFont systemFontOfSize:12];
        _label.hidden = YES;
        [self addSubview:_label];
        /***** END THREEMA MODIFICATION: add label to display filename *********/
        
        // Listen for photo loading notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setProgressFromNotification:)
                                                     name:MWPHOTO_PROGRESS_NOTIFICATION
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMWPhotoLoadingDidEndNotification:)
                                                     name:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                                   object:nil];
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setGridController:(MWGridViewController *)gridController {
    _gridController = gridController;
    // Set custom selection image if required
    if (_gridController.browser.customImageSelectedSmallIconName) {
        [_selectedButton setImage:[UIImage imageNamed:_gridController.browser.customImageSelectedSmallIconName] forState:UIControlStateSelected];
    }
}

#pragma mark - View

- (void)layoutSubviews {
    [super layoutSubviews];
    _imageView.frame = self.bounds;
    if ([_photo respondsToSelector:@selector(isUtiPreview)]) {
        BOOL isUtiThumb = [_photo performSelector:@selector(isUtiPreview)];
        if (isUtiThumb == true) {
            _imageView.frame = CGRectMake((self.bounds.size.width/2) - (36.0/2), (self.bounds.size.height/2) - (36.0/2), 36.0, 36.0);
            _imageView.contentMode = UIViewContentModeScaleAspectFit;
        } else {
            _imageView.frame = self.bounds;
            _imageView.contentMode = UIViewContentModeScaleAspectFill;
        }
    }
    
    _loadingIndicator.frame = CGRectMake(floorf((self.bounds.size.width - _loadingIndicator.frame.size.width) / 2.),
                                         floorf((self.bounds.size.height - _loadingIndicator.frame.size.height) / 2),
                                         _loadingIndicator.frame.size.width,
                                         _loadingIndicator.frame.size.height);
    _selectedButton.frame = CGRectMake(self.bounds.size.width - (_selectedButton.frame.size.width * 1.4),
                                       self.bounds.size.height - (_selectedButton.frame.size.height * 1.4), _selectedButton.frame.size.width, _selectedButton.frame.size.height);
}

#pragma mark - Cell

- (void)prepareForReuse {
    _photo = nil;
    _gridController = nil;
    _imageView.image = nil;
    _loadingIndicator.progress = 0;
    _selectedButton.hidden = YES;
    _label.hidden = YES;
    [self hideImageFailure];
    [super prepareForReuse];
}

#pragma mark - Image Handling

- (void)setPhoto:(id <MWPhoto>)photo {
    _photo = photo;
    
    /***** BEGIN THREEMA MODIFICATION: add label to display filename *********/
    if ( [photo isKindOfClass:[MediaBrowserFile class]] ) {
        MediaBrowserFile *mediaBrowserFile = (MediaBrowserFile *) photo;
        if ([mediaBrowserFile sourceReference] && [[mediaBrowserFile sourceReference] isKindOfClass:[FileMessageEntity class]]) {
            FileMessageEntity *fileMessageEntity = (FileMessageEntity *)[mediaBrowserFile sourceReference];
            if ( ![fileMessageEntity renderFileImageMessage] && ![fileMessageEntity renderFileVideoMessage] ) {
                _label.text = [fileMessageEntity fileName];
                _label.hidden = NO;
            } else {
                _label.hidden = YES;
            }
        }
    }
    /***** END THREEMA MODIFICATION: add label to display filename *********/
    
    if ([photo respondsToSelector:@selector(isVideo)]) {
        _videoIndicator.hidden = !photo.isVideo;
    } else {
        _videoIndicator.hidden = YES;
    }
    if (_photo) {
        if (![_photo underlyingImage]) {
            [self showLoadingIndicator];
        } else {
            [self hideLoadingIndicator];
        }
    } else {
        [self showImageFailure];
    }
}

- (void)displayImage {
    _imageView.image = [_photo underlyingImage];
    _selectedButton.hidden = !_selectionMode;
    [self setNeedsLayout];
    [self hideImageFailure];
}

#pragma mark - Selection

- (void)setSelectionMode:(BOOL)selectionMode {
    _selectionMode = selectionMode;
}

- (void)setIsSelected:(BOOL)isSelected {
    _isSelected = isSelected;
    _selectedButton.selected = isSelected;
}

- (void)selectionButtonPressed {
    _selectedButton.selected = !_selectedButton.selected;
    [_gridController.browser setPhotoSelected:_selectedButton.selected atIndex:_index];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    _imageView.alpha = 0.6;
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    _imageView.alpha = 1;
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    _imageView.alpha = 1;
    [super touchesCancelled:touches withEvent:event];
}

#pragma mark Indicators

- (void)hideLoadingIndicator {
    _loadingIndicator.hidden = YES;
}

- (void)showLoadingIndicator {
    _loadingIndicator.progress = 0;
    _loadingIndicator.hidden = NO;
    [self hideImageFailure];
}

- (void)showImageFailure {
    // Only show if image is not empty
    if (![_photo respondsToSelector:@selector(emptyImage)] || !_photo.emptyImage) {
        if (!_loadingError) {
            _loadingError = [UIImageView new];
            _loadingError.image = [UIImage imageForResourcePath:@"MWPhotoBrowser.bundle/ImageError" ofType:@"png" inBundle:[NSBundle bundleForClass:[self class]]];
            _loadingError.userInteractionEnabled = NO;
            [_loadingError sizeToFit];
            [self addSubview:_loadingError];
        }
        _loadingError.frame = CGRectMake(floorf((self.bounds.size.width - _loadingError.frame.size.width) / 2.),
                                         floorf((self.bounds.size.height - _loadingError.frame.size.height) / 2),
                                         _loadingError.frame.size.width,
                                         _loadingError.frame.size.height);
    }
    [self hideLoadingIndicator];
    _imageView.image = nil;
}

- (void)hideImageFailure {
    if (_loadingError) {
        [_loadingError removeFromSuperview];
        _loadingError = nil;
    }
}

#pragma mark - Notifications

- (void)setProgressFromNotification:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *dict = [notification object];
        id <MWPhoto> photoWithProgress = [dict objectForKey:@"photo"];
        if (photoWithProgress == _photo) {
//            NSLog(@"%f", [[dict valueForKey:@"progress"] floatValue]);
            float progress = [[dict valueForKey:@"progress"] floatValue];
            _loadingIndicator.progress = MAX(MIN(1, progress), 0);
        }
    });
}

- (void)handleMWPhotoLoadingDidEndNotification:(NSNotification *)notification {
    id <MWPhoto> photo = [notification object];
    if (photo == _photo) {
        if ([photo underlyingImage]) {
            // Successful load
            [self displayImage];
        } else {
            // Failed to load
            [self showImageFailure];
        }
        [self hideLoadingIndicator];
    }
}

/***** BEGIN THREEMA MODIFICATION: add function *********/
- (NSString *)accessibilityLabel {
    return [_photo accessibilityLabelForContent];
}
/***** END THREEMA MODIFICATION: add function *********/


@end
