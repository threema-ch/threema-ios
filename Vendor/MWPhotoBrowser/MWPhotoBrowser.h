// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  MWPhotoBrowser.h
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "MWPhoto.h"
#import "MWPhotoProtocol.h"
#import "MWCaptionView.h"
///***** BEGIN THREEMA MODIFICATION: ignore mute switch *********/
#import <AVKit/AVKit.h>
///***** END THREEMA MODIFICATION: ignore mute switch *********/

// Debug Logging
#if 0 // Set to 1 to enable debug logging
#define MWLog(x, ...) NSLog(x, ## __VA_ARGS__);
#else
#define MWLog(x, ...)
#endif

@class MWPhotoBrowser;

@protocol MWPhotoBrowserDelegate <NSObject>

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser;
- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index;
- (NSManagedObjectID *)photoBrowser:(MWPhotoBrowser *)photoBrowser objectIDAtIndex:(NSUInteger)index;

@optional

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index;
- (MWCaptionView *)photoBrowser:(MWPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index;
- (NSString *)photoBrowser:(MWPhotoBrowser *)photoBrowser titleForPhotoAtIndex:(NSUInteger)index;
- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index;
- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index;
/***** BEGIN THREEMA MODIFICATION: add delete button *********/
- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButton:(UIBarButtonItem *)deleteButton pressedForPhotoAtIndex:(NSUInteger)index;
- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButton:(UIBarButtonItem *)deleteButton;
- (void)photoBrowserResetSelection:(MWPhotoBrowser *)photoBrowser;
- (void)photoBrowserSelectAll:(MWPhotoBrowser *)photoBrowser;
- (NSSet *)mediaPhotoSelection;
- (NSUInteger *)mediaSelectionCount;
/***** END THREEMA MODIFICATION: add delete button *********/
- (BOOL)photoBrowser:(MWPhotoBrowser *)photoBrowser isPhotoSelectedAtIndex:(NSUInteger)index;
- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index selectedChanged:(BOOL)selected;
- (void)photoBrowserDidFinishModalPresentation:(MWPhotoBrowser *)photoBrowser;

@end

///***** BEGIN THREEMA MODIFICATION: ignore mute switch *********/
@interface MWPhotoBrowser : UIViewController <UIScrollViewDelegate, UIActionSheetDelegate, AVPlayerViewControllerDelegate>
///***** END THREEMA MODIFICATION: ignore mute switch *********/

@property (nonatomic, weak) IBOutlet id<MWPhotoBrowserDelegate> delegate;
@property (nonatomic) BOOL zoomPhotosToFill;
@property (nonatomic) BOOL displayNavArrows;
@property (nonatomic) BOOL displayActionButton;
/***** BEGIN THREEMA MODIFICATION: add select all button *********/
@property (nonatomic) BOOL displayDeleteButton;
/***** END THREEMA MODIFICATION: add select all button *********/
@property (nonatomic) BOOL displaySelectionButtons;
@property (nonatomic) BOOL alwaysShowControls;
@property (nonatomic) BOOL enableGrid;
@property (nonatomic) BOOL enableSwipeToDismiss;
@property (nonatomic) BOOL startOnGrid;
@property (nonatomic) BOOL autoPlayOnAppear;
@property (nonatomic) NSUInteger delayToHideElements;
@property (nonatomic, readonly) NSUInteger currentIndex;
/***** BEGIN THREEMA MODIFICATION: add peeking *********/
@property (nonatomic) BOOL peeking;
@property (nonatomic) NSUInteger testCount;
/***** END THREEMA MODIFICATION: add peeking *********/
///***** BEGIN THREEMA MODIFICATION: ignore mute switch *********/
@property (nonatomic, strong) NSString *prevAudioCategory;
///***** END THREEMA MODIFICATION: ignore mute switch *********/

// Customise image selection icons as they are the only icons with a colour tint
// Icon should be located in the app's main bundle
///***** BEGIN THREEMA MODIFICATION: use image instead of name *********/
@property (nonatomic, strong) UIImage *customImageSelectedIcon;
@property (nonatomic, strong) UIToolbar *gridToolbar;
///***** END THREEMA MODIFICATION: use image instead of name *********/
@property (nonatomic, strong) NSString *customImageSelectedSmallIconName;

// Init
- (id)initWithPhotos:(NSArray *)photosArray;
- (id)initWithDelegate:(id <MWPhotoBrowserDelegate>)delegate;

// Reloads the photo browser and refetches data
/***** BEGIN THREEMA MODIFICATION: delete file *********/
//- (void)reloadData;
- (void)reloadData:(BOOL)updateLayout;
/***** BEGIN THREEMA MODIFICATION: delete file *********/

// Set page that photo browser starts on
- (void)setCurrentPhotoIndex:(NSUInteger)index;

// Navigation
- (void)showNextPhotoAnimated:(BOOL)animated;
- (void)showPreviousPhotoAnimated:(BOOL)animated;

- (id<MWPhoto>)photoAtIndex:(NSUInteger)index;

/***** BEGIN THREEMA MODIFICATION: delete file *********/
- (void)finishedDeleteMedia;
- (void)toggleControls;
/***** BEGIN THREEMA MODIFICATION: delete file *********/

- (void)shareMedia:(MWPhoto *)item;
- (void)showAlert:(NSString *)title message:(NSString *)message;
@end
